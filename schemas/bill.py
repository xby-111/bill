from pydantic import BaseModel, Field, field_validator
from datetime import datetime
from typing import Optional
from utils.constants import BillType, FieldLimits, TimeConstants


class BillBase(BaseModel):
    """账单基础模型"""
    name: str = Field(..., min_length=1, max_length=FieldLimits.BILL_NAME_MAX, description="账单名称")
    amount: float = Field(..., gt=0, description="金额（必须大于0）")
    bill_type: str = Field(..., description="账单类型：income（收入）或 expense（支出）")
    category: str = Field(..., min_length=1, max_length=FieldLimits.CATEGORY_MAX, description="分类名称")
    date: datetime = Field(..., description="账单日期时间")
    note: Optional[str] = Field(None, max_length=FieldLimits.NOTE_MAX, description="备注信息")
    duration_hours: Optional[float] = Field(
        None, 
        ge=TimeConstants.MIN_WORK_HOURS, 
        le=TimeConstants.MAX_WORK_HOURS_PER_DAY, 
        description="工作时长（小时）"
    )
    pay_method: Optional[str] = Field(None, max_length=FieldLimits.PAY_METHOD_MAX, description="支付方式")
    hourly_rate: Optional[float] = Field(None, ge=0, description="时薪（元/小时）")
    # 创建时必填，数据库层允许NULL是为了兼容旧数据
    project_id: int = Field(..., description="所属项目ID（必填，新建账单必须关联项目）")
    
    @field_validator('bill_type')
    @classmethod
    def validate_bill_type(cls, v):
        if v not in BillType.values():
            raise ValueError(f'账单类型只能是 {" 或 ".join(BillType.values())}')
        return v
    
    model_config = {
        "json_schema_extra": {
            "example": {
                "name": "张师傅工作",
                "amount": 240.0,
                "bill_type": "expense",
                "category": "人工",
                "date": "2025-12-27T14:30:00Z",
                "duration_hours": 8.0,
                "hourly_rate": 30.0,
                "pay_method": "现金",
                "note": "装修工作",
                "project_id": 1
            }
        }
    }


class BillCreate(BillBase):
    """创建账单请求模型"""
    pass


class BillUpdate(BaseModel):
    """更新账单请求模型（所有字段可选）"""
    name: Optional[str] = Field(None, min_length=1, max_length=FieldLimits.BILL_NAME_MAX, description="账单名称")
    amount: Optional[float] = Field(None, gt=0, description="金额")
    bill_type: Optional[str] = Field(None, description="账单类型")
    category: Optional[str] = Field(None, min_length=1, max_length=FieldLimits.CATEGORY_MAX, description="分类")
    date: Optional[datetime] = Field(None, description="日期时间")
    note: Optional[str] = Field(None, max_length=FieldLimits.NOTE_MAX, description="备注")
    duration_hours: Optional[float] = Field(
        None, 
        ge=TimeConstants.MIN_WORK_HOURS, 
        le=TimeConstants.MAX_WORK_HOURS_PER_DAY, 
        description="工作时长"
    )
    pay_method: Optional[str] = Field(None, max_length=FieldLimits.PAY_METHOD_MAX, description="支付方式")
    hourly_rate: Optional[float] = Field(None, ge=0, description="时薪")
    project_id: Optional[int] = Field(None, description="所属项目ID")
    
    @field_validator('bill_type')
    @classmethod
    def validate_bill_type(cls, v):
        if v is not None and v not in BillType.values():
            raise ValueError(f'账单类型只能是 {" 或 ".join(BillType.values())}')
        return v


class BillResponse(BaseModel):
    """账单响应模型 - 不继承BillBase，因为响应字段要求不同"""
    id: int
    name: str
    amount: float
    bill_type: str
    category: str
    date: datetime
    note: Optional[str] = None
    duration_hours: Optional[float] = None
    hourly_rate: Optional[float] = None
    pay_method: Optional[str] = None
    project_id: Optional[int] = None  # 响应中可选，兼容旧数据（创建时必填）
    user_id: int
    created_at: datetime
    updated_at: Optional[datetime] = None

    @field_validator('bill_type')
    @classmethod
    def validate_bill_type(cls, v):
        if v not in BillType.values():
            raise ValueError(f'账单类型只能是 {" 或 ".join(BillType.values())}')
        return v

    model_config = {"from_attributes": True}


class BillListItem(BaseModel):
    """
    账单列表项（精简响应）
    
    用于列表页面，只包含必要字段，减少数据传输
    """
    id: int
    name: Optional[str] = None
    amount: float
    bill_type: str
    category: str
    date: datetime
    project_id: Optional[int] = None
    
    model_config = {"from_attributes": True}


class PaginatedBillResponse(BaseModel):
    """
    分页账单响应
    
    包含分页信息和数据列表
    """
    items: list[BillListItem]
    total: int
    page: int
    page_size: int
    has_more: bool


class BillHistoryResponse(BaseModel):
    """账单历史记录响应模型"""
    id: int
    bill_id: int
    operation_type: str
    operated_at: datetime
    name: Optional[str] = None
    amount: float
    bill_type: str
    category: str
    date: datetime
    note: Optional[str] = None
    duration_hours: Optional[float] = None
    hourly_rate: Optional[float] = None
    pay_method: Optional[str] = None
    project_id: Optional[int] = None  # 项目ID，用于恢复已删除账单
    
    model_config = {"from_attributes": True}


class BillStatistics(BaseModel):
    month: str
    total_income: float
    total_expense: float
    net_amount: float


class CategoryStatistics(BaseModel):
    category: str
    amount: float
    percentage: float


class NameStatistics(BaseModel):
    """名称统计模型（按账单名称/人员统计）"""
    name: str
    total_hours: float
    total_amount: float
    bill_count: int


class BillBatchCreate(BaseModel):
    """批量创建账单请求模型"""
    bills: list[BillCreate] = Field(
        ..., 
        min_length=1, 
        max_length=1000, 
        description="账单列表，最多1000条"
    )


class BillBatchDelete(BaseModel):
    """批量删除账单请求模型"""
    bill_ids: list[int] = Field(
        ..., 
        min_length=1, 
        max_length=100, 
        description="账单ID列表，最多100个"
    )


class BatchOperationResponse(BaseModel):
    """批量操作响应模型"""
    message: str
    count: int = Field(description="成功操作的记录数")