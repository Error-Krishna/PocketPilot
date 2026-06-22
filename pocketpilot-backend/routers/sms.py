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
    raw_sms: Optional[str] = Field(None, max_length=1000)
    sms_fingerprint: Optional[str] = Field(None, max_length=1200)


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
        fingerprint = txn.sms_fingerprint or txn.raw_sms
        query = {"user_id": user_id}
        if fingerprint:
            query["sms_fingerprint"] = fingerprint
        else:
            query["amount"] = txn.amount
            query["date"] = txn.timestamp

        exists = await db.transactions.find_one(query)
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
            "category": "other",
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

    return success_response({"inserted": inserted, "skipped": skipped})
