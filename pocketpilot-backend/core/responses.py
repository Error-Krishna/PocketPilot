from typing import Any


def success_response(data: Any = None) -> dict:
    return {"success": True, "data": data, "error": None}


def error_response(message: str, data: Any = None) -> dict:
    return {"success": False, "data": data, "error": message}
