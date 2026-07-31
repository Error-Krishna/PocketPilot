from calendar import monthrange
from datetime import date, datetime, time, timedelta, timezone

from bson import ObjectId
from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field

from core.auth import CurrentUser
from core.database import get_database
from core.responses import error_response, success_response

router = APIRouter(prefix="/budget", tags=["budget"])


class BudgetUpdate(BaseModel):
    monthly_limit: float = Field(..., gt=0)
    category_limits: dict[str, float] = Field(default_factory=dict)


class OverageResolvePayload(BaseModel):
    transaction_id: str = Field(..., min_length=1)
    # "exception": reclassify as ONE_TIME_EXCEPTION, removing it from daily
    #   math entirely (it still reduces the cycle's available balance).
    # "savings": draw the overage from banked_daily_savings.
    # "reduce_daily": spread the overage across remaining cycle days by
    #   increasing daily_limit_adjustment.
    # "hybrid": split between savings and reduce_daily per amount_from_savings.
    resolution: str = Field(..., pattern="^(exception|savings|reduce_daily|hybrid)$")
    amount_from_savings: float = Field(0, ge=0)


async def _get_user_id(current_user: CurrentUser) -> str:
    db = get_database()
    user = await db.users.find_one({"firebase_uid": current_user["uid"]})
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return str(user["_id"])


def _coerce_datetime(value: object) -> datetime:
    if isinstance(value, int):
        today = datetime.now(timezone.utc)
        max_day = monthrange(today.year, today.month)[1]
        day = min(value, max_day)
        return today.replace(day=day, hour=0, minute=0, second=0, microsecond=0)
    if isinstance(value, datetime):
        return value if value.tzinfo is not None else value.replace(tzinfo=timezone.utc)
    if isinstance(value, date):
        return datetime.combine(value, time.min, tzinfo=timezone.utc)
    if isinstance(value, str):
        parsed = datetime.fromisoformat(value)
        return parsed if parsed.tzinfo is not None else parsed.replace(tzinfo=timezone.utc)
    raise ValueError("budgetResetDate must be a date or datetime value")


def _next_reset_date(reset_date: datetime, today: datetime) -> datetime:
    reset_date = reset_date.astimezone(timezone.utc)
    today = today.astimezone(timezone.utc)

    candidate = reset_date.replace(
        year=today.year,
        month=today.month,
        day=min(reset_date.day, monthrange(today.year, today.month)[1]),
    )

    if candidate < today:
        next_year = today.year + (1 if today.month == 12 else 0)
        next_month = 1 if today.month == 12 else today.month + 1
        candidate = reset_date.replace(
            year=next_year,
            month=next_month,
            day=min(reset_date.day, monthrange(next_year, next_month)[1]),
        )

    return candidate


def _cycle_bounds(
    budget_reset_raw: object,
    last_reset_date: datetime | None,
    account_created_at: datetime,
    today: datetime,
) -> tuple[datetime, datetime]:
    """Determine (cycle_start, cycle_end) without requiring a fixed reset
    date to be configured. This is what makes budget_reset_date genuinely
    optional rather than mandatory:

    - If the user set a reset day-of-month, the cycle boundary is that
      recurring date, same as before.
    - If they didn't, the cycle simply runs from whenever it last reset
      (or account creation, for a brand new user) to 30 days later. This
      is a rolling window, not a calendar month — it exists so "days left
      in cycle" and "daily limit" are always well-defined even for a user
      who never configured a fixed date, matching the 20-day-minimum
      pocket-money-match reset path used elsewhere.
    """
    cycle_start = _as_utc_datetime(last_reset_date) or _as_utc_datetime(account_created_at) or today

    if budget_reset_raw is not None:
        reset_date = _coerce_datetime(budget_reset_raw)
        cycle_end = _next_reset_date(reset_date, today)
        return cycle_start, cycle_end

    cycle_end = cycle_start + timedelta(days=30)
    return cycle_start, cycle_end


def _sum_amounts(docs: list[dict]) -> float:
    return float(sum(doc.get("amount", 0) or 0 for doc in docs))


