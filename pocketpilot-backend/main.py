from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from core.auth import init_firebase
from core.config import settings
from core.database import close_mongo_connection, connect_to_mongo
from routers import autopays, budget, notifications, savings, sms, transactions, users


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_firebase()
    await connect_to_mongo()
    yield
    await close_mongo_connection()


app = FastAPI(
    title=settings.app_name,
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

API_PREFIX = "/api/v1"

app.include_router(users.router, prefix=API_PREFIX)
app.include_router(transactions.router, prefix=API_PREFIX)
app.include_router(autopays.router, prefix=API_PREFIX)
app.include_router(budget.router, prefix=API_PREFIX)
app.include_router(savings.router, prefix=API_PREFIX)
app.include_router(notifications.router, prefix=API_PREFIX)
app.include_router(sms.router, prefix=API_PREFIX)


@app.get("/health")
async def health_check():
    return {"status": "ok"}
