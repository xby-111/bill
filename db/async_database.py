"""
异步数据库连接配置模块

使用 SQLAlchemy 2.0 异步模式，支持：
- asyncpg: PostgreSQL 异步驱动
- aiosqlite: SQLite 异步驱动
- aiomysql: MySQL 异步驱动
"""
import os
from typing import AsyncGenerator
from urllib.parse import quote_plus
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.pool import NullPool, AsyncAdaptedQueuePool
from config import settings
import logging

logger = logging.getLogger(__name__)


def get_async_database_url() -> str:
    """
    根据配置返回异步数据库连接 URL
    
    Returns:
        SQLAlchemy 异步数据库连接字符串
    """
    if settings.DB_TYPE == "postgresql":
        if not settings.DB_USER:
            raise RuntimeError("PostgreSQL 需要设置 DB_USER 环境变量")
        encoded_password = quote_plus(settings.DB_PASSWORD or "")
        # 使用 asyncpg 驱动
        return f"postgresql+asyncpg://{settings.DB_USER}:{encoded_password}@{settings.DB_HOST}:{settings.DB_PORT}/{settings.DB_NAME}"
    
    elif settings.DB_TYPE == "mysql":
        if not settings.DB_USER:
            raise RuntimeError("MySQL 需要设置 DB_USER 环境变量")
        encoded_password = quote_plus(settings.DB_PASSWORD or "")
        # 使用 aiomysql 驱动
        return f"mysql+aiomysql://{settings.DB_USER}:{encoded_password}@{settings.DB_HOST}:{settings.DB_PORT}/{settings.DB_NAME}?charset=utf8mb4"
    
    # 默认使用 SQLite（aiosqlite 驱动）
    return f"sqlite+aiosqlite:///{settings.SQLITE_PATH}"


def create_async_db_engine():
    """
    创建 SQLAlchemy 异步引擎
    
    根据数据库类型配置不同的连接参数
    """
    url = get_async_database_url()
    echo = os.getenv("DB_ECHO", "false").lower() == "true"

    if settings.DB_TYPE in ["postgresql", "mysql"]:
        # PostgreSQL/MySQL: 启用异步连接池
        return create_async_engine(
            url,
            poolclass=AsyncAdaptedQueuePool,
            pool_size=settings.DB_POOL_SIZE,
            max_overflow=settings.DB_MAX_OVERFLOW,
            pool_pre_ping=True,  # 连接前检查是否有效
            pool_recycle=3600,   # 1小时回收连接
            echo=echo,
            # 慢查询日志阈值（秒）
            echo_pool="debug" if settings.DEBUG else False,
        )

    # SQLite: 使用 NullPool（aiosqlite 不支持连接池）
    return create_async_engine(
        url, 
        poolclass=NullPool,
        echo=echo,
    )


# 创建异步引擎和会话工厂
async_engine = create_async_db_engine()

# 异步会话工厂
AsyncSessionLocal = async_sessionmaker(
    bind=async_engine,
    class_=AsyncSession,
    autocommit=False,
    autoflush=False,
    expire_on_commit=False,  # 提升性能，避免额外的数据库查询
)


async def get_async_db() -> AsyncGenerator[AsyncSession, None]:
    """FastAPI 依赖注入：获取异步数据库会话"""
    async with AsyncSessionLocal() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


async def init_async_db():
    """初始化异步数据库（创建表）"""
    from db.database import Base
    async with async_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)


async def close_async_db():
    """关闭异步数据库连接"""
    await async_engine.dispose()
    logger.info("异步数据库连接已关闭")
