"""FastAPI application entry point for Qalqan."""
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from app.database import engine, Base
from app.models import *  # noqa – import all models so they register with Base


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Create tables on startup."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        await conn.execute(
            text(
                """
                ALTER TABLE qalqan_profiles
                ADD COLUMN IF NOT EXISTS subscription_period VARCHAR(20) DEFAULT 'monthly',
                ADD COLUMN IF NOT EXISTS subscription_status VARCHAR(20) DEFAULT 'active',
                ADD COLUMN IF NOT EXISTS subscription_expires_at TIMESTAMP
                """
            )
        )
    yield


app = FastAPI(
    title="Qalqan Family Protection API",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

from app.routers import auth, qalqan

app.include_router(auth.router)
app.include_router(qalqan.router)


@app.get("/")
async def root():
    return {"status": "ok", "app": "Qalqan Family Protection API"}
