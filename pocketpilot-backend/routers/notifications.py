from datetime import datetime, timezone

from bson import ObjectId
from fastapi import APIRouter, HTTPException, status
from pymongo import ReturnDocument
from pydantic import BaseModel, Field

from core.auth import CurrentUser
from core.database import get_database
from core.responses import error_response, success_response

router = APIRouter(prefix="/notifications", tags=["notifications"])


class NotificationCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    body: str = Field(..., min_length=1, max_length=1000)
    type: str = Field(default="info", max_length=50)


def _serialize_notification(doc: dict) -> dict:
    return {
        "id": str(doc["_id"]),
        "user_id": doc["user_id"],
        "title": doc["title"],
        "body": doc["body"],
        "type": doc["type"],
        "read": doc.get("read", False),
        "created_at": doc["created_at"],
    }


async def _get_user_id(current_user: CurrentUser) -> str:
    db = get_database()
    user = await db.users.find_one({"firebase_uid": current_user["uid"]})
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return str(user["_id"])


@router.get("")
async def list_notifications(current_user: CurrentUser):
    user_id = await _get_user_id(current_user)
    cursor = get_database().notifications.find({"user_id": user_id}).sort("created_at", -1)
    notifications = [_serialize_notification(doc) async for doc in cursor]
    return success_response(notifications)


@router.post("", status_code=status.HTTP_201_CREATED)
async def create_notification(payload: NotificationCreate, current_user: CurrentUser):
    user_id = await _get_user_id(current_user)
    now = datetime.now(timezone.utc)
    doc = {
        "_id": ObjectId(),
        "user_id": user_id,
        **payload.model_dump(),
        "read": False,
        "created_at": now,
    }
    await get_database().notifications.insert_one(doc)
    return success_response(_serialize_notification(doc))


@router.patch("/{notification_id}/read")
async def mark_notification_read(notification_id: str, current_user: CurrentUser):
    user_id = await _get_user_id(current_user)
    doc = await get_database().notifications.find_one_and_update(
        {"_id": ObjectId(notification_id), "user_id": user_id},
        {"$set": {"read": True}},
        return_document=ReturnDocument.AFTER,
    )
    if not doc:
        return error_response("Notification not found")
    return success_response(_serialize_notification(doc))


@router.delete("/{notification_id}")
async def delete_notification(notification_id: str, current_user: CurrentUser):
    user_id = await _get_user_id(current_user)
    result = await get_database().notifications.delete_one(
        {"_id": ObjectId(notification_id), "user_id": user_id}
    )
    if result.deleted_count == 0:
        return error_response("Notification not found")
    return success_response({"deleted": True})
