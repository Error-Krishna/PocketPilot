from datetime import datetime, timezone

from bson import ObjectId
from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field

from core.auth import CurrentUser
from core.database import get_database
from core.responses import error_response, success_response
from routers.budget import (
    _as_utc_datetime,
    _cycle_bounds,
    _sum_amounts,
    _sum_discretionary_spend,
    _sum_one_time_exceptions,
)

router = APIRouter(prefix="/reset", tags=["reset"])


class ResetConfirmPayload(BaseModel):
    # The transaction id sms.py flagged as a reset candidate. Required so
    # we're confirming the same credit the user was actually asked about,
    # not just trusting a bare "yes" against whatever is current.
    transaction_id: str = Field(..., min_length=1)
    confirmed: bool


async def _get_user(current_user: CurrentUser) -> dict:
    db = get_database()
    user = await db.users.find_one({"firebase_uid": current_user["uid"]})
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return user


@router.post("/confirm")
async def confirm_reset(payload: ResetConfirmPayload, current_user: CurrentUser):
    db = get_database()
    user = await _get_user(current_user)
    user_id = str(user["_id"])

    candidate = await db.transactions.find_one(
        {"_id": ObjectId(payload.transaction_id), "user_id": user_id}
    )
    if not candidate:
        return error_response("Reset candidate transaction not found")

    if not payload.confirmed:
        # User said "no, this isn't my pocket money for a new cycle" —
        # leave the transaction's classification as-is (already filed as
        # income_regular by the classifier) and do nothing further. This
        # is a legitimate, common outcome: e.g. a bonus or gift that just
        # happens to match the budget amount.
        return success_response({"reset": False})

    now = datetime.now(timezone.utc)
    monthly_budget = float(user.get("monthly_budget") or 0)
    cycle_starting_balance = user.get("cycle_starting_balance")
    cycle_base_amount = (
        float(cycle_starting_balance)
        if cycle_starting_balance is not None
        else monthly_budget
    )
    budget_reset_raw = user.get("budget_reset_date")
    account_created_at = user.get("created_at") or now
    last_reset_date = user.get("last_reset_date")

    cycle_start, cycle_end = _cycle_bounds(
        budget_reset_raw, last_reset_date, account_created_at, now
    )

    # Archive the ending cycle using the SAME window/logic the dashboard
    # summary already uses, so the archived numbers match exactly what the
    # student saw right before confirming the reset.
    cycle_transactions = await db.transactions.find(
        {
            "user_id": user_id,
            "date": {"$gte": cycle_start, "$lt": now},
        }
    ).to_list(length=None)

    active_autopays = await db.autopays.find(
        {"user_id": user_id, "is_active": True}
    ).to_list(length=None)
    due_autopays = [
        a
        for a in active_autopays
        if (nr := _as_utc_datetime(a.get("next_run_date"))) is not None and nr <= now
    ]
    total_autopays = _sum_amounts(due_autopays)

    spent = max(0.0, _sum_discretionary_spend(cycle_transactions))
    net_irregular = _sum_one_time_exceptions(cycle_transactions)
    # Same starting-point logic as the live dashboard summary (see
    # routers/budget.py) so the archived numbers match exactly what the
    # student saw right before confirming — duplicated here rather than
    # imported since this endpoint needs cycle_base_amount specifically,
    # not the full summary payload.
    available = cycle_base_amount + net_irregular - total_autopays
    saved = available - spent  # can be negative if the student overspent

    archive_doc = {
        "_id": ObjectId(),
        "user_id": user_id,
        "cycle_start": cycle_start,
        "cycle_end": now,
        "monthly_budget": monthly_budget,
        "total_spent": spent,
        "total_saved": saved,
        "total_autopays": total_autopays,
        "created_at": now,
    }
    await db.monthly_archives.insert_one(archive_doc)

    # Lifetime savings only grows by genuine positive savings — an
    # overspent cycle (saved < 0) shouldn't claw back money the student
    # already banked in previous cycles.
    lifetime_delta = max(0.0, saved)
    new_lifetime_savings = float(user.get("lifetime_savings") or 0) + lifetime_delta

    await db.users.update_one(
        {"_id": user["_id"]},
        {
            "$set": {
                "lifetime_savings": new_lifetime_savings,
                "last_reset_date": now,
                "updated_at": now,
            },
            # Clear the starting-balance override on reset: the fresh cycle
            # defaults back to the full monthly_budget unless the student
            # tells the app otherwise again (e.g. via a future onboarding-
            # style prompt), rather than silently carrying forward a stale
            # number from the cycle that just ended.
            "$unset": {"cycle_starting_balance": ""},
        },
    )

    return success_response(
        {
            "reset": True,
            "archivedCycle": {
                "cycleStart": cycle_start.isoformat(),
                "cycleEnd": now.isoformat(),
                "totalSpent": spent,
                "totalSaved": saved,
            },
            "lifetimeSavings": new_lifetime_savings,
        }
    )


@router.get("/history")
async def get_reset_history(current_user: CurrentUser):
    db = get_database()
    user = await _get_user(current_user)
    user_id = str(user["_id"])

    archives = (
        await db.monthly_archives.find({"user_id": user_id})
        .sort("cycle_end", -1)
        .to_list(length=None)
    )

    return success_response(
        {
            "history": [
                {
                    "id": str(a["_id"]),
                    "cycleStart": a["cycle_start"].isoformat(),
                    "cycleEnd": a["cycle_end"].isoformat(),
                    "monthlyBudget": a["monthly_budget"],
                    "totalSpent": a["total_spent"],
                    "totalSaved": a["total_saved"],
                    "totalAutopays": a.get("total_autopays", 0),
                }
                for a in archives
            ],
            "lifetimeSavings": float(user.get("lifetime_savings") or 0),
        }
    )
