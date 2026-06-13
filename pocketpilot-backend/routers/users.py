from datetime import datetime, timezone

from bson import ObjectId
from fastapi import APIRouter, HTTPException, status
from pymongo import ReturnDocument

from core.auth import CurrentUser
from core.database import get_database
from core.responses import error_response, success_response
from models.user import UserResponse, UserUpdate

router = APIRouter(prefix="/users", tags=["users"])


def _serialize_user(doc: dict) -> dict:
    return UserResponse(
        id=str(doc["_id"]),
        firebase_uid=doc["firebase_uid"],
        email=doc["email"],
        display_name=doc["display_name"],
        phone=doc.get("phone"),
        monthly_budget=doc.get("monthly_budget"),
        budget_reset_date=doc.get("budget_reset_date"),
        created_at=doc["created_at"],
        updated_at=doc["updated_at"],
    ).model_dump()


@router.get("/me")
async def get_current_user_profile(current_user: CurrentUser):
    db = get_database()
    user = await db.users.find_one({"firebase_uid": current_user["uid"]})
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


@router.post("/register", status_code=status.HTTP_201_CREATED)
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
        "monthly_budget": 0.0,
        "budget_reset_date": 1,
        "created_at": now,
        "updated_at": now,
    }
    await db.users.insert_one(doc)
    return success_response(_serialize_user(doc))
