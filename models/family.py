"""
家庭组模型

用于实现账单共享功能：
- 创建家庭组
- 通过邀请码加入
- 查看家庭成员账单
"""
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from db.database import Base
import secrets
import string


def generate_invite_code(length: int = 6) -> str:
    """生成随机邀请码（大写字母+数字）"""
    chars = string.ascii_uppercase + string.digits
    return ''.join(secrets.choice(chars) for _ in range(length))


class Family(Base):
    """家庭组表"""
    __tablename__ = "families"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(50), nullable=False)  # 家庭名称
    invite_code = Column(String(10), unique=True, index=True, nullable=False)  # 邀请码
    created_by = Column(Integer, ForeignKey("users.id"), nullable=False)  # 创建者
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # 关系：家庭成员（反向引用）
    members = relationship("User", back_populates="family", foreign_keys="User.family_id")
    
    # 创建者用户（区分于成员关系）
    creator = relationship("User", foreign_keys=[created_by])
