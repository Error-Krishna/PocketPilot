"""Rule-based transaction classification engine.

Classifies a parsed transaction (amount, merchant, raw SMS text, type) into
a TransactionClass — the layer that decides whether a transaction affects
the user's daily "safe to spend" number, or not.

Design goal: high precision over high recall. When confident, tag directly
with ClassificationSource.RULE. When not, tag UNCLASSIFIED with
ClassificationSource.PENDING so it lands in the review queue instead of
silently miscounting toward (or against) the user's daily allowance.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Optional

from models.transaction import ClassificationSource, TransactionCategory, TransactionClass

# Confidence threshold above which a rule-based guess is accepted without
# review. Below this, the transaction is queued for manual confirmation.
CONFIDENCE_THRESHOLD = 0.75


@dataclass
class ClassificationResult:
    txn_class: TransactionClass
    category: TransactionCategory
    confidence: float
    source: ClassificationSource
    matched_rule: Optional[str] = None


@dataclass
class ClassificationInput:
    amount: float
    merchant: Optional[str] = None
    raw_text: Optional[str] = None
    is_income: bool = False
    # Optional context to sharpen decisions:
    active_autopay_names: list[str] = field(default_factory=list)
    known_self_accounts: list[str] = field(default_factory=list)


# ---------------------------------------------------------------------------
# Keyword banks
# ---------------------------------------------------------------------------

_FIXED_COMMITMENT_KEYWORDS = [
    "sip", "mutual fund", "mf ", "systematic investment",
    "emi", "loan installment", "loan emi",
    "netflix", "spotify", "prime video", "hotstar", "youtube premium",
    "subscription", "autopay", "auto-pay", "auto pay", "standing instruction",
    "mandate", "rent", "insurance premium", "premium payment",
]

_TRANSFER_KEYWORDS = [
    "self transfer", "own account", "a/c transfer", "imps to self",
    "transferred to your account", "fund transfer to a/c",
    "e-wallet load", "wallet top-up", "wallet topup", "added to wallet",
]

_REFUND_KEYWORDS = [
    "refund", "reversed", "reversal", "cashback", "chargeback",
    "credited back", "amount reversed",
]

_INCOME_KEYWORDS = [
    "salary", "stipend", "pocket money", "allowance credited",
    "credited by", "has been credited", "credited to your account",
]

_ONE_TIME_EXCEPTION_KEYWORDS = [
    "hospital", "medical", "emergency", "insurance claim",
    "repair", "medicine", "pharmacy", "clinic",
]

_DISCRETIONARY_HINT_KEYWORDS = [
    "swiggy", "zomato", "restaurant", "cafe", "food", "uber", "ola",
    "amazon", "flipkart", "myntra", "movie", "cinema", "bookmyshow",
    "grocery", "supermarket", "shopping",
]

_CATEGORY_KEYWORD_MAP: dict[TransactionCategory, list[str]] = {
    TransactionCategory.FOOD: ["swiggy", "zomato", "restaurant", "cafe", "food", "dominos", "pizza"],
    TransactionCategory.TRANSPORT: ["uber", "ola", "rapido", "irctc", "metro", "fuel", "petrol", "diesel"],
    TransactionCategory.HOUSING: ["rent", "landlord", "electricity", "maintenance", "society"],
    TransactionCategory.ENTERTAINMENT: ["netflix", "spotify", "prime video", "hotstar", "movie", "cinema", "bookmyshow"],
    TransactionCategory.EDUCATION: ["tuition", "course", "udemy", "coursera", "exam fee", "college", "university"],
    TransactionCategory.GIFT: ["gift", "birthday"],
}


def _contains_any(text: str, keywords: list[str]) -> Optional[str]:
    for kw in keywords:
        if kw in text:
            return kw
    return None


def _guess_category(text: str) -> TransactionCategory:
    for category, keywords in _CATEGORY_KEYWORD_MAP.items():
        if _contains_any(text, keywords):
            return category
    return TransactionCategory.OTHER


def classify(input_: ClassificationInput) -> ClassificationResult:
    """Classify a transaction. Pure function, no I/O, fully unit-testable."""

    raw = (input_.raw_text or "").lower()
    merchant = (input_.merchant or "").lower()
    text = f"{raw} {merchant}".strip()

    if not text:
        # No text signal at all (e.g. manual entry with just an amount) —
        # default to discretionary if expense, income_regular if income,
        # both at moderate confidence since the user typed it themselves.
        if input_.is_income:
            return ClassificationResult(
                txn_class=TransactionClass.INCOME_REGULAR,
                category=TransactionCategory.OTHER,
                confidence=0.6,
                source=ClassificationSource.RULE,
                matched_rule="no_text_income_default",
            )
        return ClassificationResult(
            txn_class=TransactionClass.DISCRETIONARY,
            category=TransactionCategory.OTHER,
            confidence=0.6,
            source=ClassificationSource.RULE,
            matched_rule="no_text_expense_default",
        )

    # 1. Known active autopay name match -> fixed commitment, high confidence
    for autopay_name in input_.active_autopay_names:
        name = autopay_name.lower()
        if name and name in text:
            return ClassificationResult(
                txn_class=TransactionClass.FIXED_COMMITMENT,
                category=_guess_category(text),
                confidence=0.95,
                source=ClassificationSource.RULE,
                matched_rule=f"autopay_name:{autopay_name}",
            )

    # 2. Known self-account match -> internal transfer, high confidence
    for acct in input_.known_self_accounts:
        acct_l = acct.lower()
        if acct_l and acct_l in text:
            return ClassificationResult(
                txn_class=TransactionClass.TRANSFER_INTERNAL,
                category=TransactionCategory.OTHER,
                confidence=0.95,
                source=ClassificationSource.RULE,
                matched_rule=f"self_account:{acct}",
            )

    # 3. Income keywords, checked ahead of refund. A specific income term
    #    ("salary", "stipend", "pocket money") is a stronger, more precise
    #    signal than a generic refund word, and only applies to credits in
    #    the first place. This ordering fixes a real failure mode: a late
    #    pocket-money credit whose SMS also contained generic "credited"
    #    phrasing was previously outranked by the refund check below and
    #    misclassified as REFUND, which then wrongly subtracted from —
    #    and could even drive negative — the month's discretionary spend.
    if input_.is_income and (match := _contains_any(text, _INCOME_KEYWORDS)):
        return ClassificationResult(
            txn_class=TransactionClass.INCOME_REGULAR,
            category=TransactionCategory.OTHER,
            confidence=0.85,
            source=ClassificationSource.RULE,
            matched_rule=f"income_kw:{match}",
        )

    # 4. Refund / reversal keywords. Restricted to actual credits — refund
    #    is meaningless on a debit SMS, and gating on is_income keeps this
    #    from firing on unrelated debit text that happens to contain a
    #    shared word.
    if input_.is_income and (match := _contains_any(text, _REFUND_KEYWORDS)):
        return ClassificationResult(
            txn_class=TransactionClass.REFUND,
            category=_guess_category(text),
            confidence=0.9,
            source=ClassificationSource.RULE,
            matched_rule=f"refund_kw:{match}",
        )

    # 5. Fixed commitment keywords (SIP, EMI, subscriptions, rent)
    if match := _contains_any(text, _FIXED_COMMITMENT_KEYWORDS):
        return ClassificationResult(
            txn_class=TransactionClass.FIXED_COMMITMENT,
            category=_guess_category(text),
            confidence=0.9,
            source=ClassificationSource.RULE,
            matched_rule=f"fixed_kw:{match}",
        )

    # 6. Internal transfer keywords
    if match := _contains_any(text, _TRANSFER_KEYWORDS):
        return ClassificationResult(
            txn_class=TransactionClass.TRANSFER_INTERNAL,
            category=TransactionCategory.OTHER,
            confidence=0.85,
            source=ClassificationSource.RULE,
            matched_rule=f"transfer_kw:{match}",
        )

    # 7. One-time exception keywords (medical/emergency)
    if match := _contains_any(text, _ONE_TIME_EXCEPTION_KEYWORDS):
        return ClassificationResult(
            txn_class=TransactionClass.ONE_TIME_EXCEPTION,
            category=TransactionCategory.ONE_TIME,
            confidence=0.8,
            source=ClassificationSource.RULE,
            matched_rule=f"exception_kw:{match}",
        )

    # 8. Strong discretionary hints (known merchant categories)
    if match := _contains_any(text, _DISCRETIONARY_HINT_KEYWORDS):
        return ClassificationResult(
            txn_class=TransactionClass.DISCRETIONARY,
            category=_guess_category(text),
            confidence=0.85,
            source=ClassificationSource.RULE,
            matched_rule=f"discretionary_kw:{match}",
        )

    # 9. Fallback: generic expense/income with a merchant name we don't
    # recognize. Confidence below threshold -> goes to review queue.
    if input_.is_income:
        return ClassificationResult(
            txn_class=TransactionClass.UNCLASSIFIED,
            category=TransactionCategory.OTHER,
            confidence=0.4,
            source=ClassificationSource.PENDING,
            matched_rule="fallback_income_unclassified",
        )

    return ClassificationResult(
        txn_class=TransactionClass.UNCLASSIFIED,
        category=_guess_category(text),
        confidence=0.4,
        source=ClassificationSource.PENDING,
        matched_rule="fallback_expense_unclassified",
    )


def is_confident(result: ClassificationResult) -> bool:
    return result.confidence >= CONFIDENCE_THRESHOLD and result.source == ClassificationSource.RULE
