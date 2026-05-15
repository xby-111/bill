"""
项目路由模块

处理项目相关的HTTP请求
"""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List
from db.database import get_db
from schemas.project import ProjectCreate, ProjectResponse, ProjectUpdate, ProjectWithBills
from services.project_service import (
    create_project as create_project_service,
    get_projects as get_projects_service,
    get_project_with_bills,
    update_project as update_project_service,
    delete_project as delete_project_service
)
from routers.auth import get_current_user
from schemas.user import UserResponse

router = APIRouter(prefix="/projects", tags=["项目"])


@router.post("/", response_model=ProjectResponse, summary="创建项目")
def create_project(
    project: ProjectCreate,
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """创建新项目用于分组管理账单"""
    return create_project_service(db=db, project=project, user_id=current_user.id)


@router.get("/", response_model=List[ProjectResponse], summary="获取项目列表")
def get_projects(
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """获取当前用户的所有项目"""
    return get_projects_service(db=db, user_id=current_user.id)


@router.get("/{project_id}", response_model=ProjectWithBills, summary="获取项目详情")
def get_project(
    project_id: int,
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """获取项目详情，包含该项目下的所有账单"""
    return get_project_with_bills(db=db, project_id=project_id, user_id=current_user.id)


@router.put("/{project_id}", response_model=ProjectResponse, summary="更新项目")
def update_project(
    project_id: int,
    project: ProjectUpdate,
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """更新项目信息（重命名等）"""
    return update_project_service(
        db=db, 
        project_id=project_id, 
        project=project, 
        user_id=current_user.id
    )


@router.delete("/{project_id}", summary="删除项目")
def delete_project(
    project_id: int,
    db: Session = Depends(get_db),
    current_user: UserResponse = Depends(get_current_user)
):
    """删除项目（项目下的账单会被一并删除）"""
    return delete_project_service(db=db, project_id=project_id, user_id=current_user.id)
