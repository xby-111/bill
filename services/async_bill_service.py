"""
异步账单服务模块

提供异步数据库操作和缓存集成：
- 异步 CRUD 操作
- Redis/内存缓存集成
- 批量操作优化
- 统计数据缓存
"""
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import func, extract, select, delete
from models.bill import Bill, BillHistory
from schemas.bill import BillCreate, BillUpdate, BillStatistics, CategoryStatistics, NameStatistics
from datetime import datetime, timedelta
from typing import List, Optional
from utils.exceptions import NotFoundException, AppException
from utils.constants import BillType, OperationType, Pagination
from utils.cache import (
    cache_get, cache_set, CacheKeys, invalidate_user_cache
)
from utils.timezone_utils import ensure_utc
import json
import re
import logging

logger = logging.getLogger(__name__)


async def create_bill_async(db: AsyncSession, bill: BillCreate, user_id: int) -> Bill:
    """异步创建新账单"""
    from models.project import Project
    
    bill_data = bill.dict()
    if 'date' in bill_data:
        bill_data['date'] = ensure_utc(bill_data['date'])
    
    # 验证项目ID是否属于当前用户（project_id是必填字段）
    project_id = bill_data.get('project_id')
    if not project_id:
        raise AppException(
            message="项目ID是必填字段",
            error_code="PROJECT_ID_REQUIRED"
        )
    
    project = await db.execute(
        select(Project).where(
            Project.id == project_id,
            Project.user_id == user_id
        )
    )
    if not project.scalar_one_or_none():
        raise NotFoundException("项目", project_id)
    
    db_bill = Bill(**bill_data, user_id=user_id)
    db.add(db_bill)
    await db.commit()
    await db.refresh(db_bill)
    
    # 清除用户统计缓存
    await invalidate_user_cache(user_id)
    
    return db_bill


async def create_bills_batch_async(
    db: AsyncSession, 
    bills: List[BillCreate], 
    user_id: int
) -> List[Bill]:
    """
    批量创建账单（优化性能）
    
    一次性插入多条账单，比逐条插入效率高很多
    """
    from models.project import Project
    
    if not bills:
        return []
    
    if len(bills) > 1000:
        raise AppException(
            message="批量插入最多支持 1000 条记录",
            error_code="BATCH_SIZE_EXCEEDED"
        )
    
    # 收集所有项目ID并验证是否为空
    project_ids = set()
    for bill in bills:
        if not bill.project_id:
            raise AppException(
                message="项目ID是必填字段",
                error_code="PROJECT_ID_REQUIRED"
            )
        project_ids.add(bill.project_id)
    
    # 批量查询用户的项目
    result = await db.execute(
        select(Project.id).where(
            Project.id.in_(project_ids),
            Project.user_id == user_id
        )
    )
    valid_project_ids = {row[0] for row in result.fetchall()}
    
    # 检查是否有无效的项目ID
    invalid_ids = project_ids - valid_project_ids
    if invalid_ids:
        raise NotFoundException("项目", list(invalid_ids)[0])
    
    db_bills = []
    for bill in bills:
        bill_data = bill.dict()
        if 'date' in bill_data:
            bill_data['date'] = ensure_utc(bill_data['date'])
        db_bills.append(Bill(**bill_data, user_id=user_id))
    
    # 批量添加
    db.add_all(db_bills)
    await db.commit()
    
    # 刷新获取 ID
    for bill in db_bills:
        await db.refresh(bill)
    
    # 清除用户统计缓存
    await invalidate_user_cache(user_id)
    
    logger.info(f"批量创建 {len(db_bills)} 条账单，用户: {user_id}")
    return db_bills