def _sum_discretionary_spend(docs: list[dict]) -> float:
    """Sum of transactions that actually count against the daily allowance.

    Only DISCRETIONARY expenses burn the daily budget. FIXED_COMMITMENT is
    already reserved separately via autopays_due. TRANSFER_INTERNAL never
    counts (it's the user's own money moving, not spend). ONE_TIME_EXCEPTION
    is excluded from daily math by design (see net_irregular). UNCLASSIFIED
    is excluded until reviewed, so it can't silently miscount either way.
    REFUND offsets discretionary spend it reverses.
    """
    total = 0.0
    for doc in docs:
        if doc.get("type") != "expense" and doc.get("txn_class") != "refund":
            continue
        txn_class = doc.get("txn_class", "discretionary")
        if doc.get("classification_source") == "pending":
            continue
        amount = float(doc.get("amount", 0) or 0)
        if txn_class == "discretionary":
            total += amount
        elif txn_class == "refund":
            total -= amount
    return total


def _sum_one_time_exceptions(docs: list[dict]) -> float:
    """Net effect of one-time/emergency transactions for the period.

    These are real money movements (medical bills, emergency repairs) that
    shouldn't distort the daily allowance math, but still need to reduce
    the available balance for the month so the plan stays honest.
    """
    total = 0.0
    for doc in docs:
        if doc.get("txn_class") != "one_time_exception":
            continue
        amount = float(doc.get("amount", 0) or 0)
        total += -amount if doc.get("type") == "expense" else amount
    return total


def _count_needs_review(docs: list[dict]) -> tuple[int, float]:
    """Count and total amount of transactions still pending classification
    review, so the user can be alerted rather than have them silently
    excluded from (or wrongly included in) the budget math.

    Mirrors the review queue's own filter (classification_source == pending)
    rather than txn_class, since that's the authoritative signal for "has a
    human confirmed this yet" used by routers/review.py.
    """
    pending = [doc for doc in docs if doc.get("classification_source") == "pending"]
    return len(pending), _sum_amounts(pending)


def _as_utc_datetime(value: datetime | None) -> datetime | None:
    if value is None:
        return None
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


@router.get("")
async def get_budget(current_user: CurrentUser):
    user_id = await _get_user_id(current_user)
    settings = await get_database().settings.find_one({"user_id": user_id, "type": "budget"})
    if not settings:
        return success_response({"monthly_limit": 0, "category_limits": {}})
    return success_response(
        {
            "monthly_limit": settings.get("monthly_limit", 0),
            "category_limits": settings.get("category_limits", {}),
        }
    )


@router.put("")
async def upsert_budget(payload: BudgetUpdate, current_user: CurrentUser):
    user_id = await _get_user_id(current_user)
    now = datetime.now(timezone.utc)
    doc = {
        "user_id": user_id,
        "type": "budget",
        "monthly_limit": payload.monthly_limit,
        "category_limits": payload.category_limits,
        "updated_at": now,
    }
    await get_database().settings.update_one(
        {"user_id": user_id, "type": "budget"},
        {"$set": doc, "$setOnInsert": {"created_at": now}},
        upsert=True,
    )
    return success_response(
        {
            "monthly_limit": payload.monthly_limit,
            "category_limits": payload.category_limits,
        }
    )


@router.get("/trend")
async def get_spend_trend(current_user: CurrentUser, days: int = 7):
    """Simple day-by-day discretionary spend series for a quick-glance
    trend line — deliberately not a full analytics breakdown, just
    "how much did I spend each of the last N days".
    """
    days = max(1, min(days, 90))
    user_id = await _get_user_id(current_user)
    db = get_database()

    today = datetime.now(timezone.utc)
    range_start = (today - timedelta(days=days - 1)).replace(
        hour=0, minute=0, second=0, microsecond=0
    )
    range_end = today.replace(hour=0, minute=0, second=0, microsecond=0) + timedelta(days=1)

    transactions = await db.transactions.find(
        {
            "user_id": user_id,
            "date": {"$gte": range_start, "$lt": range_end},
        }
    ).to_list(length=None)

    # Bucket by calendar day, reusing the same discretionary-spend filter
    # as the daily/monthly summary so the trend line is consistent with
    # every other number shown on the dashboard.
    by_day: dict[date, list[dict]] = {}
    for txn in transactions:
        txn_date = txn["date"]
        if txn_date.tzinfo is None:
            txn_date = txn_date.replace(tzinfo=timezone.utc)
        day_key = txn_date.astimezone(timezone.utc).date()
        by_day.setdefault(day_key, []).append(txn)

    series = []
    for offset in range(days):
        day = (range_start + timedelta(days=offset)).date()
        day_docs = by_day.get(day, [])
        spent = max(0.0, _sum_discretionary_spend(day_docs))
        series.append({"date": day.isoformat(), "spent": spent})

    return success_response({"days": days, "series": series})


