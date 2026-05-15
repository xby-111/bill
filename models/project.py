from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Index
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from db.database import Base


class Project(Base):
    """项目表 - 用于分组管理账单"""
    __tablename__ = "projects"
    
    __table_args__ = (
        # 用户 + 项目名索引
        Index('idx_user_project_name', 'user_id', 'name'),
    )
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False)  # 项目名称
    description = Column(String(500), nullable=True)  # 项目描述
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    user = relationship("User", back_populates="projects")
    
    # 项目下的账单
    bills = relationship("Bill", back_populates="project", cascade="all, delete-orphan")