async def get_bills_by_user_async(
    db: AsyncSession, 
    user_id: int, 
    skip: int = 0, 
    limit: int = 100,
    month: Optional[str] = None,
    bill_type: Optional[str] = None,
    worker: Optional[str] = None,
    category: Optional[str] = None,
    project_id: Optional[int] = None
) -> List[Bill]:
    """异步获取用户账单列表，支持多条件筛选（包括项目筛选）"""
    # 输入验证
    if skip < 0 or limit < Pagination.MIN_LIMIT or limit > Pagination.MAX_LIMIT:
        raise AppException(
            message="无效的分页参数",
            error_code="INVALID_PAGINATION"
        )
    
    if month and not re.match(r'^\d{4}-\d{2}$', month):
        raise AppException(
            message="月份格式必须为 YYYY-MM",
            error_code="INVALID_MONTH_FORMAT"
        )
    
    if bill_type and bill_type not in BillType.values():
        raise AppException(
            message=f"账单类型只能是 {' 或 '.join(BillType.values())}",
            error_code="INVALID_BILL_TYPE"
        )
    
    # 构建查询
    query = select(Bill).where(Bill.user_id == user_id)
    
    if month:
        year, month_num = map(int, month.split('-'))
        query = query.where(
            extract('year', Bill.date) == year,
            extract('month', Bill.date) == month_num
        )
    
    if bill_type:
        query = query.where(Bill.bill_type == bill_type)
    
    if worker:
        worker_safe = worker.strip()
        query = query.where(Bill.name.ilike(f"%{worker_safe}%"))
    
    if category:
        category_safe = category.strip()
        query = query.where(Bill.category.ilike(f"%{category_safe}%"))
    
    if project_id:
        query = query.where(Bill.project_id == project_id)
    
    query = query.order_by(Bill.date.desc()).offset(skip).limit(limit)
    
    result = await db.execute(query)
    return result.scalars().all()


async def get_bill_by_id_async(db: AsyncSession, bill_id: int, user_id: int) -> Bill:
    """异步根据ID获取单个账单"""
    query = select(Bill).where(Bill.id == bill_id, Bill.user_id == user_id)
    result = await db.execute(query)
    bill = result.scalar_one_or_none()
    
    if not bill:
        raise NotFoundException("账单", bill_id)
    return bill


async def update_bill_async(
    db: AsyncSession, 
    bill_id: int, 
    bill: BillUpdate, 
    user_id: int
) -> Bill:
    """异步更新账单（并在更新前自动存档旧版本）"""
    from models.project import Project
    
    db_bill = await get_bill_by_id_async(db, bill_id, user_id)
    
    # 验证项目ID（如果提供）是否属于当前用户
    update_data = bill.dict(exclude_unset=True)
    if 'project_id' in update_data and update_data['project_id'] is not None:
        project = await db.execute(
            select(Project).where(
                Project.id == update_data['project_id'],
                Project.user_id == user_id
            )
        )
        if not project.scalar_one_or_none():
            raise NotFoundException("项目", update_data['project_id'])
    
    # 1. 创建历史快照
    history = BillHistory(
        bill_id=db_bill.id,
        operation_type=OperationType.UPDATE.value,
        amount=db_bill.amount,
        bill_type=db_bill.bill_type,
        category=db_bill.category,
        date=db_bill.date,
        note=db_bill.note,
        name=db_bill.name,
        duration_hours=db_bill.duration_hours,
        hourly_rate=db_bill.hourly_rate,
        pay_method=db_bill.pay_method,
        user_id=db_bill.user_id,
        project_id=db_bill.project_id
    )
    db.add(history)
    
    # 2. 执行更新
    for field, value in update_data.items():
        if field == 'date' and value is not None:
            value = ensure_utc(value)
        setattr(db_bill, field, value)
    
    await db.commit()
    await db.refresh(db_bill)
    
    # 清除用户统计缓存
    await invalidate_user_cache(user_id)
    
    return db_bill


async def delete_bill_async(db: AsyncSession, bill_id: int, user_id: int) -> dict:
    """异步删除账单（并在删除前自动存档）"""
    db_bill = await get_bill_by_id_async(db, bill_id, user_id)
    
    # 1. 创建历史快照
    history = BillHistory(
        bill_id=db_bill.id,
        operation_type=OperationType.DELETE.value,
        amount=db_bill.amount,
        bill_type=db_bill.bill_type,
        category=db_bill.category,
        date=db_bill.date,
        note=db_bill.note,
        name=db_bill.name,
        duration_hours=db_bill.duration_hours,
        hourly_rate=db_bill.hourly_rate,
        pay_method=db_bill.pay_method,
        user_id=db_bill.user_id,
        project_id=db_bill.project_id
    )
    db.add(history)
    
    # 2. 执行删除
    await db.delete(db_bill)
    await db.commit()
    
    # 清除用户统计缓存
    await invalidate_user_cache(user_id)
    
    return {"message": "账单删除成功"}


