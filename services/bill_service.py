from sqlalchemy.orm import Session
from sqlalchemy import func, extract
from fastapi import HTTPException, status
from models.bill import Bill
from schemas.bill import BillCreate, BillUpdate, BillStatistics, CategoryStatistics, WorkerStatistics
from datetime import datetime
from typing import List, Optional
import csv
import io

def create_bill(db: Session, bill: BillCreate, user_id: int):
    """创建新账单"""
    db_bill = Bill(**bill.dict(), user_id=user_id)
    db.add(db_bill)
    db.commit()
    db.refresh(db_bill)
    return db_bill

def get_bills_by_user(
    db: Session, 
    user_id: int, 
    skip: int = 0, 
    limit: int = 100,
    month: Optional[str] = None,
    bill_type: Optional[str] = None,
    worker: Optional[str] = None,
    category: Optional[str] = None
):
    """获取用户账单列表，支持多条件筛选"""
    query = db.query(Bill).filter(Bill.user_id == user_id)
    
    if month:
        year, month_num = map(int, month.split('-'))
        query = query.filter(
            extract('year', Bill.date) == year,
            extract('month', Bill.date) == month_num
        )
    
    if bill_type:
        query = query.filter(Bill.bill_type == bill_type)
    
    if worker:
        query = query.filter(Bill.worker.ilike(f"%{worker}%"))
    
    if category:
        query = query.filter(Bill.category.ilike(f"%{category}%"))
    
    return query.order_by(Bill.date.desc()).offset(skip).limit(limit).all()

def get_bill_by_id(db: Session, bill_id: int, user_id: int):
    """根据ID获取单个账单"""
    bill = db.query(Bill).filter(Bill.id == bill_id, Bill.user_id == user_id).first()
    if not bill:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="账单不存在"
        )
    return bill

def update_bill(db: Session, bill_id: int, bill: BillUpdate, user_id: int):
    """更新账单"""
    db_bill = get_bill_by_id(db, bill_id, user_id)
    
    update_data = bill.dict(exclude_unset=True)
    for field, value in update_data.items():
        setattr(db_bill, field, value)
    
    db.commit()
    db.refresh(db_bill)
    return db_bill

def delete_bill(db: Session, bill_id: int, user_id: int):
    """删除账单"""
    db_bill = get_bill_by_id(db, bill_id, user_id)
    db.delete(db_bill)
    db.commit()
    return {"message": "账单删除成功"}

def get_monthly_statistics(db: Session, user_id: int, month: str):
    """获取月度收支统计"""
    year, month_num = map(int, month.split('-'))
    
    income_result = db.query(
        func.coalesce(func.sum(Bill.amount), 0)
    ).filter(
        Bill.user_id == user_id,
        Bill.bill_type == 'income',
        extract('year', Bill.date) == year,
        extract('month', Bill.date) == month_num
    ).scalar()
    
    expense_result = db.query(
        func.coalesce(func.sum(Bill.amount), 0)
    ).filter(
        Bill.user_id == user_id,
        Bill.bill_type == 'expense',
        extract('year', Bill.date) == year,
        extract('month', Bill.date) == month_num
    ).scalar()
    
    return BillStatistics(
        month=month,
        total_income=float(income_result),
        total_expense=float(expense_result),
        net_amount=float(income_result - expense_result)
    )

def get_category_statistics(db: Session, user_id: int, month: Optional[str] = None):
    """获取分类统计"""
    query = db.query(
        Bill.category,
        func.sum(Bill.amount).label('total_amount')
    ).filter(Bill.user_id == user_id)
    
    if month:
        year, month_num = map(int, month.split('-'))
        query = query.filter(
            extract('year', Bill.date) == year,
            extract('month', Bill.date) == month_num
        )
    
    results = query.group_by(Bill.category).all()
    
    total_amount = sum(float(result.total_amount) for result in results)
    
    category_stats = []
    for result in results:
        percentage = (float(result.total_amount) / total_amount * 100) if total_amount > 0 else 0
        category_stats.append(CategoryStatistics(
            category=result.category,
            amount=float(result.total_amount),
            percentage=round(percentage, 2)
        ))
    
    return sorted(category_stats, key=lambda x: x.amount, reverse=True)

def get_worker_statistics(db: Session, user_id: int, month: Optional[str] = None) -> List[WorkerStatistics]:
    """获取工人/服务者统计（按人汇总工时和金额）"""
    query = db.query(
        Bill.worker,
        func.sum(Bill.duration_hours).label('total_hours'),
        func.sum(Bill.amount).label('total_amount'),
        func.count(Bill.id).label('bill_count')
    ).filter(
        Bill.user_id == user_id,
        Bill.worker.isnot(None),
        Bill.worker != ''
    )
    
    if month:
        year, month_num = map(int, month.split('-'))
        query = query.filter(
            extract('year', Bill.date) == year,
            extract('month', Bill.date) == month_num
        )
    
    results = query.group_by(Bill.worker).all()
    
    worker_stats = []
    for result in results:
        worker_stats.append(WorkerStatistics(
            worker=result.worker,
            total_hours=float(result.total_hours or 0),
            total_amount=float(result.total_amount or 0),
            bill_count=result.bill_count
        ))
    
    return sorted(worker_stats, key=lambda x: x.total_amount, reverse=True)

def export_bills_to_csv(db: Session, user_id: int, month: Optional[str] = None) -> str:
    """导出账单为 CSV 格式字符串"""
    bills = get_bills_by_user(db, user_id, skip=0, limit=10000, month=month)
    
    output = io.StringIO()
    writer = csv.writer(output)
    
    # 写入表头
    writer.writerow(['日期时间', '类型', '分类', '金额', '工人', '时长(小时)', '时薪(元/小时)', '支付方式', '备注'])
    
    # 写入数据
    for bill in bills:
        writer.writerow([
            bill.date.strftime('%Y-%m-%d %H:%M:%S') if bill.date else '',
            '收入' if bill.bill_type == 'income' else '支出',
            bill.category or '',
            bill.amount,
            bill.worker or '',
            bill.duration_hours or '',
            bill.hourly_rate or '',
            bill.pay_method or '',
            bill.note or ''
        ])
    
    return output.getvalue()