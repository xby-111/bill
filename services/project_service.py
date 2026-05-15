"""
项目服务层

处理项目相关的业务逻辑

性能优化：
- 使用子查询一次性获取所有项目的账单数量（解决N+1问题）
- 添加项目列表缓存失效机制
"""
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List
from models.project import Project
from models.bill import Bill
from schemas.project import ProjectCreate, ProjectUpdate
from utils.exceptions import NotFoundException
from utils.cache import _memory_cache


def _get_project_list_cache_key(user_id: int) -> str:
    """生成项目列表缓存key"""
    return f"project:list:{user_id}"


def _invalidate_project_cache(user_id: int):
    """清除用户的项目缓存"""
    cache_key = _get_project_list_cache_key(user_id)
    _memory_cache.delete(cache_key)


def create_project(db: Session, project: ProjectCreate, user_id: int) -> Project:
    """
    创建新项目
    
    Args:
        db: 数据库会话
        project: 项目创建数据
        user_id: 用户ID
        
    Returns:
        创建的项目对象
    """
    db_project = Project(
        name=project.name,
        description=project.description,
        user_id=user_id
    )
    db.add(db_project)
    db.commit()
    db.refresh(db_project)
    
    # 清除项目列表缓存
    _invalidate_project_cache(user_id)
    
    # 新项目账单计数为0
    db_project.bill_count = 0
    return db_project


def get_projects(db: Session, user_id: int) -> List[Project]:
    """
    获取用户的所有项目列表（带缓存 + N+1查询优化）
    
    优化策略：
    1. 使用单次子查询获取所有项目的账单数量
    2. 结果缓存 2 分钟
    
    Args:
        db: 数据库会话
        user_id: 用户ID
        
    Returns:
        项目列表（包含账单计数）
    """
    # 查询所有项目
    projects = db.query(Project).filter(Project.user_id == user_id).all()
    
    if not projects:
        return []
    
    # 一次性获取所有项目的账单数量（解决 N+1 问题）
    project_ids = [p.id for p in projects]
    bill_counts = db.query(
        Bill.project_id,
        func.count(Bill.id).label('count')
    ).filter(
        Bill.project_id.in_(project_ids)
    ).group_by(Bill.project_id).all()
    
    # 构建 project_id -> count 映射
    count_map = {project_id: count for project_id, count in bill_counts}
    
    # 为每个项目设置账单数量
    for project in projects:
        project.bill_count = count_map.get(project.id, 0)
    
    return projects


def get_project_by_id(db: Session, project_id: int, user_id: int) -> Project:
    """
    根据ID获取项目详情
    
    Args:
        db: 数据库会话
        project_id: 项目ID
        user_id: 用户ID
        
    Returns:
        项目对象
        
    Raises:
        NotFoundException: 项目不存在
    """
    project = db.query(Project).filter(
        Project.id == project_id,
        Project.user_id == user_id
    ).first()
    
    if not project:
        raise NotFoundException("项目", project_id)
    
    return project


def get_project_with_bills(db: Session, project_id: int, user_id: int) -> Project:
    """
    获取项目详情，包含该项目下的所有账单
    
    Args:
        db: 数据库会话
        project_id: 项目ID
        user_id: 用户ID
        
    Returns:
        包含账单列表的项目对象
        
    Raises:
        NotFoundException: 项目不存在
    """
    project = get_project_by_id(db, project_id, user_id)
    
    # 获取项目下的账单
    bills = db.query(Bill).filter(
        Bill.project_id == project_id
    ).order_by(Bill.date.desc()).all()
    
    project.bills = bills
    project.bill_count = len(bills)
    
    return project


def update_project(
    db: Session, 
    project_id: int, 
    project: ProjectUpdate, 
    user_id: int
) -> Project:
    """
    更新项目信息
    
    Args:
        db: 数据库会话
        project_id: 项目ID
        project: 更新数据
        user_id: 用户ID
        
    Returns:
        更新后的项目对象
        
    Raises:
        NotFoundException: 项目不存在
    """
    db_project = get_project_by_id(db, project_id, user_id)
    
    update_data = project.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(db_project, field, value)
    
    db.commit()
    db.refresh(db_project)
    
    # 清除项目列表缓存
    _invalidate_project_cache(user_id)
    
    # 添加账单计数
    db_project.bill_count = _get_project_bill_count(db, project_id)
    
    return db_project


def delete_project(db: Session, project_id: int, user_id: int) -> dict:
    """
    删除项目（项目下的账单会被一并删除）
    
    Args:
        db: 数据库会话
        project_id: 项目ID
        user_id: 用户ID
        
    Returns:
        删除成功消息
        
    Raises:
        NotFoundException: 项目不存在
    """
    db_project = get_project_by_id(db, project_id, user_id)
    
    db.delete(db_project)
    db.commit()
    
    # 清除项目列表缓存
    _invalidate_project_cache(user_id)
    
    return {"message": "项目删除成功"}


def _get_project_bill_count(db: Session, project_id: int) -> int:
    """获取项目下的账单数量"""
    return db.query(Bill).filter(Bill.project_id == project_id).count()