def _sum_discretionary_spend_for_range(
    db_transactions: list[dict], range_start: datetime, range_end: datetime
) -> float:
    """Discretionary spend within [range_start, range_end), reusing the
    same classification-aware filter as _sum_discretionary_spend but
    scoped to an arbitrary day — used by the daily rollover to compute
    exactly how much a single past day spent, independent of the
    caller's own date filtering.
    """
    scoped = [
        doc
        for doc in db_transactions
        if range_start <= _as_utc_datetime(doc["date"]) < range_end
    ]
    return max(0.0, _sum_discretionary_spend(scoped))


async def _apply_daily_rollover(
    db, user: dict, cycle_start: datetime, daily_limit: float, today: datetime
) -> float:
    """Bank any fully-elapsed days since the last rollover into
    banked_daily_savings, so "unused daily limit" becomes a durable saved
    amount at midnight rather than silently inflating tomorrow's limit
    (that dynamic-redistribution behavior is deliberately NOT what this
    flat-daily-limit model does — see budget.py module docstring above).

    Lazy/idempotent by design: there's no server-side midnight cron, so
    this runs on-demand whenever the summary is fetched and catches up on
    every day that's fully elapsed but not yet banked — whether the user
    opened the app yesterday or once a week. last_rollover_date tracks the
    boundary so a day is never banked twice.
    """
    user_id = str(user["_id"])
    today_start = today.replace(hour=0, minute=0, second=0, microsecond=0)

    last_rollover = user.get("last_rollover_date")
    last_rollover = _as_utc_datetime(last_rollover) or cycle_start
    rollover_from = max(last_rollover, cycle_start).replace(
        hour=0, minute=0, second=0, microsecond=0
    )

    if rollover_from >= today_start:
        # Nothing has fully elapsed since the last rollover yet.
        return float(user.get("banked_daily_savings") or 0)

    # Pull every transaction across the full span being rolled over in one
    # query, then bucket per day in Python — cheaper than one query per day
    # for a user who's been away a while.
    span_transactions = await db.transactions.find(
        {
            "user_id": user_id,
            "date": {"$gte": rollover_from, "$lt": today_start},
        }
    ).to_list(length=None)

    banked_delta = 0.0
    cursor = rollover_from
    while cursor < today_start:
        day_end = cursor + timedelta(days=1)
        spent_that_day = _sum_discretionary_spend_for_range(
            span_transactions, cursor, day_end
        )
        # Overspending a day never claws back from savings — only unused
        # allowance banks, floored at zero.
        banked_delta += max(0.0, daily_limit - spent_that_day)
        cursor = day_end

    new_banked_total = float(user.get("banked_daily_savings") or 0) + banked_delta

    await db.users.update_one(
        {"_id": user["_id"]},
        {
            "$set": {
                "banked_daily_savings": new_banked_total,
                "last_rollover_date": today_start,
            }
        },
    )
    # Keep the in-memory doc consistent for the rest of this request.
    user["banked_daily_savings"] = new_banked_total
    user["last_rollover_date"] = today_start

    return new_banked_total


