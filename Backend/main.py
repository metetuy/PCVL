from fastapi import FastAPI
from database import Base, engine
from routers import sessions

# Creates all tables defined in models.py, if they don't already exist.
# In a real production app you'd eventually replace this with proper
# migrations (a tool called Alembic) — but for now, this is fine.
Base.metadata.create_all(bind=engine)

app = FastAPI()

app.include_router(sessions.router)