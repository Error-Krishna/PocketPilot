from datetime import datetime, timedelta, timezone
from typing import Optional
import re

from bson import ObjectId
from fastapi import APIRouter, status
from pydantic import BaseModel, Field

from core.auth import CurrentUser
from core.classifier import ClassificationInput, classify, is_confident
from core.database import get_database
from core.responses import error_response, success_response
from models.transaction import ClassificationSource, TransactionClass

router = APIRouter(prefix="/sms", tags=["sms"])

# Matches common bank SMS balance phrasing: "Avl Bal: Rs.1234.50",
# "Available Balance INR 500", "Bal Rs 999", etc. Informational only —
# never fed into budget math (see routers/budget.py) since it's not
# reliable enough to calculate against: not every bank includes it, and it
# goes stale the instant a non-SMS transaction happens.
_BALANCE_PATTERN = re.compile(
    r'(?:avl\.?\s*bal(?:ance)?|available\s*bal(?:ance)?|\bbal(?:ance)?)\s*[:\-]?\s*'
    r'(?:rs\.?|inr|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
    re.IGNORECASE,
)


def _extract_bank_balance(raw_sms: str | None) -> float | None:
    if not raw_sms:
        return None
    match = _BALANCE_PATTERN.search(raw_sms)
    if not match:
        return None
    try:
        return float(match.group(1).replace(",", ""))
    except ValueError:
        return None

# Matched within this tolerance of monthly_budget to count as "looks like
# pocket money" — SMS amounts are sometimes off by a rupee or two due to
# rounding in how the student describes their allowance vs. what actually
# lands (e.g. a bank fee shaved off, or the parent rounding up).
_POCKET_MONEY_MATCH_TOLERANCE = 5.0
# Minimum days since the last reset before an amount-match is eligible to
# prompt an EARLY reset when the user has NOT configured a fixed reset day.
# This is what stops a random ₹5000 credit halfway through the month (that
# happens to equal the budget) from repeatedly re-prompting.
_MIN_DAYS_BETWEEN_UNSCHEDULED_RESETS = 20


class SmsTransaction(BaseModel):
    amount: float = Field(..., gt=0)
    merchant: Optional[str] = Field(None, max_length=200)
    timestamp: datetime
    source: str = "sms"
    raw_sms: Optional[str] = Field(None, max_length=1000)
    sms_fingerprint: Optional[str] = Field(None, max_length=1200)
    # True when the parser detected a credit (money in) rather than a debit.
    # Defaults to False since most SMS parsing today targets debit alerts.
    is_credit: bool = False


class SmsSyncPayload(BaseModel):
    transactions: list[SmsTransaction] = Field(..., min_length=1, max_length=100)


