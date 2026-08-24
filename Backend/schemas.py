from pydantic import BaseModel, ConfigDict
from datetime import datetime
from typing import Optional, Literal

class SessionCreate(BaseModel):
    duration: int
    type: Literal["work","break","stopwatch"]

    # only used for historical imports
    created_at: Optional[datetime] = None


class SessionResponse(BaseModel):
    id: int
    duration: int
    type: Literal["work","break","stopwatch"]
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)