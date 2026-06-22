import asyncio

from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase

from core.config import settings

client: AsyncIOMotorClient | None = None
db: AsyncIOMotorDatabase | None = None


async def connect_to_mongo() -> None:
    global client, db
    try:
        client = AsyncIOMotorClient(settings.mongodb_uri, serverSelectionTimeoutMS=5000)
        await client.admin.command("ping")
        db = client[settings.mongodb_db]
        await asyncio.gather(
            # FIX: use 'date' instead of 'timestamp' – all queries sort/filter by 'date'
            db.transactions.create_index([("user_id", 1), ("date", -1)], background=True),
            db.transactions.create_index([("user_id", 1), ("source", 1)], background=True),
            # New index for O(1) SMS dedup lookups
            db.transactions.create_index(
                [("user_id", 1), ("sms_fingerprint", 1)],
                sparse=True,
                background=True,
            ),
            db.autopays.create_index([("user_id", 1), ("is_active", 1)], background=True),
            db.users.create_index([("firebase_uid", 1)], unique=True, background=True),
        )
    except Exception as e:
        client = None
        db = None
        raise RuntimeError(f"Failed to connect to MongoDB: {e}") from e


async def close_mongo_connection() -> None:
    global client, db
    if client is not None:
        client.close()
    client = None
    db = None


def get_database() -> AsyncIOMotorDatabase:
    if db is None:
        raise RuntimeError("Database is not initialized")
    return db