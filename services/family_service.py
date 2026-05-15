"""
家庭组服务层

处理家庭组相关的业务逻辑：
- 创建家庭组
- 加入/退出家庭组
- 获取家庭成员及账单
- 家庭统计
"""
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime
from models.family import Family, generate_invite_code
from models.user import User
from models.bill import Bill
from schemas.family import FamilyCreate, FamilyMemberResponse, FamilyBillResponse
from utils.exceptions import NotFoundException, ConflictException, AppException


def create_family(db: Session, family: FamilyCreate, user_id: int) -> Family:
    """
    创建家庭组
    
    Args:
        db: 数据库会话
        family: 创建数据
        user_id: 创建者用户ID
        
    Returns:
        创建的家庭组对象
        
    Raises:
        ConflictException: 用户已在其他家庭组中
    """
    # 检查用户是否已在家庭组中
    user = db.query(User).filter(User.id == user_id).first()
    if user.family_id:
        raise ConflictException("您已在家庭组中，请先退出当前家庭")
    
    # 生成唯一邀请码
    invite_code = generate_invite_code()
    while db.query(Family).filter(Family.invite_code == invite_code).first():
        invite_code = generate_invite_code()
    
    # 创建家庭组
    db_family = Family(
        name=family.name,
        invite_code=invite_code,
        created_by=user_id
    )
    db.add(db_family)
    db.flush()  # 获取 family id
    
    # 创建者自动加入家庭
    user.family_id = db_family.id
    user.family_joined_at = datetime.utcnow()
    
    db.commit()
    db.refresh(db_family)
    
    return db_family


def get_user_family(db: Session, user_id: int) -> Optional[Family]:
    """
    获取用户所在的家庭组
    
    Returns:
        家庭组对象，未加入则返回 None
    """
    user = db.query(User).filter(User.id == user_id).first()
    if not user or not user.family_id:
        return None
    
    return db.query(Family).filter(Family.id == user.family_id).first()


def join_family(db: Session, invite_code: str, user_id: int) -> Family:
    """
    通过邀请码加入家庭组
    
    Args:
        db: 数据库会话
        invite_code: 邀请码
        user_id: 用户ID
        
    Returns:
        加入的家庭组对象
        
    Raises:
        NotFoundException: 邀请码无效
        ConflictException: 用户已在家庭组中
    """
    # 检查用户是否已在家庭组中
    user = db.query(User).filter(User.id == user_id).first()
    if user.family_id:
        raise ConflictException("您已在家庭组中，请先退出当前家庭")
    
    # 查找家庭组
    family = db.query(Family).filter(
        Family.invite_code == invite_code.upper()
    ).first()
    
    if not family:
        raise NotFoundException("家庭组", f"邀请码 {invite_code}")
    
    # 加入家庭
    user.family_id = family.id
    user.family_joined_at = datetime.utcnow()
    
    db.commit()
    db.refresh(family)
    
    return family


def leave_family(db: Session, user_id: int) -> dict:
    """
    退出家庭组
    
    如果是创建者且还有其他成员，需要转让或解散
    
    Returns:
        操作结果消息
        
    Raises:
        AppException: 创建者不能直接退出
    """
    user = db.query(User).filter(User.id == user_id).first()
    
    if not user.family_id:
        raise AppException(message="您当前不在任何家庭组中", error_code="NOT_IN_FAMILY")
    
    family = db.query(Family).filter(Family.id == user.family_id).first()
    
    # 检查是否是创建者
    if family.created_by == user_id:
        # 检查是否还有其他成员
        member_count = db.query(User).filter(User.family_id == family.id).count()
        if member_count > 1:
            raise AppException(
                message="您是家庭创建者，请先转让给其他成员或解散家庭",
                error_code="CREATOR_CANNOT_LEAVE"
            )
        # 只有创建者一人，直接解散
        db.delete(family)
    
    # 退出家庭
    user.family_id = None
    user.family_joined_at = None
    
    db.commit()
    
    return {"message": "已退出家庭组"}


def dissolve_family(db: Session, user_id: int) -> dict:
    """
    解散家庭组（仅创建者可操作）
    
    所有成员将被移出家庭
    """
    user = db.query(User).filter(User.id == user_id).first()
    
    if not user.family_id:
        raise AppException(message="您当前不在任何家庭组中", error_code="NOT_IN_FAMILY")
    
    family = db.query(Family).filter(Family.id == user.family_id).first()
    
    if family.created_by != user_id:
        raise AppException(message="只有创建者可以解散家庭", error_code="NOT_CREATOR")
    
    # 移除所有成员
    db.query(User).filter(User.family_id == family.id).update({
        User.family_id: None,
        User.family_joined_at: None
    })
    
    # 删除家庭
    db.delete(family)
    db.commit()
    
    return {"message": "家庭组已解散"}


