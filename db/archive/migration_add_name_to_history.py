"""
数据库迁移脚本：为 bill_histories 表添加 name 列
执行时间：2025-12-31
功能：在 bill_histories 表中添加 name 字段以支持账单名称历史记录
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


def check_column_exists(conn, table_name: str, column_name: str, db_type: str) -> bool:
    """检查列是否已存在"""
    if db_type == "sqlite":
        result = conn.execute(text(f"PRAGMA table_info({table_name})"))
        columns = [row[1] for row in result.fetchall()]
        return column_name in columns
    elif db_type == "postgresql":
        result = conn.execute(text("""
            SELECT column_name FROM information_schema.columns 
            WHERE table_name = :table_name AND column_name = :column_name
        """), {"table_name": table_name, "column_name": column_name})
        return result.fetchone() is not None
    elif db_type == "mysql":
        result = conn.execute(text("""
            SELECT column_name FROM information_schema.columns 
            WHERE table_name = :table_name AND column_name = :column_name
        """), {"table_name": table_name, "column_name": column_name})
        return result.fetchone() is not None
    return False


def run_migration():
    """执行数据库迁移：为 bill_histories 表添加 name 列"""
    database_url = get_database_url()
    logger.info(f"连接数据库: {settings.DB_TYPE} @ {settings.DB_HOST}")
    
    engine = create_engine(database_url, echo=True)
    db_type = settings.DB_TYPE.lower()
    
    with engine.connect() as conn:
        trans = conn.begin()
        
        try:
            # 检查 name 列是否已存在
            if check_column_exists(conn, "bill_histories", "name", db_type):
                logger.info("✓ bill_histories.name 列已存在，跳过迁移")
                trans.commit()
                return True
            
            # 添加 name 列
            logger.info("添加 bill_histories.name 列...")
            
            if db_type == "sqlite":
                conn.execute(text("""
                    ALTER TABLE bill_histories ADD COLUMN name VARCHAR(200)
                """))
            elif db_type == "postgresql":
                conn.execute(text("""
                    ALTER TABLE bill_histories ADD COLUMN name VARCHAR(200)
                """))
            elif db_type == "mysql":
                conn.execute(text("""
                    ALTER TABLE bill_histories ADD COLUMN name VARCHAR(200) AFTER operation_type
                """))
            
            logger.info("✓ name 列添加成功")
            
            # 提交事务
            trans.commit()
            logger.info("✓ 迁移完成！")
            return True
            
        except Exception as e:
            trans.rollback()
            logger.error(f"✗ 迁移失败: {e}")
            raise


def rollback_migration():
    """回滚迁移：删除 name 列"""
    database_url = get_database_url()
    engine = create_engine(database_url, echo=True)
    db_type = settings.DB_TYPE.lower()
    
    with engine.connect() as conn:
        trans = conn.begin()
        
        try:
            if not check_column_exists(conn, "bill_histories", "name", db_type):
                logger.info("name 列不存在，无需回滚")
                trans.commit()
                return True
            
            logger.info("删除 bill_histories.name 列...")
            
            if db_type == "sqlite":
                # SQLite 不支持 DROP COLUMN（需要重建表）
                logger.warning("SQLite 不支持直接删除列，需要手动重建表")
            elif db_type == "postgresql":
                conn.execute(text("""
                    ALTER TABLE bill_histories DROP COLUMN name
                """))
            elif db_type == "mysql":
                conn.execute(text("""
                    ALTER TABLE bill_histories DROP COLUMN name
                """))
            
            trans.commit()
            logger.info("✓ 回滚完成")
            return True
            
        except Exception as e:
            trans.rollback()
            logger.error(f"✗ 回滚失败: {e}")
            raise


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="bill_histories 表添加 name 列迁移")
    parser.add_argument("--rollback", action="store_true", help="回滚迁移")
    args = parser.parse_args()
    
    if args.rollback:
        rollback_migration()
    else:
        run_migration()
