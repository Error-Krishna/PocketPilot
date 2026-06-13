from datetime import datetime, timezone
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


class TransactionType(str, Enum):
    INCOME = "income"
    EXPENSE = "expense"


class TransactionCategory(str, Enum):
    FOOD = "food"
    TRANSPORT = "transport"
    HOUSING = "housing"
    ENTERTAINMENT = "entertainment"
    EDUCATION = "education"
    OTHER = "other"


class TransactionBase(BaseModel):
    amount: float = Field(..., gt=0)
    type: TransactionType = TransactionType.EXPENSE
    category: TransactionCategory = TransactionCategory.OTHER
    description: Optional[str] = Field(None, max_length=500)
    merchant: Optional[str] = Field(None, max_length=200)
    source: str = Field(default="manual")
    date: Optional[datetime] = Field(default_factory=lambda: datetime.now(timezone.utc))


class TransactionCreate(TransactionBase):
    pass


class TransactionUpdate(BaseModel):
    amount: Optional[float] = Field(None, gt=0)
    type: Optional[TransactionType] = None
    category: Optional[TransactionCategory] = None
    description: Optional[str] = Field(None, max_length=500)
    date: Optional[datetime] = None


class TransactionResponse(TransactionBase):
    id: str
    user_id: str
    created_at: datetime
    updated_at: datetime
