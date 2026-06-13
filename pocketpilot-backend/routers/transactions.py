from datetime import datetime, timezone

from bson import ObjectId
from fastapi import APIRouter, HTTPException, status
from pymongo import ReturnDocument

from core.auth import CurrentUser
from core.database import get_database
from core.responses import error_response, success_response
from models.transaction import TransactionCreate, TransactionResponse, TransactionUpdate

router = APIRouter(prefix="/transactions", tags=["transactions"])


def _serialize_transaction(doc: dict) -> dict:
    return TransactionResponse(
        id=str(doc["_id"]),
        user_id=doc["user_id"],
        amount=doc["amount"],
        type=doc["type"],
        category=doc["category"],
        description=doc.get("description"),
        date=doc["date"],
        created_at=doc["created_at"],
        updated_at=doc["updated_at"],
    ).model_dump()


async def _get_user_id(current_user: CurrentUser) -> str:
    db = get_database()
    user = await db.users.find_one({"firebase_uid": current_user["uid"]})
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return str(user["_id"])


@router.get("")
async def list_transactions(current_user: CurrentUser):
    user_id = await _get_user_id(current_user)
    db = get_database()
    cursor = db.transactions.find({"user_id": user_id}).sort("date", -1)
    transactions = [_serialize_transaction(doc) async for doc in cursor]
    return success_response(transactions)


@router.post("", status_code=status.HTTP_201_CREATED)
async def create_transaction(payload: TransactionCreate, current_user: CurrentUser):
    user_id = await _get_user_id(current_user)
    now = datetime.now(timezone.utc)
    doc = {
        "_id": ObjectId(),
        "user_id": user_id,
        **payload.model_dump(),
        "created_at": now,
        "updated_at": now,
    }
    await get_database().transactions.insert_one(doc)
    return success_response(_serialize_transaction(doc))


@router.get("/{transaction_id}")
async def get_transaction(transaction_id: str, current_user: CurrentUser):
    user_id = await _get_user_id(current_user)
    doc = await get_database().transactions.find_one(
        {"_id": ObjectId(transaction_id), "user_id": user_id}
    )
    if not doc:
        return error_response("Transaction not found")
    return success_response(_serialize_transaction(doc))


@router.patch("/{transaction_id}")
async def update_transaction(
    transaction_id: str, payload: TransactionUpdate, current_user: CurrentUser
):
    user_id = await _get_user_id(current_user)
    updates = payload.model_dump(exclude_unset=True)
    if not updates:
        return error_response("No fields to update")

    updates["updated_at"] = datetime.now(timezone.utc)
    doc = await get_database().transactions.find_one_and_update(
        {"_id": ObjectId(transaction_id), "user_id": user_id},
        {"$set": updates},
        return_document=ReturnDocument.AFTER,
    )
    if not doc:
        return error_response("Transaction not found")
    return success_response(_serialize_transaction(doc))


@router.delete("/{transaction_id}")
async def delete_transaction(transaction_id: str, current_user: CurrentUser):
    user_id = await _get_user_id(current_user)
    result = await get_database().transactions.delete_one(
        {"_id": ObjectId(transaction_id), "user_id": user_id}
    )
    if result.deleted_count == 0:
        return error_response("Transaction not found")
    return success_response({"deleted": True})
