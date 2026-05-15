from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import ORJSONResponse
from contextlib import asynccontextmanager
from db.database import warmup_connection_pool
from db.init_db import create_tables
from routers import auth, bills, projects, monitor, family
from utils.exceptions import register_exception_handlers
from utils.logging_config import setup_logging
from config import settings
import logging
import uuid
import time

# 初始化日志系统
setup_logging()
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    应用生命周期管理
    
    启动时：初始化数据库、连接池预热、缓存初始化
    关闭时：清理连接
    """
    # 启动
    logger.info("应用启动中...")
    
    # 1. 创建数据库表
    create_tables()
    logger.info("数据库表已就绪")
    
    # 2. 连接池预热（减少首次请求延迟）
    warmup_connection_pool(pool_size=5)
    
    # 3. 初始化缓存（预热 Redis 连接，如果配置了的话）
    try:
        from utils.cache import get_redis_client
        await get_redis_client()
    except Exception as e:
        logger.debug(f"缓存初始化: {e}")
    
    yield
    
    # 关闭
    logger.info("应用关闭中...")
    
    # 关闭 Redis 连接
    try:
        from utils.cache import close_redis
        await close_redis()
    except Exception as e:
        logger.warning(f"关闭 Redis 连接时出错: {e}")
    
    logger.info("应用已关闭")


# 验证配置
try:
    settings.validate()
    logger.info("配置验证通过")
except ValueError as e:
    logger.error(f"配置验证失败: {e}")
    raise

# 使用 ORJSONResponse 提升 JSON 序列化性能
app = FastAPI(
    title="个人账单管理系统", 
    version="1.0.0",
    description="家庭工时记账系统 API",
    default_response_class=ORJSONResponse,
    docs_url="/docs",  # API 文档路径
    redoc_url="/redoc",  # ReDoc 文档路径
    lifespan=lifespan,  # 添加生命周期管理
)

# 开启 Gzip 压缩 (最小 1KB 触发)，大幅降低移动端流量消耗，提升速度
app.add_middleware(GZipMiddleware, minimum_size=1000)

# 配置CORS（从配置读取允许的域名）
cors_origins = settings.CORS_ORIGINS
app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization", "X-Request-ID"],
    expose_headers=["X-Request-ID", "X-Process-Time"],
    max_age=600,  # 预检请求缓存10分钟
)


# 请求追踪中间件：添加请求ID和处理时间
@app.middleware("http")
async def add_request_metadata(request: Request, call_next):
    """添加请求ID和处理时间到响应头"""
    request_id = request.headers.get("X-Request-ID", str(uuid.uuid4())[:8])
    start_time = time.time()
    
    # 将 request_id 存入 state 供日志使用
    request.state.request_id = request_id
    
    response = await call_next(request)
    
    # 添加响应头
    process_time = time.time() - start_time
    response.headers["X-Request-ID"] = request_id
    response.headers["X-Process-Time"] = f"{process_time:.3f}s"
    
    # 记录慢请求
    if process_time > 1.0:
        logger.warning(f"慢请求 [{request_id}] {request.method} {request.url.path} - {process_time:.2f}s")
    
    return response

# 注册全局异常处理
register_exception_handlers(app)

# 注册路由（统一使用v1版本前缀）
app.include_router(auth.router, prefix="/api/v1")
app.include_router(bills.router, prefix="/api/v1")
app.include_router(projects.router, prefix="/api/v1")
app.include_router(monitor.router, prefix="/api/v1")
app.include_router(family.router, prefix="/api/v1")


@app.get("/", tags=["系统"])
def read_root():
    """API 根路径"""
    return {
        "message": "欢迎使用个人账单管理系统",
        "version": "1.0.0",
        "docs": "/docs" if settings.DEBUG else "生产环境已禁用",
        "health_check": "/api/v1/monitor/health"
    }