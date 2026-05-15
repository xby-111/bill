from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Index
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from db.database import Base


class Bill(Base):
    __tablename__ = "bills"
    
    # 复合索引优化常用查询
    __table_args__ = (
        # 用户 + 日期查询（按月查询账单）- 覆盖索引
        Index('idx_user_date', 'user_id', 'date'),
        # 用户 + 账单名称查询（名称统计）
        Index('idx_user_name', 'user_id', 'name'),
        # 用户 + 分类查询（分类统计）
        Index('idx_user_category', 'user_id', 'category'),
        # 用户 + 类型查询（收入/支出筛选）
        Index('idx_user_type', 'user_id', 'bill_type'),
        # 用户 + 项目查询
        Index('idx_user_project', 'user_id', 'project_id'),
        # 用户 + 日期 + 类型（月度统计查询优化）
        Index('idx_user_date_type', 'user_id', 'date', 'bill_type'),
        # 用户 + 创建时间（按创建时间排序）
        Index('idx_user_created', 'user_id', 'created_at'),
    )

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(200), nullable=False)  # 账单名称（替代worker字段）
    amount = Column(Float, nullable=False)
    bill_type = Column(String, nullable=False)
    category = Column(String, nullable=False)
    date = Column(DateTime(timezone=True), nullable=False)
    note = Column(String, nullable=True)
    duration_hours = Column(Float, nullable=True)
    hourly_rate = Column(Float, nullable=True)
    pay_method = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    user_id = Column(Integer, ForeignKey("users.id"))
    # project_id 数据库层允许 NULL（兼容旧数据），但 API 层强制必填（新建账单必须关联项目）
    project_id = Column(Integer, ForeignKey("projects.id"), nullable=True)
    
    user = relationship("User", back_populates="bills")
    project = relationship("Project", back_populates="bills")


class BillHistory(Base):
    """账单历史记录表（用于数据回溯）"""
    __tablename__ = "bill_histories"

    id = Column(Integer, primary_key=True, index=True)
    bill_id = Column(Integer, index=True, nullable=False) # 关联原始账单ID
    operation_type = Column(String, nullable=False) # 'UPDATE' 或 'DELETE'
    operated_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # 原始数据快照
    name = Column(String(200), nullable=True)  # 账单名称
    amount = Column(Float, nullable=False)
    bill_type = Column(String, nullable=False)
    category = Column(String, nullable=False)
    date = Column(DateTime(timezone=True), nullable=False)
    note = Column(String, nullable=True)
    duration_hours = Column(Float, nullable=True)
    hourly_rate = Column(Float, nullable=True)
    pay_method = Column(String, nullable=True)
    
    # 记录当时的用户和项目
    user_id = Column(Integer, nullable=False)
    project_id = Column(Integer, nullable=True)  # 记录当时的项目ID，用于恢复已删除账单