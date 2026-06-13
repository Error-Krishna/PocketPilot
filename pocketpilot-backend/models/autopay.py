from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


class AutopayFrequency(str, Enum):
    WEEKLY = "weekly"
    BIWEEKLY = "biweekly"
    MONTHLY = "monthly"


class AutopayBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    amount: float = Field(..., gt=0)
    frequency: AutopayFrequency
    next_run_date: datetime
    is_active: bool = True
    category: Optional[str] = None


class AutopayCreate(AutopayBase):
    pass


class AutopayUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    amount: Optional[float] = Field(None, gt=0)
    frequency: Optional[AutopayFrequency] = None
    next_run_date: Optional[datetime] = None
    is_active: Optional[bool] = None
    category: Optional[str] = None


class AutopayResponse(AutopayBase):
    id: str
    user_id: str
    created_at: datetime
    updated_at: datetime
