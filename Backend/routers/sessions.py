from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from sqlalchemy import desc
from datetime import datetime, timezone
from typing import List

from database import get_db
from models import SessionRecord
from schemas import SessionCreate, SessionResponse

router = APIRouter(prefix = "/sessions",  tags=["sessions"])

# POST /sessions - create a new session record
@router.post("/", response_model=SessionResponse)
def create_session(session_data: SessionCreate, db: Session = Depends(get_db)):

    # If the client sent a created_at use it otherwise use current server time
    timestamp = session_data.created_at or datetime.now(timezone.utc)

    new_session = SessionRecord(
        duration = session_data.duration,
        type = session_data.type,
        created_at = timestamp
                                )

    db.add(new_session)
    db.commit()
    db.refresh(new_session)

    return new_session

@router.get("/", response_model=List[SessionResponse])
def get_sessions(
    limit: int = Query(default=20, le=1000), # ?limit=20 in the URL, capped at 100 max
    db: Session = Depends(get_db)
):
    sessions = (
        db.query(SessionRecord)
            .order_by(desc(SessionRecord.created_at))
            .limit(limit)
            .all()
    )

    return sessions