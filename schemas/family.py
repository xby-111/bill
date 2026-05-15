"""
家庭组相关的请求和响应模型
"""
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime


# ==================== 请求模型 ====================

class FamilyCreate(BaseModel):
    """创建家庭组请求"""
    name: str = Field(..., min_length=1, max_length=50, description="家庭名称")


class FamilyJoin(BaseModel):
    """加入家庭组请求"""
    invite_code: str = Field(..., min_length=6, max_length=10, description="邀请码")


# ==================== 响应模型 ====================

class FamilyMemberResponse(BaseModel):
    """家庭成员信息"""
    id: int
    username: str
    joined_at: Optional[datetime] = None
    is_creator: bool = False  # 是否是创建者
    
    class Config:
        from_attributes = True


class FamilyResponse(BaseModel):
    """家庭组信息响应"""
    id: int
    name: str
    invite_code: str
    created_by: int
    created_at: datetime
    member_count: int = 0
    
    class Config:
        from_attributes = True


class FamilyDetailResponse(BaseModel):
    """家庭组详情响应（包含成员列表）"""
    id: int
    name: str
    invite_code: str
    created_by: int
    created_at: datetime
    members: List[FamilyMemberResponse] = []
    
    class Config:
        from_attributes = True


class FamilyBillResponse(BaseModel):
    """家庭账单响应（包含账单所属成员信息）"""
    id: int
    name: str
    amount: float
    bill_type: str
    category: str
    date: datetime
    note: Optional[str] = None
    project_id: Optional[int] = None
    
    # 账单所属用户信息
    user_id: int
    username: str  # 账单所属成员的用户名
    
    class Config:
        from_attributes = True


class FamilyStatisticsResponse(BaseModel):
    """家庭统计响应"""
    total_income: float = 0
    total_expense: float = 0
    balance: float = 0
    member_stats: List[dict] = []  # 每个成员的统计
