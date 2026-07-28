from datetime import datetime
from typing import Optional

from pydantic import BaseModel, EmailStr, Field


class UserBase(BaseModel):
    email: EmailStr
    display_name: str = Field(..., min_length=1, max_length=100)
    phone: Optional[str] = None
    monthly_budget: Optional[float] = Field(None, ge=0)
    budget_reset_date: Optional[int] = Field(None, ge=1, le=31)
    lifetime_savings: float = Field(0, ge=0)
    last_reset_date: Optional[datetime] = None
    # User-entered "how much of this cycle's money do I actually have left
    # right now", captured at onboarding or at reset. Overrides the default
    # assumption that the full monthly_budget is untouched at cycle start —
    # this is what lets someone onboard mid-cycle, after already spending
    # some of this cycle's pocket money before installing the app, without
    # the budget math silently assuming they have more than they really do.
    cycle_starting_balance: Optional[float] = Field(None, ge=0)
    # Informational only — opportunistically parsed from bank SMS "Avl
    # Bal"/"Bal" text when present. Never used in budget math (see
    # note in routers/budget.py); shown on the dashboard as a loose
    # reference point only, since it can drift out of sync with reality
    # the moment a non-SMS transaction happens.
    last_known_bank_balance: Optional[float] = None
    last_known_bank_balance_at: Optional[datetime] = None


class UserCreate(UserBase):
    firebase_uid: str


class UserUpdate(BaseModel):
    display_name: Optional[str] = Field(None, min_length=1, max_length=100)
    phone: Optional[str] = None
    monthly_budget: Optional[float] = Field(None, ge=0)
    budget_reset_date: Optional[int] = Field(None, ge=1, le=31)
    cycle_starting_balance: Optional[float] = Field(None, ge=0)


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
