from datetime import datetime, timezone

from bson import ObjectId
from fastapi import APIRouter, HTTPException, status
from pymongo import ReturnDocument
from pydantic import BaseModel

from core.auth import CurrentUser
from core.database import get_database
from core.responses import error_response, success_response
from models.transaction import ClassificationSource, TransactionClass, TransactionResponse

router = APIRouter(prefix="/review", tags=["review"])


class ReviewDecision(BaseModel):
    txn_class: TransactionClass


def _serialize_transaction(doc: dict) -> dict:
    return TransactionResponse(
        id=str(doc["_id"]),
        user_id=doc["user_id"],
        amount=doc["amount"],
        type=doc["type"],
        category=doc["category"],
        description=doc.get("description"),
        merchant=doc.get("merchant"),
        source=doc.get("source", "manual"),
        date=doc["date"],
        created_at=doc["created_at"],
        updated_at=doc["updated_at"],
        txn_class=doc.get("txn_class", TransactionClass.UNCLASSIFIED.value),
        classification_source=doc.get(
            "classification_source", ClassificationSource.PENDING.value
        ),
        classification_confidence=doc.get("classification_confidence", 0.0),
    ).model_dump()


async def _get_user_id(current_user: CurrentUser) -> str:
    db = get_database()
    user = await db.users.find_one({"firebase_uid": current_user["uid"]})
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return str(user["_id"])


@router.get("/queue")
async def get_review_queue(current_user: CurrentUser):
    """Transactions the rule-based classifier could not confidently place."""
    user_id = await _get_user_id(current_user)
    cursor = (
        get_database()
        .transactions.find(
            {
                "user_id": user_id,
                "classification_source": ClassificationSource.PENDING.value,
            }
        )
        .sort("date", -1)
    )
    docs = [_serialize_transaction(doc) async for doc in cursor]
    return success_response(docs)


@router.get("/queue/count")
async def get_review_queue_count(current_user: CurrentUser):
    user_id = await _get_user_id(current_user)
    count = await get_database().transactions.count_documents(
        {
            "user_id": user_id,
            "classification_source": ClassificationSource.PENDING.value,
        }
    )
    return success_response({"count": count})


@router.patch("/{transaction_id}")
async def confirm_classification(
    transaction_id: str, payload: ReviewDecision, current_user: CurrentUser
):
    """User confirms/corrects a transaction's class from the review queue."""
    user_id = await _get_user_id(current_user)
    now = datetime.now(timezone.utc)
    doc = await get_database().transactions.find_one_and_update(
        {"_id": ObjectId(transaction_id), "user_id": user_id},
        {
            "$set": {
                "txn_class": payload.txn_class.value,
                "classification_source": ClassificationSource.USER.value,
                "classification_confidence": 1.0,
                "updated_at": now,
            }
        },
        return_document=ReturnDocument.AFTER,
    )
    if not doc:
        return error_response("Transaction not found")
    return success_response(_serialize_transaction(doc))
