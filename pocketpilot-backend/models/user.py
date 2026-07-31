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
    # Daily-rollover state (see routers/budget.py _apply_daily_rollover).
    # last_rollover_date tracks which calendar day the stored daily figures
    # are for, so a lazy check on each request can detect "it's a new day"
    # without needing a cron job. banked_daily_savings accumulates each
    # day's genuinely unused flat allowance once midnight passes for it —
    # separate from lifetime_savings, which only grows at cycle reset.
    last_rollover_date: Optional[datetime] = None
    banked_daily_savings: float = Field(0, ge=0)
    # Cumulative reduction applied to the flat daily_limit for the rest of
    # the current cycle, from resolving "this purchase went over today's
    # limit" decisions where the user chose to reduce future days rather
    # than draw from savings. Reset to 0 at cycle reset (see routers/reset.py).
    daily_limit_adjustment: float = Field(0, ge=0)


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
