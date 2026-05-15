from fastapi import APIRouter, Depends, Query
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List, Optional
from db.async_database import get_async_db
from schemas.bill import (
    BillCreate, BillResponse, BillUpdate, BillStatistics, 
    CategoryStatistics, NameStatistics,
    BillHistoryResponse, BillBatchCreate, BillBatchDelete, BatchOperationResponse
)
from services.async_bill_service import (
    create_bill_async, get_bills_by_user_async, get_bill_by_id_async, 
    update_bill_async, delete_bill_async, get_monthly_statistics_async, 
    get_category_statistics_async, get_name_statistics_async, 
    get_bill_history_async, create_bills_batch_async, delete_bills_batch_async,
    export_bills_to_csv_async, restore_bill_version_async
)
from routers.auth import get_current_user
from schemas.user import UserResponse
import io

router = APIRouter(prefix="/bills", tags=["账单"])


@router.post("/", response_model=BillResponse, summary="创建账单")
async def create_bill_endpoint(
    bill: BillCreate, 
    db: AsyncSession = Depends(get_async_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    创建新账单记录 (异步)
    """
    return await create_bill_async(db=db, bill=bill, user_id=current_user.id)


@router.get("/", response_model=List[BillResponse], summary="获取账单列表")
async def get_bills(
    skip: int = Query(0, ge=0, description="跳过的记录数"),
    limit: int = Query(100, ge=1, le=500, description="返回的记录数，最大500"),
    month: Optional[str] = Query(None, description="格式: YYYY-MM"),
    bill_type: Optional[str] = Query(None, description="income 或 expense"),
    worker: Optional[str] = Query(None, description="按工人姓名筛选"),
    category: Optional[str] = Query(None, description="按分类筛选"),
    project_id: Optional[int] = Query(None, description="按项目ID筛选"),
    db: AsyncSession = Depends(get_async_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """获取当前用户的账单列表 (异步)"""
    return await get_bills_by_user_async(
        db=db, 
        user_id=current_user.id, 
        skip=skip, 
        limit=limit,
        month=month,
        bill_type=bill_type,
        worker=worker,
        category=category,
        project_id=project_id
    )


@router.get("/export", summary="导出账单CSV")
async def export_bills(
    month: Optional[str] = Query(None, description="格式: YYYY-MM，可选"),
    db: AsyncSession = Depends(get_async_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    导出账单为 CSV 文件下载 (异步接口).
    """
    csv_content = await export_bills_to_csv_async(db=db, user_id=current_user.id, month=month)
    
    # 添加 BOM 以支持 Excel 正确识别中文
    csv_bytes = ('\ufeff' + csv_content).encode('utf-8')
    
    filename = f"bills_{month}.csv" if month else "bills_all.csv"
    
    return StreamingResponse(
        io.BytesIO(csv_bytes),
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": f"attachment; filename={filename}"}
    )


@router.get("/statistics/monthly", response_model=BillStatistics, summary="统计查询")
async def get_monthly_stats(
    month: Optional[str] = Query(None, description="格式: YYYY-MM，单月查询"),
    date: Optional[str] = Query(None, description="格式: YYYY-MM-DD，单日查询"),
    start_date: Optional[str] = Query(None, description="格式: YYYY-MM-DD，范围开始日期"),
    end_date: Optional[str] = Query(None, description="格式: YYYY-MM-DD，范围结束日期"),
    start_month: Optional[str] = Query(None, description="格式: YYYY-MM，范围开始月份"),
    end_month: Optional[str] = Query(None, description="格式: YYYY-MM，范围结束月份"),
    project_id: Optional[int] = Query(None, description="按项目ID筛选"),
    db: AsyncSession = Depends(get_async_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """获取统计数据，支持单日、单月、日期范围、月份范围查询 (异步+缓存)"""
    return await get_monthly_statistics_async(
        db=db, user_id=current_user.id, 
        month=month, date=date,
        start_date=start_date, end_date=end_date,
        start_month=start_month, end_month=end_month,
        project_id=project_id
    )


@router.get("/statistics/category", response_model=List[CategoryStatistics], summary="分类统计")
async def get_category_stats(
    month: Optional[str] = Query(None, description="格式: YYYY-MM，可选"),
    project_id: Optional[int] = Query(None, description="按项目ID筛选"),
    db: AsyncSession = Depends(get_async_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """获取分类统计 (异步+缓存)"""
    return await get_category_statistics_async(db=db, user_id=current_user.id, month=month, project_id=project_id)


@router.get("/statistics/name", response_model=List[NameStatistics], summary="名称统计")
async def get_name_stats(
    month: Optional[str] = Query(None, description="格式: YYYY-MM，单月查询"),
    date: Optional[str] = Query(None, description="格式: YYYY-MM-DD，单日查询"),
    start_date: Optional[str] = Query(None, description="格式: YYYY-MM-DD，范围开始日期"),
    end_date: Optional[str] = Query(None, description="格式: YYYY-MM-DD，范围结束日期"),
    start_month: Optional[str] = Query(None, description="格式: YYYY-MM，范围开始月份"),
    end_month: Optional[str] = Query(None, description="格式: YYYY-MM，范围结束月份"),
    project_id: Optional[int] = Query(None, description="按项目ID筛选"),
    db: AsyncSession = Depends(get_async_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """按账单名称/人员统计汇总 (异步+缓存)"""
    return await get_name_statistics_async(
        db=db, user_id=current_user.id, 
        month=month, date=date,
        start_date=start_date, end_date=end_date,
        start_month=start_month, end_month=end_month,
        project_id=project_id
    )


@router.get("/{bill_id}", response_model=BillResponse, summary="获取单个账单")
async def get_bill(
    bill_id: int,
    db: AsyncSession = Depends(get_async_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """根据账单ID获取详情 (异步)"""
    return await get_bill_by_id_async(db=db, bill_id=bill_id, user_id=current_user.id)


@router.put("/{bill_id}", response_model=BillResponse, summary="更新账单")
async def update_bill_endpoint(
    bill_id: int,
    bill: BillUpdate,
    db: AsyncSession = Depends(get_async_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """更新指定账单 (异步)"""
    return await update_bill_async(db=db, bill_id=bill_id, bill=bill, user_id=current_user.id)


@router.delete("/{bill_id}", summary="删除账单")
async def delete_bill_endpoint(
    bill_id: int,
    db: AsyncSession = Depends(get_async_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """删除指定账单 (异步)"""
    return await delete_bill_async(db=db, bill_id=bill_id, user_id=current_user.id)


@router.post("/batch", response_model=BatchOperationResponse, summary="批量创建账单")
async def create_bills_batch_endpoint(
    request: BillBatchCreate,
    db: AsyncSession = Depends(get_async_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """批量创建账单 (异步)"""
    bills = await create_bills_batch_async(db=db, bills=request.bills, user_id=current_user.id)
    return BatchOperationResponse(message="批量创建成功", count=len(bills))


@router.delete("/batch", response_model=BatchOperationResponse, summary="批量删除账单")
async def delete_bills_batch_endpoint(
    request: BillBatchDelete,
    db: AsyncSession = Depends(get_async_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """批量删除账单 (异步)"""
    result = await delete_bills_batch_async(db=db, bill_ids=request.bill_ids, user_id=current_user.id)
    return BatchOperationResponse(message=result["message"], count=result["deleted_count"])


@router.get("/{bill_id}/history", response_model=List[BillHistoryResponse], summary="查看账单修改历史")
async def get_bill_history_endpoint(
    bill_id: int,
    db: AsyncSession = Depends(get_async_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """查看某个账单的所有历史版本 (异步)"""
    return await get_bill_history_async(db=db, bill_id=bill_id, user_id=current_user.id)


@router.post("/history/{history_id}/restore", response_model=BillResponse, summary="回滚到历史版本")
async def restore_version_endpoint(
    history_id: int,
    db: AsyncSession = Depends(get_async_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    回滚到指定的历史版本 (异步接口).
    """
    return await restore_bill_version_async(db=db, history_id=history_id, user_id=current_user.id)