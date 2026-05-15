"""
数据库迁移脚本：添加 projects 表并修改 bills 表
执行时间：2024年
功能：
1. 创建 projects 表
2. 在 bills 表添加 name 和 project_id 列
3. 将 worker 字段内容迁移到 name 字段
4. 删除 worker 列（可选，保留则注释相关代码）
"""

import sys
import os
# 添加父目录到 Python 路径
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import create_engine, text
from config import settings
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def get_database_url():
    """根据配置生成数据库连接URL"""
    db_type = settings.DB_TYPE.lower()
    
    if db_type == "sqlite":
        return f"sqlite:///{settings.DB_NAME}.db"
    elif db_type == "postgresql":
        return f"postgresql://{settings.DB_USER}:{settings.DB_PASSWORD}@{settings.DB_HOST}:{settings.DB_PORT}/{settings.DB_NAME}"
    elif db_type == "mysql":
        return f"mysql+pymysql://{settings.DB_USER}:{settings.DB_PASSWORD}@{settings.DB_HOST}:{settings.DB_PORT}/{settings.DB_NAME}"
    else:
        raise ValueError(f"不支持的数据库类型: {db_type}")


def run_migration():
    """执行数据库迁移"""
    database_url = get_database_url()
    logger.info(f"连接数据库: {settings.DB_TYPE} @ {settings.DB_HOST}")
    
    engine = create_engine(database_url, echo=True)
    db_type = settings.DB_TYPE.lower()
    
    with engine.connect() as conn:
        # 开启事务
        trans = conn.begin()
        
        try:
            # 1. 创建 projects 表
            logger.info("创建 projects 表...")
            
            if db_type == "sqlite":
                conn.execute(text("""
                    CREATE TABLE IF NOT EXISTS projects (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        name VARCHAR(255) NOT NULL,
                        description TEXT,
                        user_id INTEGER NOT NULL,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
                    )
                """))
            else:
                conn.execute(text("""
                    CREATE TABLE IF NOT EXISTS projects (
                        id SERIAL PRIMARY KEY,
                        name VARCHAR(255) NOT NULL,
                        description TEXT,
                        user_id INTEGER NOT NULL,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
                    )
                """))
            
            logger.info("✅ projects 表创建成功")
            
            # 2. 检查 bills 表是否已有 name 列
            logger.info("检查 bills 表结构...")
            
            if db_type == "sqlite":
                # SQLite 使用 PRAGMA 查询表结构
                result = conn.execute(text("PRAGMA table_info(bills)"))
                columns = [row[1] for row in result.fetchall()]
                has_name = 'name' in columns
                has_project_id = 'project_id' in columns
            else:
                # PostgreSQL/MySQL 使用 information_schema
                result = conn.execute(text("""
                    SELECT column_name 
                    FROM information_schema.columns 
                    WHERE table_name='bills' AND column_name='name'
                """))
                has_name = result.fetchone() is not None
                
                result = conn.execute(text("""
                    SELECT column_name 
                    FROM information_schema.columns 
                    WHERE table_name='bills' AND column_name='project_id'
                """))
                has_project_id = result.fetchone() is not None
            
            if not has_name:
                # 3. 添加 name 列
                logger.info("添加 bills.name 列...")
                conn.execute(text("""
                    ALTER TABLE bills ADD COLUMN name VARCHAR(255)
                """))
                
                # 4. 将 worker 数据迁移到 name（如果 worker 列存在）
                logger.info("迁移 worker 数据到 name 列...")
                conn.execute(text("""
                    UPDATE bills SET name = worker WHERE worker IS NOT NULL
                """))
                logger.info("✅ 数据迁移完成")
            else:
                logger.info("⚠️ bills.name 列已存在，跳过添加")
            
            # 5. 检查并添加 project_id 列
            if not has_project_id:
                logger.info("添加 bills.project_id 列...")
                conn.execute(text("""
                    ALTER TABLE bills ADD COLUMN project_id INTEGER
                """))
                
                # 添加外键约束（SQLite 在表创建时定义外键，这里跳过）
                if db_type != "sqlite":
                    conn.execute(text("""
                        ALTER TABLE bills 
                        ADD CONSTRAINT fk_bills_project 
                        FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE SET NULL
                    """))
                logger.info("✅ project_id 列和外键添加成功")
            else:
                logger.info("⚠️ bills.project_id 列已存在，跳过添加")
            
            # 6. [可选] 删除 worker 列
            # 取消注释以下代码来删除 worker 列
            # logger.info("删除 bills.worker 列...")
            # conn.execute(text("""
            #     ALTER TABLE bills DROP COLUMN worker
            # """))
            # logger.info("✅ worker 列删除成功")
            
            # 提交事务
            trans.commit()
            logger.info("🎉 数据库迁移完成！")
            
        except Exception as e:
            # 回滚事务
            trans.rollback()
            logger.error(f"❌ 迁移失败: {e}")
            raise


if __name__ == "__main__":
    logger.info("=" * 60)
    logger.info("开始执行数据库迁移：添加 projects 表")
    logger.info("=" * 60)
    run_migration()
