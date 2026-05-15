"""
数据库迁移脚本：添加家庭组功能

创建 families 表并在 users 表添加 family_id 字段
"""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import text
from db.database import engine


def migrate():
    """执行迁移"""
    with engine.connect() as conn:
        # 1. 创建 families 表
        conn.execute(text("""
            CREATE TABLE IF NOT EXISTS families (
                id SERIAL PRIMARY KEY,
                name VARCHAR(100) NOT NULL,
                invite_code VARCHAR(10) NOT NULL UNIQUE,
                created_by INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """))
        print("✓ 创建 families 表")
        
        # 2. 创建邀请码索引
        conn.execute(text("""
            CREATE INDEX IF NOT EXISTS idx_families_invite_code 
            ON families(invite_code)
        """))
        print("✓ 创建 invite_code 索引")
        
        # 3. 为 users 表添加 family_id 和 family_joined_at 字段
        # 检查 family_id 字段是否存在
        result = conn.execute(text("""
            SELECT column_name FROM information_schema.columns 
            WHERE table_name = 'users' AND column_name = 'family_id'
        """))
        
        if result.fetchone() is None:
            conn.execute(text("""
                ALTER TABLE users 
                ADD COLUMN family_id INTEGER REFERENCES families(id) ON DELETE SET NULL
            """))
            print("✓ 添加 users.family_id 字段")
        else:
            print("- users.family_id 已存在，跳过")
        
        # 检查 family_joined_at 字段是否存在
        result = conn.execute(text("""
            SELECT column_name FROM information_schema.columns 
            WHERE table_name = 'users' AND column_name = 'family_joined_at'
        """))
        
        if result.fetchone() is None:
            conn.execute(text("""
                ALTER TABLE users 
                ADD COLUMN family_joined_at TIMESTAMP
            """))
            print("✓ 添加 users.family_joined_at 字段")
        else:
            print("- users.family_joined_at 已存在，跳过")
        
        # 4. 创建 family_id 索引
        conn.execute(text("""
            CREATE INDEX IF NOT EXISTS idx_users_family_id 
            ON users(family_id)
        """))
        print("✓ 创建 users.family_id 索引")
        
        conn.commit()
        print("\n✅ 家庭组迁移完成！")


def rollback():
    """回滚迁移"""
    with engine.connect() as conn:
        # 1. 删除 users 表的 family 相关字段
        result = conn.execute(text("""
            SELECT column_name FROM information_schema.columns 
            WHERE table_name = 'users' AND column_name = 'family_id'
        """))
        
        if result.fetchone():
            conn.execute(text("ALTER TABLE users DROP COLUMN IF EXISTS family_joined_at"))
            conn.execute(text("ALTER TABLE users DROP COLUMN IF EXISTS family_id"))
            print("✓ 删除 users 表的 family 相关字段")
        
        # 2. 删除 families 表
        conn.execute(text("DROP TABLE IF EXISTS families CASCADE"))
        print("✓ 删除 families 表")
        
        conn.commit()
        print("\n✅ 回滚完成！")


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="家庭组迁移脚本")
    parser.add_argument("--rollback", action="store_true", help="回滚迁移")
    args = parser.parse_args()
    
    if args.rollback:
        print("正在回滚家庭组迁移...")
        rollback()
    else:
        print("正在执行家庭组迁移...")
        migrate()
