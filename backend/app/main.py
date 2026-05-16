"""FastAPI application entry point."""
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.database import engine, Base
from app.models import *  # noqa – import all models so they register with Base


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Create tables on startup."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield


app = FastAPI(
    title="PRY – Language Learning API",
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

# Include routers
from app.routers import auth, profile, content, progress, exam, placement, trainers, qalqan

app.include_router(auth.router)
app.include_router(profile.router)
app.include_router(content.router)
app.include_router(progress.router)
app.include_router(exam.router)
app.include_router(placement.router)
app.include_router(trainers.router)
app.include_router(qalqan.router)


@app.get("/")
async def root():
    return {"status": "ok", "app": "PRY Language Learning API"}
