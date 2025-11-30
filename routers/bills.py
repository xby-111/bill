from fastapi import APIRouter, Depends, Query
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from typing import List, Optional
from db.database import get_db
from schemas.bill import BillCreate, BillResponse, BillUpdate, BillStatistics, CategoryStatistics, WorkerStatistics
from services.bill_service import (
    create_bill, get_bills_by_user, get_bill_by_id, 
    update_bill, delete_bill, get_monthly_statistics, 
    get_category_statistics, get_worker_statistics, export_bills_to_csv
)
from routers.auth import get_current_user
from schemas.user import UserResponse
import io

router = APIRouter(prefix="/bills", tags=["bills"])

@router.post("/", response_model=BillResponse, summary="创建账单")
def create_bill_endpoint(
    bill: BillCreate, 
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    创建新账单记录。
    
    - **amount**: 金额（必填）
    - **bill_type**: 类型，income（收入）或 expense（支出）
    - **category**: 分类，如"人工"、"材料"、"餐饮"等
    - **date**: 日期时间
    - **worker**: 工人/服务者姓名（可选）
    - **duration_hours**: 工作时长，单位小时（可选）
    - **pay_method**: 支付方式（可选）
    - **note**: 备注（可选）
    """
    return create_bill(db=db, bill=bill, user_id=current_user.id)

@router.get("/", response_model=List[BillResponse], summary="获取账单列表")
def get_bills(
    skip: int = 0,
    limit: int = 100,
    month: Optional[str] = Query(None, description="格式: YYYY-MM"),
    bill_type: Optional[str] = Query(None, description="income 或 expense"),
    worker: Optional[str] = Query(None, description="按工人姓名筛选"),
    category: Optional[str] = Query(None, description="按分类筛选"),
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """获取当前用户的账单列表，支持按月份、类型、工人、分类筛选"""
    return get_bills_by_user(
        db=db, 
        user_id=current_user.id, 
        skip=skip, 
        limit=limit,
        month=month,
        bill_type=bill_type,
        worker=worker,
        category=category
    )

@router.get("/export", summary="导出账单CSV")
def export_bills(
    month: Optional[str] = Query(None, description="格式: YYYY-MM，可选"),
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    导出账单为 CSV 文件下载。
    
    可选按月份筛选，不传则导出全部。
    """
    csv_content = export_bills_to_csv(db=db, user_id=current_user.id, month=month)
    
    # 添加 BOM 以支持 Excel 正确识别中文
    csv_bytes = ('\ufeff' + csv_content).encode('utf-8')
    
    filename = f"bills_{month}.csv" if month else "bills_all.csv"
    
    return StreamingResponse(
        io.BytesIO(csv_bytes),
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": f"attachment; filename={filename}"}
    )

@router.get("/statistics/monthly", response_model=BillStatistics, summary="月度统计")
def get_monthly_stats(
    month: str = Query(..., description="格式: YYYY-MM"),
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """获取指定月份的收入、支出、净额统计"""
    return get_monthly_statistics(db=db, user_id=current_user.id, month=month)

@router.get("/statistics/category", response_model=List[CategoryStatistics], summary="分类统计")
def get_category_stats(
    month: Optional[str] = Query(None, description="格式: YYYY-MM，可选"),
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """获取分类统计（各分类金额及占比）"""
    return get_category_statistics(db=db, user_id=current_user.id, month=month)

@router.get("/statistics/worker", response_model=List[WorkerStatistics], summary="工人统计")
def get_worker_stats(
    month: Optional[str] = Query(None, description="格式: YYYY-MM，可选"),
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    按工人/服务者统计汇总。
    
    返回每个工人的总工时、总金额、记录数。
    """
    return get_worker_statistics(db=db, user_id=current_user.id, month=month)

@router.get("/{bill_id}", response_model=BillResponse, summary="获取单个账单")
def get_bill(
    bill_id: int,
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """根据账单ID获取详情"""
    return get_bill_by_id(db=db, bill_id=bill_id, user_id=current_user.id)

@router.put("/{bill_id}", response_model=BillResponse, summary="更新账单")
def update_bill_endpoint(
    bill_id: int,
    bill: BillUpdate,
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """更新指定账单（仅传入需要修改的字段）"""
    return update_bill(db=db, bill_id=bill_id, bill=bill, user_id=current_user.id)

@router.delete("/{bill_id}", summary="删除账单")
def delete_bill_endpoint(
    bill_id: int,
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """删除指定账单"""
    return delete_bill(db=db, bill_id=bill_id, user_id=current_user.id)