async def delete_bills_batch_async(
    db: AsyncSession, 
    bill_ids: List[int], 
    user_id: int
) -> dict:
    """
    批量删除账单
    
    先创建历史记录，再批量删除
    """
    if not bill_ids:
        return {"message": "无账单需要删除", "deleted_count": 0}
    
    if len(bill_ids) > 100:
        raise AppException(
            message="批量删除最多支持 100 条记录",
            error_code="BATCH_SIZE_EXCEEDED"
        )
    
    # 查询要删除的账单
    query = select(Bill).where(Bill.id.in_(bill_ids), Bill.user_id == user_id)
    result = await db.execute(query)
    bills = result.scalars().all()
    
    if not bills:
        raise NotFoundException("账单", bill_ids)
    
    # 创建历史快照
    for bill in bills:
        history = BillHistory(
            bill_id=bill.id,
            operation_type=OperationType.DELETE.value,
            amount=bill.amount,
            bill_type=bill.bill_type,
            category=bill.category,
            date=bill.date,
            note=bill.note,
            name=bill.name,
            duration_hours=bill.duration_hours,
            hourly_rate=bill.hourly_rate,
            pay_method=bill.pay_method,
            user_id=bill.user_id,
            project_id=bill.project_id
        )
        db.add(history)
    
    # 批量删除
    delete_query = delete(Bill).where(
        Bill.id.in_([b.id for b in bills]),
        Bill.user_id == user_id
    )
    await db.execute(delete_query)
    await db.commit()
    
    # 清除用户统计缓存
    await invalidate_user_cache(user_id)
    
    logger.info(f"批量删除 {len(bills)} 条账单，用户: {user_id}")
    return {"message": "账单批量删除成功", "deleted_count": len(bills)}


async def get_monthly_statistics_async(
    db: AsyncSession, 
    user_id: int, 
    month: Optional[str] = None,
    date: Optional[str] = None,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    start_month: Optional[str] = None,
    end_month: Optional[str] = None,
    project_id: Optional[int] = None
) -> BillStatistics:
    """
    异步获取收支统计（带缓存）
    支持：单日、单月、日期范围、月份范围查询
    
    缓存时间：5 分钟
    """
    # 确定查询范围标识
    if start_date and end_date:
        period_key = f"{start_date}~{end_date}"
    elif start_month and end_month:
        period_key = f"{start_month}~{end_month}"
    elif date:
        period_key = date
    elif month:
        period_key = month
    else:
        period_key = "all"
    
    # 检查缓存
    base_key = CacheKeys.bill_stats_key(user_id, period_key)
    cache_key = f"{base_key}:{project_id}" if project_id else base_key
    
    cached = await cache_get(cache_key)
    if cached:
        try:
            data = json.loads(cached)
            return BillStatistics(**data)
        except (json.JSONDecodeError, TypeError):
            pass
    
    # 基础查询条件
    base_filters = [Bill.user_id == user_id]
    
    if start_date and end_date:
        # 日期范围查询
        start = datetime.strptime(start_date, '%Y-%m-%d').date()
        end = datetime.strptime(end_date, '%Y-%m-%d').date()
        base_filters.append(func.date(Bill.date) >= start)
        base_filters.append(func.date(Bill.date) <= end)
    elif start_month and end_month:
        # 月份范围查询
        start_year, start_mon = map(int, start_month.split('-'))
        end_year, end_mon = map(int, end_month.split('-'))
        start = datetime(start_year, start_mon, 1).date()
        # 计算结束月份的最后一天
        if end_mon == 12:
            end = datetime(end_year + 1, 1, 1).date() - timedelta(days=1)
        else:
            end = datetime(end_year, end_mon + 1, 1).date() - timedelta(days=1)
        base_filters.append(func.date(Bill.date) >= start)
        base_filters.append(func.date(Bill.date) <= end)
    elif date:
        # 单日查询
        query_date = datetime.strptime(date, '%Y-%m-%d').date()
        base_filters.append(func.date(Bill.date) == query_date)
    elif month:
        # 单月查询
        year, month_num = map(int, month.split('-'))
        base_filters.append(extract('year', Bill.date) == year)
        base_filters.append(extract('month', Bill.date) == month_num)
    
    if project_id:
        base_filters.append(Bill.project_id == project_id)
    
    # 收入统计
    income_query = select(func.coalesce(func.sum(Bill.amount), 0)).where(
        *base_filters,
        Bill.bill_type == BillType.INCOME.value
    )
    income_result = await db.execute(income_query)
    income = income_result.scalar()
    
    # 支出统计
    expense_query = select(func.coalesce(func.sum(Bill.amount), 0)).where(
        *base_filters,
        Bill.bill_type == BillType.EXPENSE.value
    )
    expense_result = await db.execute(expense_query)
    expense = expense_result.scalar()
    
    stats = BillStatistics(
        month=period_key,
        total_income=float(income),
        total_expense=float(expense),
        net_amount=float(income - expense)
    )
    
    # 写入缓存（5分钟）
    await cache_set(cache_key, json.dumps(stats.dict()), ttl=300)
    
    return stats


