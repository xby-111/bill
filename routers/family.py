"""
家庭组路由

提供家庭组相关的 API 接口：
- 创建/加入/退出家庭组
- 查看家庭成员
- 查看家庭账单
- 家庭统计
"""
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from typing import List, Optional
from db.database import get_db
from schemas.family import (
    FamilyCreate, FamilyJoin, FamilyResponse, FamilyDetailResponse,
    FamilyMemberResponse, FamilyBillResponse, FamilyStatisticsResponse
)
from services.family_service import (
    create_family, get_user_family, join_family, leave_family,
    dissolve_family, get_family_members, get_family_bills,
    get_family_statistics, refresh_invite_code
)
from routers.auth import get_current_user
from schemas.user import UserResponse

router = APIRouter(prefix="/family", tags=["家庭组"])


@router.post("/", response_model=FamilyResponse, summary="创建家庭组")
def create_family_endpoint(
    family: FamilyCreate,
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    创建新的家庭组
    
    - 创建者自动成为家庭成员
    - 生成6位邀请码供其他成员加入
    - 每个用户只能属于一个家庭组
    """
    result = create_family(db=db, family=family, user_id=current_user.id)
    return FamilyResponse(
        id=result.id,
        name=result.name,
        invite_code=result.invite_code,
        created_by=result.created_by,
        created_at=result.created_at,
        member_count=1
    )


@router.get("/", response_model=Optional[FamilyDetailResponse], summary="获取我的家庭")
def get_my_family(
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    获取当前用户所在的家庭组信息
    
    如果用户未加入任何家庭，返回 null
    """
    family = get_user_family(db=db, user_id=current_user.id)
    if not family:
        return None
    
    members = get_family_members(db=db, user_id=current_user.id)
    return FamilyDetailResponse(
        id=family.id,
        name=family.name,
        invite_code=family.invite_code,
        created_by=family.created_by,
        created_at=family.created_at,
        members=members
    )


@router.post("/join", response_model=FamilyResponse, summary="加入家庭组")
def join_family_endpoint(
    data: FamilyJoin,
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    通过邀请码加入家庭组
    
    - 邀请码不区分大小写
    - 用户只能加入一个家庭组
    """
    family = join_family(db=db, invite_code=data.invite_code, user_id=current_user.id)
    member_count = len(get_family_members(db=db, user_id=current_user.id))
    return FamilyResponse(
        id=family.id,
        name=family.name,
        invite_code=family.invite_code,
        created_by=family.created_by,
        created_at=family.created_at,
        member_count=member_count
    )


@router.post("/leave", summary="退出家庭组")
def leave_family_endpoint(
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    退出当前家庭组
    
    - 普通成员可以直接退出
    - 创建者如果是最后一人，会同时解散家庭
    - 创建者如果还有其他成员，需要先转让或解散
    """
    return leave_family(db=db, user_id=current_user.id)


@router.post("/dissolve", summary="解散家庭组")
def dissolve_family_endpoint(
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    解散家庭组（仅创建者可操作）
    
    所有成员将被移出家庭，家庭组被删除
    """
    return dissolve_family(db=db, user_id=current_user.id)


@router.get("/members", response_model=List[FamilyMemberResponse], summary="获取家庭成员")
def get_members(
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    获取家庭组的所有成员列表
    """
    return get_family_members(db=db, user_id=current_user.id)


@router.get("/bills", response_model=List[FamilyBillResponse], summary="获取家庭账单")
def get_bills(
    skip: int = Query(0, ge=0, description="跳过记录数"),
    limit: int = Query(100, ge=1, le=500, description="返回记录数"),
    month: Optional[str] = Query(None, description="月份筛选 (YYYY-MM)"),
    member_id: Optional[int] = Query(None, description="指定成员ID筛选"),
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    获取家庭组所有成员的账单
    
    - 可按月份筛选
    - 可按成员筛选
    - 每条账单显示所属成员的用户名
    """
    return get_family_bills(
        db=db, 
        user_id=current_user.id, 
        skip=skip, 
        limit=limit,
        month=month,
        member_id=member_id
    )


@router.get("/statistics", response_model=FamilyStatisticsResponse, summary="家庭统计")
def get_statistics(
    month: Optional[str] = Query(None, description="月份筛选 (YYYY-MM)"),
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    获取家庭组的统计数据
    
    - 总收入/支出/结余
    - 每个成员的统计明细
    """
    return get_family_statistics(db=db, user_id=current_user.id, month=month)


@router.post("/refresh-code", summary="刷新邀请码")
def refresh_code(
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """
    刷新家庭组邀请码（仅创建者可操作）
    
    旧邀请码将失效
    """
    new_code = refresh_invite_code(db=db, user_id=current_user.id)
    return {"invite_code": new_code}
