from datetime import datetime, timezone

from bson import ObjectId
from fastapi import APIRouter, HTTPException, status
from pymongo import ReturnDocument
from pydantic import BaseModel, Field

from core.auth import CurrentUser
from core.database import get_database
from core.responses import error_response, success_response

router = APIRouter(prefix="/savings", tags=["savings"])


class SavingsGoalCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    target_amount: float = Field(..., gt=0)
    current_amount: float = Field(default=0, ge=0)
    target_date: datetime | None = None


class SavingsGoalUpdate(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=100)
    target_amount: float | None = Field(None, gt=0)
    current_amount: float | None = Field(None, ge=0)
    target_date: datetime | None = None


def _serialize_goal(doc: dict) -> dict:
    return {
        "id": str(doc["_id"]),
        "user_id": doc["user_id"],
        "name": doc["name"],
        "target_amount": doc["target_amount"],
        "current_amount": doc["current_amount"],
        "target_date": doc.get("target_date"),
        "created_at": doc["created_at"],
        "updated_at": doc["updated_at"],
    }


async def _get_user_id(current_user: CurrentUser) -> str:
    db = get_database()
    user = await db.users.find_one({"firebase_uid": current_user["uid"]})
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return str(user["_id"])


@router.get("")
async def list_savings_goals(current_user: CurrentUser):
    user_id = await _get_user_id(current_user)
    cursor = get_database().savings.find({"user_id": user_id}).sort("created_at", -1)
    goals = [_serialize_goal(doc) async for doc in cursor]
    return success_response(goals)


@router.post("", status_code=status.HTTP_201_CREATED)
async def create_savings_goal(payload: SavingsGoalCreate, current_user: CurrentUser):
    user_id = await _get_user_id(current_user)
    now = datetime.now(timezone.utc)
    doc = {
        "_id": ObjectId(),
        "user_id": user_id,
        **payload.model_dump(),
        "created_at": now,
        "updated_at": now,
    }
    await get_database().savings.insert_one(doc)
    return success_response(_serialize_goal(doc))


@router.patch("/{goal_id}")
async def update_savings_goal(goal_id: str, payload: SavingsGoalUpdate, current_user: CurrentUser):
    user_id = await _get_user_id(current_user)
    updates = payload.model_dump(exclude_unset=True)
    if not updates:
        return error_response("No fields to update")

    updates["updated_at"] = datetime.now(timezone.utc)
    doc = await get_database().savings.find_one_and_update(
        {"_id": ObjectId(goal_id), "user_id": user_id},
        {"$set": updates},
        return_document=ReturnDocument.AFTER,
    )
    if not doc:
        return error_response("Savings goal not found")
    return success_response(_serialize_goal(doc))


@router.delete("/{goal_id}")
async def delete_savings_goal(goal_id: str, current_user: CurrentUser):
    user_id = await _get_user_id(current_user)
    result = await get_database().savings.delete_one(
        {"_id": ObjectId(goal_id), "user_id": user_id}
    )
    if result.deleted_count == 0:
        return error_response("Savings goal not found")
    return success_response({"deleted": True})
