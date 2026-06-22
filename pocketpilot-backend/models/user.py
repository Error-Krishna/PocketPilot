from datetime import datetime
from typing import Optional

from pydantic import BaseModel, EmailStr, Field


class UserBase(BaseModel):
    email: EmailStr
    display_name: str = Field(..., min_length=1, max_length=100)
    phone: Optional[str] = None
    monthly_budget: Optional[float] = Field(None, ge=0)
    budget_reset_date: Optional[int] = Field(None, ge=1, le=31)


class UserCreate(UserBase):
    firebase_uid: str


class UserUpdate(BaseModel):
    display_name: Optional[str] = Field(None, min_length=1, max_length=100)
    phone: Optional[str] = None
    monthly_budget: Optional[float] = Field(None, ge=0)
    budget_reset_date: Optional[int] = Field(None, ge=1, le=31)


class UserInDB(UserBase):
    id: str = Field(..., alias="_id")
    firebase_uid: str
    created_at: datetime
    updated_at: datetime

    model_config = {"populate_by_name": True}


class UserResponse(UserBase):
    id: str
    firebase_uid: str
    created_at: datetime
    updated_at: datetime
