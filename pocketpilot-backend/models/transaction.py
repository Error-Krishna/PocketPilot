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
    # Which of the user's registered bank accounts this transaction came
    # from/went to. Optional since older transactions predate multi-account
    # support, and manual entries may not specify one.
    account_id: Optional[str] = None
    # Original SMS text, when this transaction came from SMS parsing.
    # Surfaced in the transaction detail view so the user can see exactly
    # what the bank actually said, not just our parsed interpretation.
    raw_sms: Optional[str] = None
    # Which specific rule/keyword the classifier matched to reach its
    # decision (e.g. "discretionary_kw:swiggy") — surfaced on the detail
    # screen as "why was this classified this way", so a wrong guess is
    # obvious and explainable rather than a silent black box.
    classification_rule: Optional[str] = None
    # True when this transaction pushed that day's discretionary spend
    # above the flat daily_limit and the user hasn't yet decided how to
    # absorb the overage (savings / reduce future days / hybrid / treat as
    # an emergency exception). See routers/budget.py overage endpoints.
    overage_pending: bool = False
    overage_resolved_at: Optional[datetime] = None


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
    account_id: Optional[str] = None


class TransactionResponse(TransactionBase):
    id: str
    user_id: str
    created_at: datetime
    updated_at: datetime