@router.get("/summary")
async def get_budget_summary(current_user: CurrentUser):
    user_id = await _get_user_id(current_user)
    db = get_database()
    user = await db.users.find_one({"_id": ObjectId(user_id)})
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    monthly_budget = float(user.get("monthly_budget") or 0)
    # If the user told us how much of this cycle's money they actually have
    # left (set at onboarding or reset), that's the real starting point for
    # this cycle's math — not the full monthly_budget, which would silently
    # overstate what's available if they'd already spent some of it before
    # setting up the app or confirming the reset. Falls back to the full
    # budget when unset, which is the original behavior.
    cycle_starting_balance = user.get("cycle_starting_balance")
    cycle_base_amount = (
        float(cycle_starting_balance)
        if cycle_starting_balance is not None
        else monthly_budget
    )
    budget_reset_raw = user.get("budget_reset_date")
    account_created_at = user.get("created_at") or datetime.now(timezone.utc)
    last_reset_date = user.get("last_reset_date")

    today = datetime.now(timezone.utc)
    # budget_reset_date is genuinely optional now: if unset, the cycle is a
    # rolling 30-day window from the last reset (or account creation for a
    # brand-new user) instead of erroring out.
    cycle_start, next_reset_date = _cycle_bounds(
        budget_reset_raw, last_reset_date, account_created_at, today
    )

    active_autopays = await db.autopays.find({"user_id": user_id, "is_active": True}).to_list(
        length=None
    )
    due_autopays = [
        autopay
        for autopay in active_autopays
        if (next_run := _as_utc_datetime(autopay.get("next_run_date"))) is not None
        and next_run <= next_reset_date
    ]
    total_autopays_due = _sum_amounts(due_autopays)

    monthly_transactions = await db.transactions.find(
        {
            "user_id": user_id,
            "date": {"$gte": cycle_start, "$lt": next_reset_date},
        }
    ).to_list(length=None)
    # True signed value — a refund can legitimately exceed same-window
    # discretionary spend (e.g. a delayed cashback), and that excess must
    # still correctly increase the remaining budget below. Only the
    # user-facing "spent" figure gets clamped for display, further down.
    spent_this_month_signed = _sum_discretionary_spend(monthly_transactions)
    net_irregular = _sum_one_time_exceptions(monthly_transactions)
    needs_review_count, needs_review_amount = _count_needs_review(monthly_transactions)
    available_balance = cycle_base_amount + net_irregular - total_autopays_due
    remaining_balance = available_balance - spent_this_month_signed
    # "Spent this month" should never read negative to the user — that's
    # never meaningful even when it's mathematically what a refund-heavy
    # window produces. Display value only; math above already used the
    # true signed figure.
    spent_this_month = max(0.0, spent_this_month_signed)

    remaining_days = max(1, (next_reset_date.date() - today.date()).days)
    days_elapsed = max(1, (today.date() - cycle_start.date()).days + 1)
    total_cycle_days = days_elapsed + remaining_days
    # Flat daily limit: a fixed amount per day for the whole cycle, NOT a
    # dynamic remaining-balance-over-remaining-days figure. Per-day
    # underspend is banked into savings at rollover (see
    # _apply_daily_rollover) rather than silently raising tomorrow's
    # limit — that's the deliberate behavior change from the old dynamic
    # model, so a day's leftover shows up as "you saved ₹X" instead of a
    # bigger number the user never explicitly sees.
    daily_limit_base = cycle_base_amount / total_cycle_days if total_cycle_days else 0.0
    # daily_limit_adjustment accumulates whenever the user resolves a
    # "this went over today's limit" alert by choosing to reduce future
    # days rather than draw from savings (see POST /budget/overage/resolve).
    # It's a straight per-day subtraction, not re-derived from remaining
    # balance, so multiple overage resolutions across a cycle compound
    # predictably rather than the math shifting underneath a prior choice.
    daily_limit_adjustment = float(user.get("daily_limit_adjustment") or 0)
    daily_limit = max(0.0, daily_limit_base - daily_limit_adjustment)

    banked_daily_savings = await _apply_daily_rollover(
        db, user, cycle_start, daily_limit, today
    )

    day_start = today.replace(hour=0, minute=0, second=0, microsecond=0)
    day_end = day_start + timedelta(days=1)
    today_transactions = await db.transactions.find(
        {
            "user_id": user_id,
            "date": {"$gte": day_start, "$lt": day_end},
        }
    ).to_list(length=None)
    # Display-only clamp, same rationale as spent_this_month above.
    spent_today = max(0.0, _sum_discretionary_spend(today_transactions))
    income_today = float(
        sum(
            float(doc.get("amount", 0) or 0)
            for doc in today_transactions
            if doc.get("type") == "income" and doc.get("txn_class") == "income_regular"
        )
    )
    saved_today = max(0, daily_limit - spent_today)
    # Any transaction today still awaiting an overage decision — surfaced
    # so the dashboard can show the alert even if the user missed the
    # in-the-moment prompt (e.g. app was closed when the SMS arrived).
    pending_overage_transaction_ids = [
        str(doc["_id"]) for doc in today_transactions if doc.get("overage_pending")
    ]
    # Saved so far this cycle now includes both (a) today's not-yet-banked
    # unused allowance (saved_today, banked at the next rollover) and
    # (b) every already-banked day since cycle start. This replaces the
    # old dynamic-redistribution estimate, which no longer matches how
    # daily_limit behaves under the flat-limit model.
    saved_this_month = banked_daily_savings + saved_today
    lifetime_savings = float(user.get("lifetime_savings") or 0)

    # "Waiting for pocket money" state: cycle is genuinely exhausted
    # (nothing left today or for the rest of the cycle), rather than the
    # bare zero/negative number reading as a bug or a scary warning. The
    # app can't know when the next credit is coming, so this is purely a
    # "you're at zero, that's expected, hang tight" signal — not a
    # prediction of when funds will arrive.
    is_awaiting_funds = remaining_balance <= 0 and daily_limit <= 0

    last_known_bank_balance = user.get("last_known_bank_balance")
    last_known_bank_balance_at = user.get("last_known_bank_balance_at")

    return success_response(
        {
            "monthlyBudget": monthly_budget,
            "totalAutopays": total_autopays_due,
            "totalAutopaysDue": total_autopays_due,
            "availableBalance": available_balance,
            "spentThisMonth": spent_this_month,
            "savedThisMonth": saved_this_month,
            "netIrregularTransactions": net_irregular,
            "remainingBalance": remaining_balance,
            "dailyLimit": daily_limit,
            "spentToday": spent_today,
            "incomeToday": income_today,
            "savedToday": saved_today,
            "remainingDays": remaining_days,
            "cycleStart": cycle_start.isoformat(),
            "cycleEnd": next_reset_date.isoformat(),
            "lifetimeSavings": lifetime_savings,
            "needsReviewCount": needs_review_count,
            "needsReviewAmount": needs_review_amount,
            "isAwaitingFunds": is_awaiting_funds,
            "cycleStartingBalance": cycle_starting_balance,
            "bankedDailySavings": banked_daily_savings,
            "dailyLimitAdjustment": daily_limit_adjustment,
            "pendingOverageTransactionIds": pending_overage_transaction_ids,
            "lastKnownBankBalance": last_known_bank_balance,
            "lastKnownBankBalanceAt": last_known_bank_balance_at.isoformat()
            if last_known_bank_balance_at
            else None,
        }
    )


