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


async def _get_user_id(current_user: CurrentUser) -> str:
    db = get_database()
    user = await db.users.find_one({"firebase_uid": current_user["uid"]})
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return str(user["_id"])


def _coerce_datetime(value: object) -> datetime:
    if isinstance(value, int):
        from calendar import monthrange

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


def _sum_amounts(docs: list[dict]) -> float:
    return float(sum(doc.get("amount", 0) or 0 for doc in docs))


def _sum_expenses(docs: list[dict]) -> float:
    return float(
        sum(
            float(doc.get("amount", 0) or 0)
            for doc in docs
            if doc.get("type") == "expense"
        )
    )


def _net_amount(docs: list[dict]) -> float:
    total = 0.0
    for doc in docs:
        amount = float(doc.get("amount", 0) or 0)
        total += amount if doc.get("type") == "income" else -amount
    return total


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


@router.get("/summary")
async def get_budget_summary(current_user: CurrentUser):
    user_id = await _get_user_id(current_user)
    db = get_database()
    user = await db.users.find_one({"_id": ObjectId(user_id)})
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    monthly_budget = float(user.get("monthly_budget") or 0)
    budget_reset_raw = user.get("budget_reset_date")
    if budget_reset_raw is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="budgetResetDate is not configured for this user",
        )

    today = datetime.now(timezone.utc)
    reset_date = _coerce_datetime(budget_reset_raw)
    next_reset_date = _next_reset_date(reset_date, today)

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

    month_start = today.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    next_month_start = (month_start.replace(day=28) + timedelta(days=4)).replace(
        day=1, hour=0, minute=0, second=0, microsecond=0
    )
    monthly_transactions = await db.transactions.find(
        {
            "user_id": user_id,
            "date": {"$gte": month_start, "$lt": next_month_start},
        }
    ).to_list(length=None)
    spent_this_month = _sum_expenses(monthly_transactions)
    net_irregular = _net_amount(monthly_transactions)
    available_balance = monthly_budget + net_irregular - total_autopays_due
    remaining_balance = available_balance

    remaining_days = max(1, (next_reset_date.date() - today.date()).days)
    daily_limit = remaining_balance / remaining_days

    day_start = today.replace(hour=0, minute=0, second=0, microsecond=0)
    day_end = day_start + timedelta(days=1)
    today_transactions = await db.transactions.find(
        {
            "user_id": user_id,
            "date": {"$gte": day_start, "$lt": day_end},
        }
    ).to_list(length=None)
    spent_today = _sum_expenses(today_transactions)
    income_today = float(
        sum(
            float(doc.get("amount", 0) or 0)
            for doc in today_transactions
            if doc.get("type") == "income"
        )
    )
    saved_today = max(0, daily_limit - spent_today)

    return success_response(
        {
            "monthlyBudget": monthly_budget,
            "totalAutopays": total_autopays_due,
            "totalAutopaysDue": total_autopays_due,
            "availableBalance": available_balance,
            "spentThisMonth": spent_this_month,
            "netIrregularTransactions": net_irregular,
            "remainingBalance": remaining_balance,
            "dailyLimit": daily_limit,
            "spentToday": spent_today,
            "incomeToday": income_today,
            "savedToday": saved_today,
            "remainingDays": remaining_days,
        }
    )
