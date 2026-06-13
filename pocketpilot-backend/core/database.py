from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase

from core.config import settings

client: AsyncIOMotorClient | None = None
db: AsyncIOMotorDatabase | None = None


async def connect_to_mongo() -> None:
    global client, db
    client = AsyncIOMotorClient(settings.mongodb_uri)
    await client.admin.command("ping")
    db = client[settings.mongodb_db]
    await db.transactions.create_index([("user_id", 1), ("timestamp", -1)], background=True)
    await db.transactions.create_index([("user_id", 1), ("source", 1)], background=True)
    await db.autopays.create_index([("user_id", 1), ("is_active", 1)], background=True)
    await db.users.create_index([("firebase_uid", 1)], unique=True, background=True)


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
