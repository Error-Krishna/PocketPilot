from datetime import datetime, timezone
from typing import Optional

from pydantic import BaseModel, Field


class BankAccountBase(BaseModel):
    """A bank account the user has registered so their transactions can be
    tagged with *which* account they came from, and so self-transfers
    between the user's own registered accounts can be detected reliably
    (structured match) instead of only via free-text SMS hints.
    """

    bank_name: str = Field(..., min_length=1, max_length=100)
    nickname: Optional[str] = Field(None, max_length=100)
    # Last 4 digits only — never store a full account number.
    last_four: Optional[str] = Field(None, min_length=4, max_length=4, pattern=r"^\d{4}$")
    account_type: str = Field(default="savings")  # savings, current, wallet, etc.
    is_primary: bool = False
    # Free-text hints the SMS matcher uses to attribute an incoming SMS to
    # this specific account (e.g. bank SMS sender ID fragments, or phrases
    # like "a/c ...1234"). Kept separate from bank_name/last_four since
    # real SMS phrasing varies more than the structured fields capture.
    sms_hints: list[str] = Field(default_factory=list, max_length=10)


class BankAccountCreate(BankAccountBase):
    pass


class BankAccountUpdate(BaseModel):
    bank_name: Optional[str] = Field(None, min_length=1, max_length=100)
    nickname: Optional[str] = Field(None, max_length=100)
    last_four: Optional[str] = Field(None, min_length=4, max_length=4, pattern=r"^\d{4}$")
    account_type: Optional[str] = None
    is_primary: Optional[bool] = None
    sms_hints: Optional[list[str]] = Field(None, max_length=10)


class BankAccountInDB(BankAccountBase):
    id: str = Field(..., alias="_id")
    user_id: str
    created_at: datetime
    updated_at: datetime

    model_config = {"populate_by_name": True}


class BankAccountResponse(BankAccountBase):
    id: str
    created_at: datetime
    updated_at: datetime