async def get_category_statistics_async(
    db: AsyncSession, 
    user_id: int, 
    month: Optional[str] = None,
    project_id: Optional[int] = None
) -> List[CategoryStatistics]:
    """
    异步获取分类统计（带缓存）
    
    缓存时间：5 分钟
    """
    # 检查缓存
    base_key = CacheKeys.category_stats_key(user_id, month)
    cache_key = f"{base_key}:{project_id}" if project_id else base_key
    
    cached = await cache_get(cache_key)
    if cached:
        try:
            data = json.loads(cached)
            return [CategoryStatistics(**item) for item in data]
        except (json.JSONDecodeError, TypeError):
            pass
    
    query = select(
        Bill.category,
        func.sum(Bill.amount).label('total_amount')
    ).where(Bill.user_id == user_id)
    
    if month:
        year, month_num = map(int, month.split('-'))
        query = query.where(
            extract('year', Bill.date) == year,
            extract('month', Bill.date) == month_num
        )
    
    if project_id:
        query = query.where(Bill.project_id == project_id)
    
    query = query.group_by(Bill.category)
    result = await db.execute(query)
    results = result.all()
    
    total_amount = sum(float(r.total_amount) for r in results)
    
    category_stats = []
    for r in results:
        percentage = (float(r.total_amount) / total_amount * 100) if total_amount > 0 else 0
        category_stats.append(CategoryStatistics(
            category=r.category,
            amount=float(r.total_amount),
            percentage=round(percentage, 2)
        ))
    
    sorted_stats = sorted(category_stats, key=lambda x: x.amount, reverse=True)
    
    # 写入缓存（5分钟）
    await cache_set(
        cache_key, 
        json.dumps([s.dict() for s in sorted_stats]),
        ttl=300
    )
    
    return sorted_stats


async def get_name_statistics_async(
    db: AsyncSession, 
    user_id: int, 
    month: Optional[str] = None,
    date: Optional[str] = None,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    start_month: Optional[str] = None,
    end_month: Optional[str] = None,
    project_id: Optional[int] = None
) -> List[NameStatistics]:
    """
    异步获取名称统计（带缓存）
    支持：单日、单月、日期范围、月份范围查询
    
    缓存时间：5 分钟
    """
    # 确定查询范围标识
    if start_date and end_date:
        period_key = f"{start_date}~{end_date}"
    elif start_month and end_month:
        period_key = f"{start_month}~{end_month}"
    elif date:
        period_key = date
    elif month:
        period_key = month
    else:
        period_key = "all"
    
    # 检查缓存
    base_key = CacheKeys.name_stats_key(user_id, period_key)
    cache_key = f"{base_key}:{project_id}" if project_id else base_key
    
    cached = await cache_get(cache_key)
    if cached:
        try:
            data = json.loads(cached)
            return [NameStatistics(**item) for item in data]
        except (json.JSONDecodeError, TypeError):
            pass
    
    query = select(
        Bill.name,
        func.sum(Bill.duration_hours).label('total_hours'),
        func.sum(Bill.amount).label('total_amount'),
        func.count(Bill.id).label('bill_count')
    ).where(
        Bill.user_id == user_id,
        Bill.name.isnot(None),
        Bill.name != ''
    )
    
    if start_date and end_date:
        # 日期范围查询
        start = datetime.strptime(start_date, '%Y-%m-%d').date()
        end = datetime.strptime(end_date, '%Y-%m-%d').date()
        query = query.where(func.date(Bill.date) >= start)
        query = query.where(func.date(Bill.date) <= end)
    elif start_month and end_month:
        # 月份范围查询
        start_year, start_mon = map(int, start_month.split('-'))
        end_year, end_mon = map(int, end_month.split('-'))
        start = datetime(start_year, start_mon, 1).date()
        if end_mon == 12:
            end = datetime(end_year + 1, 1, 1).date() - timedelta(days=1)
        else:
            end = datetime(end_year, end_mon + 1, 1).date() - timedelta(days=1)
        query = query.where(func.date(Bill.date) >= start)
        query = query.where(func.date(Bill.date) <= end)
    elif date:
        # 单日查询
        query_date = datetime.strptime(date, '%Y-%m-%d').date()
        query = query.where(func.date(Bill.date) == query_date)
    elif month:
        # 单月查询
        year, month_num = map(int, month.split('-'))
        query = query.where(
            extract('year', Bill.date) == year,
            extract('month', Bill.date) == month_num
        )
    
    if project_id:
        query = query.where(Bill.project_id == project_id)
    
    query = query.group_by(Bill.name)
    result = await db.execute(query)
    results = result.all()
    
    name_stats = []
    for r in results:
        name_stats.append(NameStatistics(
            name=r.name,
            total_hours=float(r.total_hours or 0),
            total_amount=float(r.total_amount or 0),
            bill_count=r.bill_count
        ))
    
    sorted_stats = sorted(name_stats, key=lambda x: x.total_amount, reverse=True)
    
    # 写入缓存（5分钟）
    await cache_set(
        cache_key,
        json.dumps([s.dict() for s in sorted_stats]),
        ttl=300
    )
    
    return sorted_stats


