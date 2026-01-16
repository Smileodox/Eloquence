from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.config import settings
from app.routers import auth, llm

app = FastAPI(
    title="Eloquence Auth API",
    description="Authentication and LLM proxy service for Eloquence",
    version="1.1.0"
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins_list,
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

# Include routers
app.include_router(auth.router)
app.include_router(llm.router)

@app.get("/")
async def root():
    return {
        "service": "Eloquence Auth API",
        "status": "running",
        "version": "1.0.0"
    }
