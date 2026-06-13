from datetime import datetime, timezone
from typing import Optional

from bson import ObjectId
from fastapi import APIRouter, status
from pydantic import BaseModel, Field

from core.auth import CurrentUser
from core.database import get_database
from core.responses import error_response, success_response

router = APIRouter(prefix="/sms", tags=["sms"])


class SmsTransaction(BaseModel):
    amount: float = Field(..., gt=0)
    merchant: Optional[str] = Field(None, max_length=200)
    timestamp: datetime
    source: str = "sms"


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

    for txn in payload.transactions:
        exists = await db.transactions.find_one(
            {
                "user_id": user_id,
                "amount": txn.amount,
                "timestamp": txn.timestamp,
            }
        )
        if exists:
            skipped += 1
            continue

        doc = {
            "_id": ObjectId(),
            "user_id": user_id,
            "amount": txn.amount,
            "merchant": txn.merchant,
            "source": txn.source,
            "type": "expense",
            "timestamp": txn.timestamp,
            "created_at": now,
        }
        await db.transactions.insert_one(doc)
        inserted += 1

    return success_response({"inserted": inserted, "skipped": skipped})
