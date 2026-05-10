from sqlalchemy import Column, Integer, String, DateTime
from sqlalchemy.sql import func
from database import Base


class SessionRecord(Base):

    __tablename__ = "sessions"

    id = Column(Integer, primary_key=True, index = True)

    duration = Column(Integer, nullable=False)

    type = Column(String, nullable= False)

    # Will be used for past records
    date = Column(DateTime(timezone=True), nullable= True)


    #Automatically created by server, won't rely on the client's date
    created_at = Column(DateTime(timezone=True), nullable= False, server_default= func.now())

