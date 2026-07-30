from datetime import datetime, timezone

from bson import ObjectId
from fastapi import APIRouter, HTTPException, status

from core.auth import CurrentUser
from core.database import get_database
from core.responses import error_response, success_response
from models.bank_account import BankAccountCreate, BankAccountUpdate

router = APIRouter(prefix="/bank-accounts", tags=["bank-accounts"])


async def _get_user_id(current_user: CurrentUser) -> str:
    db = get_database()
    user = await db.users.find_one({"firebase_uid": current_user["uid"]})
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return str(user["_id"])


def _serialize(doc: dict) -> dict:
    return {
        "id": str(doc["_id"]),
        "bank_name": doc["bank_name"],
        "nickname": doc.get("nickname"),
        "last_four": doc.get("last_four"),
        "account_type": doc.get("account_type", "savings"),
        "is_primary": doc.get("is_primary", False),
        "sms_hints": doc.get("sms_hints", []),
        "created_at": doc["created_at"].isoformat(),
        "updated_at": doc["updated_at"].isoformat(),
    }


@router.get("")
async def list_bank_accounts(current_user: CurrentUser):
    user_id = await _get_user_id(current_user)
    db = get_database()
    accounts = await db.bank_accounts.find({"user_id": user_id}).sort("created_at", 1).to_list(
        length=None
    )
    return success_response([_serialize(a) for a in accounts])


@router.post("", status_code=status.HTTP_201_CREATED)
async def create_bank_account(payload: BankAccountCreate, current_user: CurrentUser):
    user_id = await _get_user_id(current_user)
    db = get_database()
    now = datetime.now(timezone.utc)

    doc = payload.model_dump()
    doc["_id"] = ObjectId()
    doc["user_id"] = user_id
    doc["created_at"] = now
    doc["updated_at"] = now
    # Normalize hints the same way sms.py/classifier.py compare text.
    doc["sms_hints"] = sorted({h.strip().lower() for h in doc.get("sms_hints", []) if h.strip()})

    if doc.get("is_primary"):
        # Only one primary account at a time — unset any existing one.
        await db.bank_accounts.update_many(
            {"user_id": user_id, "is_primary": True}, {"$set": {"is_primary": False}}
        )

    await db.bank_accounts.insert_one(doc)
    return success_response(_serialize(doc))


@router.patch("/{account_id}")
async def update_bank_account(
    account_id: str, payload: BankAccountUpdate, current_user: CurrentUser
):
    user_id = await _get_user_id(current_user)
    db = get_database()

    existing = await db.bank_accounts.find_one(
        {"_id": ObjectId(account_id), "user_id": user_id}
    )
    if not existing:
        return error_response("Bank account not found")

    updates = payload.model_dump(exclude_unset=True)
    if "sms_hints" in updates and updates["sms_hints"] is not None:
        updates["sms_hints"] = sorted(
            {h.strip().lower() for h in updates["sms_hints"] if h.strip()}
        )
    updates["updated_at"] = datetime.now(timezone.utc)

    if updates.get("is_primary"):
        await db.bank_accounts.update_many(
            {"user_id": user_id, "is_primary": True}, {"$set": {"is_primary": False}}
        )

    await db.bank_accounts.update_one(
        {"_id": ObjectId(account_id)}, {"$set": updates}
    )
    updated = await db.bank_accounts.find_one({"_id": ObjectId(account_id)})
    return success_response(_serialize(updated))


@router.delete("/{account_id}")
async def delete_bank_account(account_id: str, current_user: CurrentUser):
    user_id = await _get_user_id(current_user)
    db = get_database()
    result = await db.bank_accounts.delete_one(
        {"_id": ObjectId(account_id), "user_id": user_id}
    )
    if result.deleted_count == 0:
        return error_response("Bank account not found")
    # Transactions already tagged with this account_id are left as-is
    # (historical record) — they just point at an id that no longer
    # resolves to a live account, which the frontend can show as "Deleted
    # account" rather than losing the transaction itself.
    return success_response({"deleted": True})