async def get_bill_history_async(
    db: AsyncSession, 
    bill_id: int, 
    user_id: int
) -> List[BillHistory]:
    """异步获取指定账单的修改历史"""
    query = select(BillHistory).where(
        BillHistory.bill_id == bill_id,
        BillHistory.user_id == user_id
    ).order_by(BillHistory.operated_at.desc())
    
    result = await db.execute(query)
    return result.scalars().all()


async def export_bills_to_csv_async(
    db: AsyncSession, 
    user_id: int, 
    month: Optional[str] = None
) -> str:
    """异步导出账单为 CSV 格式字符串"""
    import csv
    import io
    
    bills = await get_bills_by_user_async(
        db, user_id, skip=0, limit=10000, month=month
    )
    
    output = io.StringIO()
    writer = csv.writer(output)
    
    # 写入表头
    writer.writerow(['日期时间', '名称', '类型', '分类', '金额', '时长(小时)', '时薪(元/小时)', '支付方式', '备注'])
    
    # 写入数据
    for bill in bills:
        writer.writerow([
            bill.date.strftime('%Y-%m-%d %H:%M:%S') if bill.date else '',
            bill.name or '',
            '收入' if bill.bill_type == BillType.INCOME.value else '支出',
            bill.category or '',
            bill.amount,
            bill.duration_hours or '',
            bill.hourly_rate or '',
            bill.pay_method or '',
            bill.note or ''
        ])
    
    return output.getvalue()


async def restore_bill_version_async(
    db: AsyncSession, 
    history_id: int, 
    user_id: int
) -> Bill:
    """异步回滚到指定历史版本"""
    # 查询历史记录
    history_query = select(BillHistory).where(
        BillHistory.id == history_id,
        BillHistory.user_id == user_id
    )
    result = await db.execute(history_query)
    history = result.scalar_one_or_none()
    
    if not history:
        raise NotFoundException("历史记录", history_id)
    
    # 查询原账单是否还存在
    bill_query = select(Bill).where(Bill.id == history.bill_id)
    result = await db.execute(bill_query)
    bill = result.scalar_one_or_none()
    
    if not bill:
        # 账单已删除，尝试恢复
        if not history.project_id:
            # 旧历史记录没有 project_id，无法恢复
            raise AppException(
                message="账单已被删除，且历史记录缺少项目信息，无法自动恢复。请手动创建新账单。",
                error_code="BILL_DELETED_CANNOT_RESTORE"
            )
        
        # 有 project_id，可以恢复
        note_text = history.note or ""
        new_bill = Bill(
            user_id=user_id,
            project_id=history.project_id,
            name=history.name or "恢复的账单",
            amount=history.amount,
            bill_type=history.bill_type,
            category=history.category,
            date=history.date,
            note=f"{note_text} (已从 {history.operated_at.strftime('%Y-%m-%d')} 版本恢复)",
            duration_hours=history.duration_hours,
            hourly_rate=history.hourly_rate,
            pay_method=history.pay_method
        )
        db.add(new_bill)
        await db.commit()
        await db.refresh(new_bill)
        
        # 清除缓存
        await invalidate_user_cache(user_id)
        
        return new_bill
    
    # 账单还存在，直接覆盖更新
    update_data = BillUpdate(
        name=history.name,
        amount=history.amount,
        bill_type=history.bill_type,
        category=history.category,
        date=history.date,
        note=history.note,
        duration_hours=history.duration_hours,
        hourly_rate=history.hourly_rate,
        pay_method=history.pay_method
    )
    return await update_bill_async(db, bill.id, update_data, user_id)
