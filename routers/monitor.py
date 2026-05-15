"""
系统监控路由模块

提供：
- 健康检查端点
- 性能统计端点
- 缓存状态端点
"""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import text
from datetime import datetime
from typing import Optional
from db.database import get_db
from config import settings
from routers.auth import get_current_user
from schemas.user import UserResponse
import logging

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/monitor", tags=["系统监控"])


@router.get("/health", summary="健康检查")
async def health_check(db: Session = Depends(get_db)):
    """
    健康检查接口
    
    用于负载均衡器和监控系统检测服务状态
    无需认证
    """
    # 检查数据库连接
    db_status = "connected"
    db_latency = None
    try:
        start = datetime.utcnow()
        db.execute(text("SELECT 1"))
        db_latency = (datetime.utcnow() - start).total_seconds() * 1000
    except Exception as e:
        db_status = f"error: {str(e)}"
    
    # 检查 Redis
    redis_status = "not_configured"
    redis_latency = None
    if settings.REDIS_URL:
        try:
            from utils.cache import get_redis_client
            import asyncio
            
            redis = await get_redis_client()
            if redis:
                start = datetime.utcnow()
                await redis.ping()
                redis_latency = (datetime.utcnow() - start).total_seconds() * 1000
                redis_status = "connected"
            else:
                redis_status = "fallback_to_memory"
        except Exception as e:
            redis_status = f"error: {str(e)}"
    
    status = "healthy"
    if db_status != "connected":
        status = "degraded"
    
    return {
        "status": status,
        "timestamp": datetime.utcnow().isoformat(),
        "version": settings.APP_VERSION,
        "components": {
            "database": {
                "status": db_status,
                "latency_ms": db_latency,
            },
            "cache": {
                "status": redis_status,
                "latency_ms": redis_latency,
            },
        },
        "debug_mode": settings.DEBUG,
    }


@router.get("/stats", summary="性能统计")
async def get_performance_stats(
    current_user: UserResponse = Depends(get_current_user)
):
    """
    获取系统性能统计（需要认证）
    
    返回请求统计、缓存命中率、数据库查询统计等
    """
    try:
        from utils.performance import monitor
        stats = monitor.get_stats()
        return {
            "success": True,
            "data": stats,
        }
    except Exception as e:
        logger.warning(f"获取性能统计失败: {e}")
        return {
            "success": False,
            "message": "性能监控模块未启用",
        }


@router.get("/cache", summary="缓存状态")
async def get_cache_status(
    current_user: UserResponse = Depends(get_current_user)
):
    """
    获取缓存状态（需要认证）
    """
    from utils.cache import _redis_available, _memory_cache
    
    memory_cache_size = len(_memory_cache._cache)
    
    result = {
        "redis_enabled": settings.REDIS_URL != "",
        "redis_available": _redis_available or False,
        "memory_cache_size": memory_cache_size,
        "memory_cache_maxsize": _memory_cache.maxsize,
    }
    
    if _redis_available:
        try:
            from utils.cache import get_redis_client
            redis = await get_redis_client()
            if redis:
                info = await redis.info("memory")
                result["redis_memory"] = {
                    "used_memory": info.get("used_memory_human"),
                    "peak_memory": info.get("used_memory_peak_human"),
                }
        except Exception as e:
            result["redis_error"] = str(e)
    
    return result


@router.post("/cache/clear", summary="清空缓存")
async def clear_cache(
    pattern: Optional[str] = None,
    current_user: UserResponse = Depends(get_current_user)
):
    """
    清空缓存（需要认证）
    
    - 不传 pattern：清空所有缓存
    - 传 pattern：按模式清空（仅 Redis 支持）
    """
    from utils.cache import cache_delete_pattern, _memory_cache
    
    if pattern:
        count = await cache_delete_pattern(pattern)
        return {"message": f"已清除 {count} 个缓存键", "pattern": pattern}
    else:
        _memory_cache.clear()
        await cache_delete_pattern("*")
        return {"message": "已清空所有缓存"}