async def _get_overage_context(db, user: dict, transaction_id: str) -> dict:
    """Shared setup for preview/resolve: loads the transaction, confirms
    it's a genuine same-day overage, and computes the current daily_limit
    and how much of today's spend exceeds it. Returns None if the
    transaction can't be found — a stale or already-resolved transaction_id
    should be a clear no-op, not silently charged against the wrong day.
    """
    user_id = str(user["_id"])
    txn = await db.transactions.find_one({"_id": ObjectId(transaction_id), "user_id": user_id})
    if not txn:
        return None

    monthly_budget = float(user.get("monthly_budget") or 0)
    cycle_starting_balance = user.get("cycle_starting_balance")
    cycle_base_amount = (
        float(cycle_starting_balance) if cycle_starting_balance is not None else monthly_budget
    )
    budget_reset_raw = user.get("budget_reset_date")
    account_created_at = user.get("created_at") or datetime.now(timezone.utc)
    last_reset_date = user.get("last_reset_date")
    today = datetime.now(timezone.utc)
    cycle_start, next_reset_date = _cycle_bounds(
        budget_reset_raw, last_reset_date, account_created_at, today
    )

    remaining_days = max(1, (next_reset_date.date() - today.date()).days)
    days_elapsed = max(1, (today.date() - cycle_start.date()).days + 1)
    total_cycle_days = days_elapsed + remaining_days
    daily_limit_base = cycle_base_amount / total_cycle_days if total_cycle_days else 0.0
    daily_limit_adjustment = float(user.get("daily_limit_adjustment") or 0)
    daily_limit = max(0.0, daily_limit_base - daily_limit_adjustment)

    day_start = today.replace(hour=0, minute=0, second=0, microsecond=0)
    day_end = day_start + timedelta(days=1)
    today_transactions = await db.transactions.find(
        {"user_id": user_id, "date": {"$gte": day_start, "$lt": day_end}}
    ).to_list(length=None)
    spent_today = max(0.0, _sum_discretionary_spend(today_transactions))
    overage = max(0.0, spent_today - daily_limit)

    return {
        "txn": txn,
        "daily_limit": daily_limit,
        "daily_limit_base": daily_limit_base,
        "daily_limit_adjustment": daily_limit_adjustment,
        "overage": overage,
        "remaining_days": remaining_days,
        "banked_daily_savings": float(user.get("banked_daily_savings") or 0),
    }


