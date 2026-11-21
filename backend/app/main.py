import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import get_settings
from .routers import admin, ai, app_api, auth, payments

settings = get_settings()
logging.basicConfig(level=logging.INFO)

app = FastAPI(
    title=settings.app_name,
    version="1.0.0",
    description="Backend for the NutriLens app and admin panel.",
    docs_url="/docs" if settings.is_dev else None,
    redoc_url=None,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    # Development: any localhost port (Flutter web, admin dev server).
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?" if settings.is_dev else None,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(app_api.router)
app.include_router(ai.router)
app.include_router(payments.router)
app.include_router(admin.router)


@app.get("/health", tags=["meta"])
async def health() -> dict[str, str]:
    return {"status": "ok"}
