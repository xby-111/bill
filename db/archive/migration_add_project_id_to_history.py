"""
数据库迁移脚本：为 bill_histories 表添加 project_id 字段

运行方式：
    python -m db.migration_add_project_id_to_history

功能：
    - 为 bill_histories 表添加 project_id 列
    - 支持 SQLite、PostgreSQL、MySQL
"""
import os
import sys
from pathlib import Path

# 添加项目根目录到路径
sys.path.insert(0, str(Path(__file__).parent.parent))

from sqlalchemy import create_engine, text, inspect
from config import settings
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def get_database_url() -> str:
    """获取数据库连接URL"""
    if settings.DB_TYPE == "sqlite":
        return f"sqlite:///{settings.SQLITE_PATH}"
    elif settings.DB_TYPE == "postgresql":
        return f"postgresql://{settings.DB_USER}:{settings.DB_PASSWORD}@{settings.DB_HOST}:{settings.DB_PORT}/{settings.DB_NAME}"
    elif settings.DB_TYPE == "mysql":
        return f"mysql+pymysql://{settings.DB_USER}:{settings.DB_PASSWORD}@{settings.DB_HOST}:{settings.DB_PORT}/{settings.DB_NAME}"
    else:
        raise ValueError(f"不支持的数据库类型: {settings.DB_TYPE}")


def column_exists(engine, table_name: str, column_name: str) -> bool:
    """检查列是否已存在"""
    inspector = inspect(engine)
    columns = [col['name'] for col in inspector.get_columns(table_name)]
    return column_name in columns


def run_migration():
    """执行迁移"""
    database_url = get_database_url()
    engine = create_engine(database_url)
    
    table_name = "bill_histories"
    column_name = "project_id"
    
    # 检查列是否已存在
    if column_exists(engine, table_name, column_name):
        logger.info(f"列 '{column_name}' 已存在于表 '{table_name}' 中，跳过迁移")
        return
    
    # 根据数据库类型执行迁移
    with engine.connect() as conn:
        if settings.DB_TYPE == "sqlite":
            # SQLite
            sql = f"ALTER TABLE {table_name} ADD COLUMN {column_name} INTEGER"
        elif settings.DB_TYPE == "postgresql":
            # PostgreSQL
            sql = f"ALTER TABLE {table_name} ADD COLUMN {column_name} INTEGER"
        elif settings.DB_TYPE == "mysql":
            # MySQL
            sql = f"ALTER TABLE {table_name} ADD COLUMN {column_name} INT"
        else:
            raise ValueError(f"不支持的数据库类型: {settings.DB_TYPE}")
        
        logger.info(f"执行迁移: {sql}")
        conn.execute(text(sql))
        conn.commit()
        logger.info(f"成功为表 '{table_name}' 添加列 '{column_name}'")


if __name__ == "__main__":
    try:
        run_migration()
        logger.info("迁移完成！")
    except Exception as e:
        logger.error(f"迁移失败: {e}")
        sys.exit(1)
