from pydantic import BaseModel
from datetime import datetime
from typing import Optional


class BillBase(BaseModel):
    amount: float
    bill_type: str
    category: str
    date: datetime
    note: Optional[str] = None
    worker: Optional[str] = None
    duration_hours: Optional[float] = None
    pay_method: Optional[str] = None
    hourly_rate: Optional[float] = None


class BillCreate(BillBase):
    pass


class BillUpdate(BaseModel):
    amount: Optional[float] = None
    bill_type: Optional[str] = None
    category: Optional[str] = None
    date: Optional[datetime] = None
    note: Optional[str] = None
    worker: Optional[str] = None
    duration_hours: Optional[float] = None
    pay_method: Optional[str] = None
    hourly_rate: Optional[float] = None


class BillResponse(BillBase):
    id: int
    user_id: int
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class BillStatistics(BaseModel):
    month: str
    total_income: float
    total_expense: float
    net_amount: float


class CategoryStatistics(BaseModel):
    category: str
    amount: float
    percentage: float


class WorkerStatistics(BaseModel):
    worker: str
    total_hours: float
    total_amount: float
    bill_count: int