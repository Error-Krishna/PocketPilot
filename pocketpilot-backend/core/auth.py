from typing import Annotated

import firebase_admin
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from firebase_admin import auth, credentials

from core.config import settings

_bearer_scheme = HTTPBearer(auto_error=False)
_firebase_initialized = False


import json
import os
from firebase_admin import exceptions

def init_firebase() -> None:
    global _firebase_initialized
    if _firebase_initialized:
        return

    # Prefer credentials supplied via env var (FIREBASE_CREDENTIALS_JSON) so
    # this works on hosts like Render where committing the service-account
    # JSON file to the repo isn't appropriate. Falls back to the local file
    # path for local development, where the JSON file is easy to keep
    # out of git via .gitignore instead.
    creds_json = os.environ.get("FIREBASE_CREDENTIALS_JSON")
    try:
        if creds_json:
            cred_dict = json.loads(creds_json)
            cred = credentials.Certificate(cred_dict)
        else:
            cred_path = settings.firebase_credentials_path
            if not os.path.exists(cred_path):
                raise FileNotFoundError(
                    f"Firebase credentials file not found at {cred_path}, and "
                    "FIREBASE_CREDENTIALS_JSON env var is not set either."
                )
            cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
    except (ValueError, exceptions.FirebaseError, json.JSONDecodeError) as e:
        raise RuntimeError(f"Failed to initialize Firebase: {e}") from e

    _firebase_initialized = True


async def get_current_user(
    credentials: Annotated[
        HTTPAuthorizationCredentials | None, Depends(_bearer_scheme)
    ],
) -> dict:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid authorization header",
        )

    try:
        decoded = auth.verify_id_token(credentials.credentials)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        ) from exc

    return decoded


CurrentUser = Annotated[dict, Depends(get_current_user)]
