from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional, List, TYPE_CHECKING, Any
from utils.constants import FieldLimits

if TYPE_CHECKING:
    from schemas.bill import BillResponse


class ProjectBase(BaseModel):
    """项目基础模型"""
    name: str = Field(
        ..., 
        min_length=1, 
        max_length=FieldLimits.PROJECT_NAME_MAX, 
        description="项目名称"
    )
    description: Optional[str] = Field(
        None, 
        max_length=FieldLimits.PROJECT_DESC_MAX, 
        description="项目描述"
    )


class ProjectCreate(ProjectBase):
    """创建项目请求"""
    pass


class ProjectUpdate(BaseModel):
    """更新项目请求"""
    name: Optional[str] = Field(None, min_length=1, max_length=FieldLimits.PROJECT_NAME_MAX)
    description: Optional[str] = Field(None, max_length=FieldLimits.PROJECT_DESC_MAX)


class ProjectResponse(ProjectBase):
    """项目响应"""
    id: int
    user_id: int
    created_at: datetime
    updated_at: Optional[datetime] = None
    bill_count: int = 0  # 项目下的账单数量
    
    model_config = {"from_attributes": True}


class ProjectWithBills(ProjectResponse):
    """包含账单的项目响应"""
    bills: List[Any] = []  # 使用 Any 避免循环导入
    
    model_config = {"from_attributes": True}
