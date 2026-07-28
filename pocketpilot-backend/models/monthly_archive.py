from datetime import datetime

from pydantic import BaseModel, Field


class MonthlyArchiveBase(BaseModel):
    """Snapshot of one completed budgeting cycle, created at reset time.

    This is the thing that lets a student glance at "last month" without
    re-running any calculation — the numbers are frozen exactly as they
    were the moment the cycle ended.
    """

    cycle_start: datetime
    cycle_end: datetime
    monthly_budget: float = Field(..., ge=0)
    total_spent: float = Field(..., ge=0)
    total_saved: float
    total_autopays: float = Field(0, ge=0)


class MonthlyArchiveInDB(MonthlyArchiveBase):
    id: str = Field(..., alias="_id")
    user_id: str
    created_at: datetime

    model_config = {"populate_by_name": True}


class MonthlyArchiveResponse(MonthlyArchiveBase):
    id: str
    created_at: datetime
