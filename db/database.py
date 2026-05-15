"""
数据库连接配置模块

支持的数据库类型:
- sqlite: 本地开发，零配置，适合个人/小家庭使用
- postgresql: 生产环境，支持并发，适合多用户
- mysql: 可选，生态丰富

性能优化:
- 连接池优化配置
- 慢查询日志记录
- 连接健康检查
"""
import os
import time
import logging
from urllib.parse import quote_plus
from sqlalchemy import create_engine, event, text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from sqlalchemy.engine import Engine
from config import settings

logger = logging.getLogger(__name__)

# 慢查询阈值（秒）
SLOW_QUERY_THRESHOLD = float(os.getenv("SLOW_QUERY_THRESHOLD", "0.5"))


def get_database_url() -> str:
    """
    根据配置返回数据库连接 URL
    
    Returns:
        SQLAlchemy 数据库连接字符串
    """
    if settings.DB_TYPE == "postgresql":
        if not settings.DB_USER:
            raise RuntimeError("PostgreSQL 需要设置 DB_USER 环境变量")
        encoded_password = quote_plus(settings.DB_PASSWORD or "")
        return f"postgresql+psycopg2://{settings.DB_USER}:{encoded_password}@{settings.DB_HOST}:{settings.DB_PORT}/{settings.DB_NAME}"
    
    elif settings.DB_TYPE == "mysql":
        if not settings.DB_USER:
            raise RuntimeError("MySQL 需要设置 DB_USER 环境变量")
        encoded_password = quote_plus(settings.DB_PASSWORD or "")
        return f"mysql+pymysql://{settings.DB_USER}:{encoded_password}@{settings.DB_HOST}:{settings.DB_PORT}/{settings.DB_NAME}?charset=utf8mb4"
    
    # 默认使用 SQLite（适合个人/家庭使用）
    return f"sqlite:///{settings.SQLITE_PATH}"


def create_db_engine():
    """
    创建 SQLAlchemy 引擎
    
    根据数据库类型配置不同的连接参数
    性能优化：
    - 增大连接池
    - 启用连接回收
    - 配置连接超时
    """
    url = get_database_url()
    echo = os.getenv("DB_ECHO", "false").lower() == "true"

    if settings.DB_TYPE in ["postgresql", "mysql"]:
        # PostgreSQL/MySQL: 优化连接池配置
        return create_engine(
            url,
            pool_size=settings.DB_POOL_SIZE,           # 连接池大小
            max_overflow=settings.DB_MAX_OVERFLOW,     # 溢出连接数
            pool_pre_ping=True,                        # 连接前检查是否有效
            pool_recycle=1800,                         # 30分钟回收连接（避免连接超时）
            pool_timeout=30,                           # 获取连接超时（秒）
            pool_use_lifo=True,                        # LIFO 模式，复用热连接
            echo=echo,
        )

    # SQLite: 允许跨线程访问，并设置UTF-8编码
    eng = create_engine(
        url, 
        connect_args={"check_same_thread": False},
        echo=echo,
    )
    
    # 设置SQLite使用UTF-8编码
    @event.listens_for(eng, "connect")
    def set_sqlite_pragma(dbapi_connection, connection_record):
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA encoding = 'UTF-8'")
        cursor.close()
    
    return eng


# 慢查询日志事件监听器
@event.listens_for(Engine, "before_cursor_execute")
def before_cursor_execute(conn, cursor, statement, parameters, context, executemany):
    """记录 SQL 执行开始时间"""
    conn.info.setdefault('query_start_time', []).append(time.time())


@event.listens_for(Engine, "after_cursor_execute")
def after_cursor_execute(conn, cursor, statement, parameters, context, executemany):
    """检查慢查询并记录日志"""
    total = time.time() - conn.info['query_start_time'].pop(-1)
    if total >= SLOW_QUERY_THRESHOLD:
        # 截断过长的 SQL
        sql_preview = statement[:500] + "..." if len(statement) > 500 else statement
        logger.warning(
            f"慢查询 [{total:.3f}s]: {sql_preview}",
            extra={
                "duration": total,
                "statement": statement[:1000],
                "parameters": str(parameters)[:200] if parameters else None
            }
        )


# 创建引擎和会话
engine = create_db_engine()
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def warmup_connection_pool(pool_size: int = 3):
    """
    预热数据库连接池
    
    在应用启动时预先建立数据库连接，避免首次请求时的连接建立延迟。
    
    Args:
        pool_size: 预热连接数量（建议 3-5 个）
    """
    if settings.DB_TYPE == "sqlite":
        # SQLite 不需要预热
        return
    
    connections = []
    try:
        # 预先建立连接
        for _ in range(pool_size):
            conn = engine.connect()
            connections.append(conn)
        
        # 执行简单查询确保连接可用
        for conn in connections:
            conn.execute(text("SELECT 1"))
        
        logger.info(f"连接池预热完成: {pool_size} 个连接已就绪")
    except Exception as e:
        logger.warning(f"连接池预热失败: {e}")
    finally:
        # 将连接放回池中（不关闭）
        for conn in connections:
            conn.close()


def get_db():
    """FastAPI 依赖注入：获取数据库会话"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
