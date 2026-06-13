from datetime import datetime, timezone

from bson import ObjectId
from fastapi import APIRouter, HTTPException, status
from pymongo import ReturnDocument

from core.auth import CurrentUser
from core.database import get_database
from core.responses import error_response, success_response
from models.autopay import AutopayCreate, AutopayResponse, AutopayUpdate

router = APIRouter(prefix="/autopays", tags=["autopays"])


def _serialize_autopay(doc: dict) -> dict:
    return AutopayResponse(
        id=str(doc["_id"]),
        user_id=doc["user_id"],
        name=doc["name"],
        amount=doc["amount"],
        frequency=doc["frequency"],
        next_run_date=doc["next_run_date"],
        is_active=doc["is_active"],
        category=doc.get("category"),
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
async def list_autopays(current_user: CurrentUser):
    user_id = await _get_user_id(current_user)
    cursor = get_database().autopays.find({"user_id": user_id}).sort("next_run_date", 1)
    autopays = [_serialize_autopay(doc) async for doc in cursor]
    return success_response(autopays)


@router.post("", status_code=status.HTTP_201_CREATED)
async def create_autopay(payload: AutopayCreate, current_user: CurrentUser):
    user_id = await _get_user_id(current_user)
    now = datetime.now(timezone.utc)
    doc = {
        "_id": ObjectId(),
        "user_id": user_id,
        **payload.model_dump(),
        "created_at": now,
        "updated_at": now,
    }
    await get_database().autopays.insert_one(doc)
    return success_response(_serialize_autopay(doc))


@router.get("/{autopay_id}")
async def get_autopay(autopay_id: str, current_user: CurrentUser):
    user_id = await _get_user_id(current_user)
    doc = await get_database().autopays.find_one(
        {"_id": ObjectId(autopay_id), "user_id": user_id}
    )
    if not doc:
        return error_response("Autopay not found")
    return success_response(_serialize_autopay(doc))


@router.patch("/{autopay_id}")
async def update_autopay(autopay_id: str, payload: AutopayUpdate, current_user: CurrentUser):
    user_id = await _get_user_id(current_user)
    updates = payload.model_dump(exclude_unset=True)
    if not updates:
        return error_response("No fields to update")

    updates["updated_at"] = datetime.now(timezone.utc)
    doc = await get_database().autopays.find_one_and_update(
        {"_id": ObjectId(autopay_id), "user_id": user_id},
        {"$set": updates},
        return_document=ReturnDocument.AFTER,
    )
    if not doc:
        return error_response("Autopay not found")
    return success_response(_serialize_autopay(doc))


@router.delete("/{autopay_id}")
async def delete_autopay(autopay_id: str, current_user: CurrentUser):
    user_id = await _get_user_id(current_user)
    result = await get_database().autopays.delete_one(
        {"_id": ObjectId(autopay_id), "user_id": user_id}
    )
    if result.deleted_count == 0:
        return error_response("Autopay not found")
    return success_response({"deleted": True})
