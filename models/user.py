from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from db.database import Base


class User(Base):
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # 家庭组关联（可空，未加入家庭则为空）
    family_id = Column(Integer, ForeignKey("families.id"), nullable=True)
    family_joined_at = Column(DateTime(timezone=True), nullable=True)  # 加入家庭时间
    
    # 关系
    bills = relationship("Bill", back_populates="user")
    projects = relationship("Project", back_populates="user")
    family = relationship("Family", back_populates="members", foreign_keys=[family_id])