from datetime import datetime, timezone

from bson import ObjectId
from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field
from pymongo import ReturnDocument

from core.auth import CurrentUser
from core.database import get_database
from core.responses import error_response, success_response
from models.user import UserResponse, UserUpdate

router = APIRouter(prefix="/users", tags=["users"])


class BankBalanceConfirm(BaseModel):
    # If the user just confirms the existing figure is accurate, the
    # frontend can omit corrected_balance and only send confirmed=true —
    # this simply refreshes last_known_bank_balance_at without changing
    # the number.
    confirmed: bool
    corrected_balance: float | None = Field(None, ge=0)
    # Whether the corrected figure should also become this cycle's actual
    # starting balance (i.e. affect budget math), not just the
    # informational reference number. Ignored if corrected_balance is None.
    apply_to_cycle: bool = False


def _serialize_user(doc: dict) -> dict:
    return UserResponse(
        id=str(doc["_id"]),
        firebase_uid=doc["firebase_uid"],
        email=doc["email"],
        display_name=doc["display_name"],
        phone=doc.get("phone"),
        monthly_budget=doc.get("monthly_budget"),
        budget_reset_date=doc.get("budget_reset_date"),
        lifetime_savings=doc.get("lifetime_savings", 0),
        last_reset_date=doc.get("last_reset_date"),
        cycle_starting_balance=doc.get("cycle_starting_balance"),
        last_known_bank_balance=doc.get("last_known_bank_balance"),
        last_known_bank_balance_at=doc.get("last_known_bank_balance_at"),
        last_rollover_date=doc.get("last_rollover_date"),
        banked_daily_savings=doc.get("banked_daily_savings", 0),
        created_at=doc["created_at"],
        updated_at=doc["updated_at"],
    ).model_dump()


@router.get("/me")
async def get_current_user_profile(current_user: CurrentUser):
    db = get_database()
    user = await db.users.find_one(
        {"firebase_uid": current_user["uid"]}
    )

    if not user:
        return error_response("User not found")

    return success_response(_serialize_user(user))


@router.patch("/me")
async def update_current_user_profile(payload: UserUpdate, current_user: CurrentUser):
    db = get_database()
    updates = payload.model_dump(exclude_unset=True)
    if not updates:
        return error_response("No fields to update")

    updates["updated_at"] = datetime.now(timezone.utc)
    result = await db.users.find_one_and_update(
        {"firebase_uid": current_user["uid"]},
        {"$set": updates},
        return_document=ReturnDocument.AFTER,
    )
    if not result:
        return error_response("User not found")
    return success_response(_serialize_user(result))


@router.post("/me/bank-balance")
async def confirm_or_correct_bank_balance(
    payload: BankBalanceConfirm, current_user: CurrentUser
):
    """User reviews the informational bank-balance figure (opportunistically
    parsed from SMS — see routers/sms.py) and either confirms it's accurate
    or corrects it. A correction always updates the display figure; the
    user separately opts in to also using it as this cycle's real starting
    point for budget math via apply_to_cycle, since those are genuinely
    different actions (see cycle_starting_balance docs in models/user.py).
    """
    db = get_database()
    now = datetime.now(timezone.utc)
    updates: dict = {"updated_at": now}

    if payload.corrected_balance is not None:
        updates["last_known_bank_balance"] = payload.corrected_balance
        updates["last_known_bank_balance_at"] = now
        if payload.apply_to_cycle:
            updates["cycle_starting_balance"] = payload.corrected_balance
    else:
        # Pure confirmation, no number change — still worth bumping the
        # timestamp so the user can see "confirmed as of just now".
        updates["last_known_bank_balance_at"] = now

    result = await db.users.find_one_and_update(
        {"firebase_uid": current_user["uid"]},
        {"$set": updates},
        return_document=ReturnDocument.AFTER,
    )
    if not result:
        return error_response("User not found")
    return success_response(_serialize_user(result))


@router.post("/register", status_code=status.HTTP_201_CREATED)  # added status code
async def register_user(current_user: CurrentUser):
    db = get_database()
    existing = await db.users.find_one({"firebase_uid": current_user["uid"]})
    if existing:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="User already registered")

    now = datetime.now(timezone.utc)
    doc = {
        "_id": ObjectId(),
        "firebase_uid": current_user["uid"],
        "email": current_user.get("email", ""),
        "display_name": current_user.get("name") or current_user.get("email", "Student"),
        "phone": None,
        "monthly_budget": None,
        # Genuinely unset, not defaulted to day 1 — budget_reset_date is
        # optional by design (see routers/budget.py _cycle_bounds and the
        # onboarding flow), so a new user who hasn't chosen a reset day yet
        # correctly falls back to pocket-money-match auto-detection instead
        # of silently being locked to a reset date they never picked.
        "budget_reset_date": None,
        "lifetime_savings": 0.0,
        "created_at": now,
        "updated_at": now,
    }
    await db.users.insert_one(doc)
    return success_response(_serialize_user(doc))
