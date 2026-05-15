"""
数据库迁移：为没有项目的旧账单设置默认项目

执行此迁移前，系统会：
1. 为每个用户创建一个"默认项目"（如果不存在）
2. 将所有 project_id 为 NULL 的账单关联到该默认项目
"""
import sys
from pathlib import Path

# 添加项目根目录到路径
sys.path.insert(0, str(Path(__file__).parent.parent))

from sqlalchemy import create_engine, update, select, and_
from sqlalchemy.orm import Session
from models.bill import Bill
from models.project import Project
from models.user import User
from config.config import get_settings

settings = get_settings()


def migrate():
    """执行迁移"""
    engine = create_engine(settings.database_url)
    
    with Session(engine) as session:
        # 获取所有用户
        users = session.execute(select(User)).scalars().all()
        
        total_updated = 0
        
        for user in users:
            print(f"\n处理用户: {user.username} (ID: {user.id})")
            
            # 查找该用户是否有 project_id 为 NULL 的账单
            null_bills_count = session.execute(
                select(Bill).where(
                    and_(
                        Bill.user_id == user.id,
                        Bill.project_id.is_(None)
                    )
                )
            ).scalars().all()
            
            if not null_bills_count:
                print(f"  ✓ 无需迁移（没有未分配项目的账单）")
                continue
            
            print(f"  发现 {len(null_bills_count)} 个未分配项目的账单")
            
            # 查找或创建"默认项目"
            default_project = session.execute(
                select(Project).where(
                    and_(
                        Project.user_id == user.id,
                        Project.name == "默认项目"
                    )
                )
            ).scalar_one_or_none()
            
            if not default_project:
                print(f"  → 创建默认项目...")
                default_project = Project(
                    name="默认项目",
                    description="系统自动创建，用于存放未分配项目的历史账单",
                    user_id=user.id
                )
                session.add(default_project)
                session.flush()  # 获取 ID
                print(f"  ✓ 默认项目创建成功 (ID: {default_project.id})")
            else:
                print(f"  ✓ 使用已存在的默认项目 (ID: {default_project.id})")
            
            # 更新所有 NULL 的 project_id
            result = session.execute(
                update(Bill)
                .where(
                    and_(
                        Bill.user_id == user.id,
                        Bill.project_id.is_(None)
                    )
                )
                .values(project_id=default_project.id)
            )
            
            updated_count = result.rowcount
            total_updated += updated_count
            print(f"  ✓ 已更新 {updated_count} 个账单")
        
        # 提交事务
        session.commit()
        print(f"\n" + "="*50)
        print(f"迁移完成！共更新 {total_updated} 个账单")
        print("="*50)


if __name__ == "__main__":
    print("="*50)
    print("数据库迁移：设置默认项目")
    print("="*50)
    print("\n⚠️  此脚本将：")
    print("  1. 为每个有未分配账单的用户创建'默认项目'")
    print("  2. 将所有 project_id=NULL 的账单关联到默认项目")
    print("\n继续吗？(yes/no): ", end="")
    
    response = input().strip().lower()
    if response in ['yes', 'y']:
        migrate()
    else:
        print("\n已取消迁移")
