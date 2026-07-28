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
    GIFT = "gift"
    ONE_TIME = "one_time"
    OTHER = "other"


class TransactionClass(str, Enum):
    """How a transaction affects the user's monthly spending PLAN.

    Orthogonal to `type` (income/expense) and `category` (food/transport/
    etc). Answers: "should this move the needle on today's safe-to-spend?"
    """

    FIXED_COMMITMENT = "fixed_commitment"  # SIP, EMI, subscription, rent
    DISCRETIONARY = "discretionary"  # everyday spend, counts against daily allowance
    TRANSFER_INTERNAL = "transfer_internal"  # self-to-self, own accounts/wallets
    REFUND = "refund"  # reverses an earlier discretionary spend
    INCOME_REGULAR = "income_regular"  # salary/allowance/pocket money — funds the plan
    ONE_TIME_EXCEPTION = "one_time_exception"  # emergency/irregular, excluded from daily math
    UNCLASSIFIED = "unclassified"  # needs manual review


class ClassificationSource(str, Enum):
    RULE = "rule"  # decided by the rule-based classifier with high confidence
    USER = "user"  # user manually confirmed/corrected it
    PENDING = "pending"  # awaiting user review


class TransactionBase(BaseModel):
    amount: float = Field(..., gt=0)
    type: TransactionType = TransactionType.EXPENSE
    category: TransactionCategory = TransactionCategory.OTHER
    description: Optional[str] = Field(None, max_length=500)
    merchant: Optional[str] = Field(None, max_length=200)
    source: str = Field(default="manual")
    date: Optional[datetime] = Field(default_factory=lambda: datetime.now(timezone.utc))
    txn_class: TransactionClass = TransactionClass.DISCRETIONARY
    classification_source: ClassificationSource = ClassificationSource.USER
    classification_confidence: float = Field(default=1.0, ge=0, le=1)


class TransactionCreate(TransactionBase):
    pass


class TransactionUpdate(BaseModel):
    amount: Optional[float] = Field(None, gt=0)
    type: Optional[TransactionType] = None
    category: Optional[TransactionCategory] = None
    description: Optional[str] = Field(None, max_length=500)
    date: Optional[datetime] = None
    txn_class: Optional[TransactionClass] = None
    classification_source: Optional[ClassificationSource] = None
    classification_confidence: Optional[float] = Field(None, ge=0, le=1)


class TransactionResponse(TransactionBase):
    id: str
    user_id: str
    created_at: datetime
    updated_at: datetime