def _preview_split(ctx: dict, amount_from_savings: float) -> dict:
    """Computes the requested split for the overage preview UI.
    amount_from_savings is clamped to [0, overage] so a caller can't
    request covering more than the actual overage from savings, or a
    negative amount.
    """
    overage = ctx["overage"]
    remaining_days = ctx["remaining_days"]
    banked = ctx["banked_daily_savings"]
    daily_limit_base = ctx["daily_limit_base"]
    daily_limit_adjustment = ctx["daily_limit_adjustment"]

    amount_from_savings = max(0.0, min(amount_from_savings, overage))
    amount_from_daily = overage - amount_from_savings

    # Spreading amount_from_daily across remaining_days (not remaining_days
    # + today, since today's overage already happened — only future days
    # can absorb a reduction).
    per_day_reduction = amount_from_daily / remaining_days if remaining_days else 0.0
    new_daily_limit = max(
        0.0, daily_limit_base - daily_limit_adjustment - per_day_reduction
    )
    new_banked_savings = max(0.0, banked - amount_from_savings)

    return {
        "amountFromSavings": amount_from_savings,
        "amountFromDailyReduction": amount_from_daily,
        "newDailyLimit": new_daily_limit,
        "newBankedSavings": new_banked_savings,
        "perDayReduction": per_day_reduction,
    }


@router.get("/overage/preview")
async def preview_overage_resolution(
    current_user: CurrentUser, transaction_id: str, amount_from_savings: float = 0
):
    """Live preview for the overage-resolution slider: given a candidate
    split between savings and reducing future days, returns what the new
    daily limit and savings figures would become — WITHOUT persisting
    anything. The frontend calls this on every slider move; only
    /overage/resolve actually commits a choice.
    """
    db = get_database()
    user = await db.users.find_one({"firebase_uid": current_user["uid"]})
    if not user:
        return error_response("User not found")

    ctx = await _get_overage_context(db, user, transaction_id)
    if ctx is None:
        return error_response("Transaction not found")

    all_savings = _preview_split(ctx, ctx["overage"])
    all_daily = _preview_split(ctx, 0.0)
    requested = _preview_split(ctx, amount_from_savings)

    return success_response(
        {
            "overage": ctx["overage"],
            "currentDailyLimit": ctx["daily_limit"],
            "currentBankedSavings": ctx["banked_daily_savings"],
            "allFromSavings": all_savings,
            "allFromReduceDaily": all_daily,
            "requestedSplit": requested,
        }
    )


@router.post("/overage/resolve")
async def resolve_overage(payload: OverageResolvePayload, current_user: CurrentUser):
    """Commits how a same-day overage gets absorbed. Always clears
    overage_pending on the transaction regardless of resolution, so it
    stops being surfaced as a pending alert either way.
    """
    db = get_database()
    user = await db.users.find_one({"firebase_uid": current_user["uid"]})
    if not user:
        return error_response("User not found")

    ctx = await _get_overage_context(db, user, payload.transaction_id)
    if ctx is None:
        return error_response("Transaction not found")

    now = datetime.now(timezone.utc)
    txn = ctx["txn"]

    if payload.resolution == "exception":
        # Reclassifying removes it from daily/discretionary math entirely
        # (see _sum_discretionary_spend) — it still reduces the cycle's
        # available_balance via _sum_one_time_exceptions, so the plan
        # stays honest, it just stops distorting TODAY's number.
        await db.transactions.update_one(
            {"_id": txn["_id"]},
            {
                "$set": {
                    "txn_class": "one_time_exception",
                    "classification_source": "user",
                    "classification_confidence": 1.0,
                    "overage_pending": False,
                    "overage_resolved_at": now,
                    "updated_at": now,
                },
                "$unset": {"classification_rule": ""},
            },
        )
        return success_response({"resolution": "exception"})

    # For savings / reduce_daily / hybrid, determine the actual split.
    if payload.resolution == "savings":
        amount_from_savings = ctx["overage"]
    elif payload.resolution == "reduce_daily":
        amount_from_savings = 0.0
    else:  # hybrid
        amount_from_savings = payload.amount_from_savings

    split = _preview_split(ctx, amount_from_savings)

    await db.users.update_one(
        {"_id": user["_id"]},
        {
            "$set": {
                "banked_daily_savings": split["newBankedSavings"],
                "daily_limit_adjustment": ctx["daily_limit_adjustment"]
                + split["perDayReduction"],
                "updated_at": now,
            }
        },
    )
    await db.transactions.update_one(
        {"_id": txn["_id"]},
        {
            "$set": {
                "overage_pending": False,
                "overage_resolved_at": now,
                "updated_at": now,
            }
        },
    )

    return success_response(
        {
            "resolution": payload.resolution,
            "amountFromSavings": split["amountFromSavings"],
            "amountFromDailyReduction": split["amountFromDailyReduction"],
            "newDailyLimit": split["newDailyLimit"],
            "newBankedSavings": split["newBankedSavings"],
        }
    )