def get_family_members(db: Session, user_id: int) -> List[FamilyMemberResponse]:
    """
    获取家庭成员列表
    """
    user = db.query(User).filter(User.id == user_id).first()
    
    if not user.family_id:
        return []
    
    family = db.query(Family).filter(Family.id == user.family_id).first()
    members = db.query(User).filter(User.family_id == user.family_id).all()
    
    return [
        FamilyMemberResponse(
            id=m.id,
            username=m.username,
            joined_at=m.family_joined_at,
            is_creator=(m.id == family.created_by)
        )
        for m in members
    ]


def get_family_bills(
    db: Session, 
    user_id: int, 
    skip: int = 0, 
    limit: int = 100,
    month: Optional[str] = None,
    member_id: Optional[int] = None
) -> List[FamilyBillResponse]:
    """
    获取家庭所有成员的账单
    
    Args:
        db: 数据库会话
        user_id: 当前用户ID
        skip: 分页偏移
        limit: 分页大小
        month: 月份筛选 (YYYY-MM)
        member_id: 指定成员ID筛选
        
    Returns:
        家庭账单列表
    """
    user = db.query(User).filter(User.id == user_id).first()
    
    if not user.family_id:
        raise AppException(message="您当前不在任何家庭组中", error_code="NOT_IN_FAMILY")
    
    # 获取家庭所有成员ID
    member_ids = db.query(User.id).filter(User.family_id == user.family_id).all()
    member_ids = [m[0] for m in member_ids]
    
    # 构建查询
    query = db.query(Bill, User.username).join(
        User, Bill.user_id == User.id
    ).filter(Bill.user_id.in_(member_ids))
    
    # 月份筛选
    if month:
        from sqlalchemy import extract
        year, month_num = map(int, month.split('-'))
        query = query.filter(
            extract('year', Bill.date) == year,
            extract('month', Bill.date) == month_num
        )
    
    # 成员筛选
    if member_id and member_id in member_ids:
        query = query.filter(Bill.user_id == member_id)
    
    # 排序和分页
    results = query.order_by(Bill.date.desc()).offset(skip).limit(limit).all()
    
    return [
        FamilyBillResponse(
            id=bill.id,
            name=bill.name,
            amount=bill.amount,
            bill_type=bill.bill_type,
            category=bill.category,
            date=bill.date,
            note=bill.note,
            project_id=bill.project_id,
            user_id=bill.user_id,
            username=username
        )
        for bill, username in results
    ]


def get_family_statistics(
    db: Session, 
    user_id: int, 
    month: Optional[str] = None
) -> dict:
    """
    获取家庭统计数据
    
    Returns:
        包含总收入、总支出、各成员统计的字典
    """
    user = db.query(User).filter(User.id == user_id).first()
    
    if not user.family_id:
        raise AppException(message="您当前不在任何家庭组中", error_code="NOT_IN_FAMILY")
    
    # 获取家庭所有成员
    members = db.query(User).filter(User.family_id == user.family_id).all()
    member_ids = [m.id for m in members]
    
    # 构建基础查询
    query = db.query(Bill).filter(Bill.user_id.in_(member_ids))
    
    # 月份筛选
    if month:
        from sqlalchemy import extract
        year, month_num = map(int, month.split('-'))
        query = query.filter(
            extract('year', Bill.date) == year,
            extract('month', Bill.date) == month_num
        )
    
    bills = query.all()
    
    # 计算总统计
    total_income = sum(b.amount for b in bills if b.bill_type == 'income')
    total_expense = sum(b.amount for b in bills if b.bill_type == 'expense')
    
    # 计算每个成员的统计
    member_stats = []
    for member in members:
        member_bills = [b for b in bills if b.user_id == member.id]
        income = sum(b.amount for b in member_bills if b.bill_type == 'income')
        expense = sum(b.amount for b in member_bills if b.bill_type == 'expense')
        member_stats.append({
            "user_id": member.id,
            "username": member.username,
            "income": income,
            "expense": expense,
            "balance": income - expense,
            "bill_count": len(member_bills)
        })
    
    return {
        "total_income": total_income,
        "total_expense": total_expense,
        "balance": total_income - total_expense,
        "member_stats": member_stats
    }


def refresh_invite_code(db: Session, user_id: int) -> str:
    """
    刷新邀请码（仅创建者可操作）
    
    Returns:
        新的邀请码
    """
    user = db.query(User).filter(User.id == user_id).first()
    
    if not user.family_id:
        raise AppException(message="您当前不在任何家庭组中", error_code="NOT_IN_FAMILY")
    
    family = db.query(Family).filter(Family.id == user.family_id).first()
    
    if family.created_by != user_id:
        raise AppException(message="只有创建者可以刷新邀请码", error_code="NOT_CREATOR")
    
    # 生成新邀请码
    new_code = generate_invite_code()
    while db.query(Family).filter(Family.invite_code == new_code).first():
        new_code = generate_invite_code()
    
    family.invite_code = new_code
    db.commit()
    
    return new_code