@router.post("/sync", status_code=status.HTTP_201_CREATED)
async def sync_sms_transactions(payload: SmsSyncPayload, current_user: CurrentUser):
    db = get_database()
    user = await db.users.find_one({"firebase_uid": current_user["uid"]})
    if not user:
        return error_response("User not found")

    user_id = str(user["_id"])
    now = datetime.now(timezone.utc)
    inserted = 0
    skipped = 0
    needs_review = 0
    reset_candidate_transaction_id: str | None = None
    # Track the most recent balance mention across this batch; only the
    # latest one (by SMS timestamp) is worth keeping since it supersedes
    # any earlier ones in the same sync.
    latest_bank_balance: float | None = None
    latest_bank_balance_at: datetime | None = None

    monthly_budget = float(user.get("monthly_budget") or 0)
    budget_reset_date = user.get("budget_reset_date")
    last_reset_date = user.get("last_reset_date")
    days_since_last_reset = (
        (now - last_reset_date).days if last_reset_date else float("inf")
    )

    # Pull classification context once per sync batch rather than per txn.
    active_autopays = await db.autopays.find(
        {"user_id": user_id, "is_active": True}
    ).to_list(length=None)
    autopay_names = [a["name"] for a in active_autopays if a.get("name")]

    user_settings = await db.settings.find_one({"user_id": user_id, "type": "self_accounts"})
    self_accounts = (user_settings or {}).get("accounts", [])

    for txn in payload.transactions:
        fingerprint = txn.sms_fingerprint or txn.raw_sms
        query = {"user_id": user_id}
        if fingerprint:
            query["sms_fingerprint"] = fingerprint
        else:
            # No fingerprint available: fall back to a tolerant match on
            # amount + merchant within a small time window, since exact
            # timestamp equality is unreliable across SMS parse retries.
            window = timedelta(minutes=2)
            query["amount"] = txn.amount
            query["merchant"] = txn.merchant
            query["date"] = {
                "$gte": txn.timestamp - window,
                "$lte": txn.timestamp + window,
            }

        exists = await db.transactions.find_one(query)
        if exists:
            skipped += 1
            continue

        result = classify(
            ClassificationInput(
                amount=txn.amount,
                merchant=txn.merchant,
                raw_text=txn.raw_sms,
                is_income=txn.is_credit,
                active_autopay_names=autopay_names,
                known_self_accounts=self_accounts,
            )
        )
        confident = is_confident(result)
        if not confident:
            needs_review += 1

        doc = {
            "_id": ObjectId(),
            "user_id": user_id,
            "amount": txn.amount,
            "merchant": txn.merchant,
            "source": txn.source,
            "type": "income" if txn.is_credit else "expense",
            "category": result.category.value,
            "txn_class": result.txn_class.value,
            "classification_source": result.source.value,
            "classification_confidence": result.confidence,
            "date": txn.timestamp,
            "created_at": now,
            "updated_at": now,
        }
        if fingerprint:
            doc["sms_fingerprint"] = fingerprint
        if txn.raw_sms:
            doc["raw_sms"] = txn.raw_sms
        await db.transactions.insert_one(doc)
        inserted += 1

        # Opportunistic, informational-only balance capture (see
        # _extract_bank_balance docstring above) — never affects
        # classification or reset eligibility, purely a reference value
        # surfaced on the dashboard.
        balance_hint = _extract_bank_balance(txn.raw_sms)
        if balance_hint is not None and (
            latest_bank_balance_at is None or txn.timestamp > latest_bank_balance_at
        ):
            latest_bank_balance = balance_hint
            latest_bank_balance_at = txn.timestamp

        # Reset-eligibility check. Only ever a prompt candidate — nothing
        # resets automatically here, the user must confirm via
        # POST /reset/confirm. Two independent eligibility paths, matching
        # the product rule exactly:
        #  - a fixed reset day is configured -> only eligible on that exact
        #    calendar day
        #  - no fixed day configured -> eligible any time, but only after
        #    at least _MIN_DAYS_BETWEEN_UNSCHEDULED_RESETS days have passed
        #    since the last reset, so a coincidental mid-month credit of
        #    the same amount doesn't repeatedly re-prompt
        if (
            txn.is_credit
            and monthly_budget > 0
            and abs(txn.amount - monthly_budget) <= _POCKET_MONEY_MATCH_TOLERANCE
            and reset_candidate_transaction_id is None
        ):
            eligible = False
            if budget_reset_date is not None:
                eligible = now.day == int(budget_reset_date)
            else:
                eligible = days_since_last_reset >= _MIN_DAYS_BETWEEN_UNSCHEDULED_RESETS

            if eligible:
                reset_candidate_transaction_id = str(doc["_id"])

    if latest_bank_balance is not None:
        await db.users.update_one(
            {"_id": user["_id"]},
            {
                "$set": {
                    "last_known_bank_balance": latest_bank_balance,
                    "last_known_bank_balance_at": latest_bank_balance_at,
                }
            },
        )

    return success_response(
        {
            "inserted": inserted,
            "skipped": skipped,
            "needs_review": needs_review,
            "reset_candidate_transaction_id": reset_candidate_transaction_id,
        }
    )
