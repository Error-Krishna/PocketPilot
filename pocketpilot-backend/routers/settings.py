from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field

from core.auth import CurrentUser
from core.database import get_database
from core.responses import success_response

router = APIRouter(prefix="/settings", tags=["settings"])


class SelfAccountsUpdate(BaseModel):
    # Free-text identifiers the classifier matches against SMS text (e.g.
    # "hdfc savings", "acct 1234", "dad's account") to detect transfers
    # between the user's own accounts. Kept as plain strings, not
    # structured account numbers, since that's exactly what
    # core/classifier.py already expects and how sms.py already reads it.
    accounts: list[str] = Field(default_factory=list, max_length=20)


async def _get_user_id(current_user: CurrentUser) -> str:
    db = get_database()
    user = await db.users.find_one({"firebase_uid": current_user["uid"]})
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return str(user["_id"])


@router.get("/self-accounts")
async def get_self_accounts(current_user: CurrentUser):
    user_id = await _get_user_id(current_user)
    db = get_database()
    doc = await db.settings.find_one({"user_id": user_id, "type": "self_accounts"})
    return success_response({"accounts": (doc or {}).get("accounts", [])})


@router.put("/self-accounts")
async def set_self_accounts(payload: SelfAccountsUpdate, current_user: CurrentUser):
    user_id = await _get_user_id(current_user)
    db = get_database()
    now = datetime.now(timezone.utc)

    # Normalize: lowercase, strip, dedupe, drop empties — matches how
    # sms.py/classifier.py compare against lowercased SMS text.
    cleaned = sorted({a.strip().lower() for a in payload.accounts if a.strip()})

    await db.settings.update_one(
        {"user_id": user_id, "type": "self_accounts"},
        {"$set": {"accounts": cleaned, "updated_at": now}, "$setOnInsert": {"created_at": now}},
        upsert=True,
    )
    return success_response({"accounts": cleaned})
