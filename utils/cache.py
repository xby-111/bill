"""
Redis 缓存模块

提供统一的缓存接口，支持：
- 用户信息缓存
- JWT Token 验证缓存
- 统计数据缓存
- 热点数据缓存

如果 Redis 不可用，自动降级到内存缓存（LRU）
"""
import json
import hashlib
import asyncio
import time
from typing import Optional, Any, Callable, TypeVar
from functools import wraps
from collections import OrderedDict
from threading import RLock
import logging
from config import settings

logger = logging.getLogger(__name__)

# Redis 客户端（延迟加载）
_redis_client = None
_redis_available = None


class TTLCache:
    """带 TTL 的线程安全内存缓存"""
    
    def __init__(self, maxsize: int = 1000, default_ttl: int = 300):
        self.maxsize = maxsize
        self.default_ttl = default_ttl
        self._cache: OrderedDict = OrderedDict()
        self._lock = RLock()
    
    def get(self, key: str) -> Optional[Any]:
        """获取缓存值"""
        with self._lock:
            if key not in self._cache:
                return None
            value, expire_at = self._cache[key]
            if time.time() > expire_at:
                del self._cache[key]
                return None
            # 移到末尾（LRU）
            self._cache.move_to_end(key)
            return value
    
    def set(self, key: str, value: Any, ttl: Optional[int] = None):
        """设置缓存值"""
        with self._lock:
            expire_at = time.time() + (ttl or self.default_ttl)
            self._cache[key] = (value, expire_at)
            self._cache.move_to_end(key)
            # 清理过期和超限
            self._cleanup()
    
    def delete(self, key: str):
        """删除缓存"""
        with self._lock:
            self._cache.pop(key, None)
    
    def clear(self):
        """清空缓存"""
        with self._lock:
            self._cache.clear()
    
    def _cleanup(self):
        """清理过期项和超限项"""
        now = time.time()
        # 删除过期项
        expired_keys = [k for k, (_, exp) in self._cache.items() if now > exp]
        for k in expired_keys:
            del self._cache[k]
        # 删除超限项（LRU）
        while len(self._cache) > self.maxsize:
            self._cache.popitem(last=False)


# 全局内存缓存实例
_memory_cache = TTLCache(maxsize=2000, default_ttl=300)


async def get_redis_client():
    """获取 Redis 客户端（单例）"""
    global _redis_client, _redis_available
    
    if _redis_available is False:
        return None
    
    if _redis_client is not None:
        return _redis_client
    
    # 检查是否配置了 Redis
    redis_url = getattr(settings, 'REDIS_URL', None)
    if not redis_url:
        logger.info("未配置 REDIS_URL，使用内存缓存")
        _redis_available = False
        return None
    
    try:
        from redis import asyncio as aioredis
        _redis_client = aioredis.from_url(
            redis_url,
            encoding="utf-8",
            decode_responses=True,
            socket_connect_timeout=5,
            socket_timeout=5,
            retry_on_timeout=True,
            max_connections=settings.REDIS_MAX_CONNECTIONS if hasattr(settings, 'REDIS_MAX_CONNECTIONS') else 20,
        )
        # 测试连接
        await _redis_client.ping()
        logger.info("Redis 连接成功")
        _redis_available = True
        return _redis_client
    except Exception as e:
        logger.warning(f"Redis 连接失败，降级到内存缓存: {e}")
        _redis_available = False
        return None


async def cache_get(key: str) -> Optional[str]:
    """获取缓存（自动选择 Redis 或内存）"""
    redis = await get_redis_client()
    if redis:
        try:
            return await redis.get(key)
        except Exception as e:
            logger.warning(f"Redis GET 失败: {e}")
    
    # 回退到内存缓存
    return _memory_cache.get(key)


async def cache_set(key: str, value: str, ttl: int = 300) -> bool:
    """设置缓存（自动选择 Redis 或内存）"""
    redis = await get_redis_client()
    if redis:
        try:
            await redis.set(key, value, ex=ttl)
            return True
        except Exception as e:
            logger.warning(f"Redis SET 失败: {e}")
    
    # 回退到内存缓存
    _memory_cache.set(key, value, ttl)
    return True


async def cache_delete(key: str) -> bool:
    """删除缓存"""
    redis = await get_redis_client()
    if redis:
        try:
            await redis.delete(key)
        except Exception as e:
            logger.warning(f"Redis DELETE 失败: {e}")
    
    _memory_cache.delete(key)
    return True


async def cache_delete_pattern(pattern: str) -> int:
    """按模式删除缓存（仅 Redis 支持）"""
    redis = await get_redis_client()
    if redis:
        try:
            keys = []
            async for key in redis.scan_iter(pattern):
                keys.append(key)
            if keys:
                await redis.delete(*keys)
            return len(keys)
        except Exception as e:
            logger.warning(f"Redis DELETE PATTERN 失败: {e}")
    
    # 内存缓存不支持模式删除，清空全部
    _memory_cache.clear()
    return 0


def cache_key(*args, prefix: str = "cache") -> str:
    """生成缓存 key"""
    key_data = ":".join(str(arg) for arg in args)
    return f"{prefix}:{key_data}"


def cache_key_hash(*args, prefix: str = "cache") -> str:
    """生成带哈希的缓存 key（用于长 key）"""
    key_data = ":".join(str(arg) for arg in args)
    hash_val = hashlib.md5(key_data.encode()).hexdigest()[:16]
    return f"{prefix}:{hash_val}"


T = TypeVar('T')


def cached(
    ttl: int = 300,
    prefix: str = "cache",
    key_builder: Optional[Callable[..., str]] = None,
):
    """
    缓存装饰器（支持异步函数）
    
    Args:
        ttl: 缓存过期时间（秒）
        prefix: 缓存 key 前缀
        key_builder: 自定义 key 构建函数
    
    Example:
        @cached(ttl=60, prefix="user")
        async def get_user(user_id: int):
            ...
    """
    def decorator(func: Callable[..., T]) -> Callable[..., T]:
        @wraps(func)
        async def async_wrapper(*args, **kwargs):
            # 构建缓存 key
            if key_builder:
                cache_k = key_builder(*args, **kwargs)
            else:
                # 默认 key：函数名 + 参数
                func_name = func.__name__
                args_str = ":".join(str(a) for a in args)
                kwargs_str = ":".join(f"{k}={v}" for k, v in sorted(kwargs.items()))
                cache_k = cache_key(func_name, args_str, kwargs_str, prefix=prefix)
            
            # 尝试从缓存获取
            cached_value = await cache_get(cache_k)
            if cached_value is not None:
                try:
                    return json.loads(cached_value)
                except json.JSONDecodeError:
                    return cached_value
            
            # 执行原函数
            result = await func(*args, **kwargs)
            
            # 存入缓存
            try:
                cache_value = json.dumps(result, ensure_ascii=False, default=str)
                await cache_set(cache_k, cache_value, ttl)
            except (TypeError, ValueError) as e:
                logger.warning(f"缓存序列化失败: {e}")
            
            return result
        
        @wraps(func)
        def sync_wrapper(*args, **kwargs):
            # 同步函数的缓存（使用内存缓存）
            if key_builder:
                cache_k = key_builder(*args, **kwargs)
            else:
                func_name = func.__name__
                args_str = ":".join(str(a) for a in args)
                kwargs_str = ":".join(f"{k}={v}" for k, v in sorted(kwargs.items()))
                cache_k = cache_key(func_name, args_str, kwargs_str, prefix=prefix)
            
            # 尝试从内存缓存获取
            cached_value = _memory_cache.get(cache_k)
            if cached_value is not None:
                return cached_value
            
            # 执行原函数
            result = func(*args, **kwargs)
            
            # 存入缓存
            _memory_cache.set(cache_k, result, ttl)
            return result
        
        if asyncio.iscoroutinefunction(func):
            return async_wrapper
        return sync_wrapper
    
    return decorator


# ============== 缓存 Key 常量 ==============

class CacheKeys:
    """缓存 Key 前缀常量"""
    USER = "user"
    USER_BY_NAME = "user:name"
    TOKEN = "token"
    BILL_STATS = "bill:stats"
    BILL_LIST = "bill:list"
    CATEGORY_STATS = "category:stats"
    NAME_STATS = "name:stats"
    PROJECT_LIST = "project:list"
    
    @staticmethod
    def user_key(user_id: int) -> str:
        return f"{CacheKeys.USER}:{user_id}"
    
    @staticmethod
    def user_by_name_key(username: str) -> str:
        return f"{CacheKeys.USER_BY_NAME}:{username}"
    
    @staticmethod
    def token_key(token_hash: str) -> str:
        return f"{CacheKeys.TOKEN}:{token_hash}"
    
    @staticmethod
    def bill_stats_key(user_id: int, month: str) -> str:
        return f"{CacheKeys.BILL_STATS}:{user_id}:{month}"
    
    @staticmethod
    def category_stats_key(user_id: int, month: Optional[str] = None) -> str:
        return f"{CacheKeys.CATEGORY_STATS}:{user_id}:{month or 'all'}"
    
    @staticmethod
    def name_stats_key(user_id: int, month: Optional[str] = None) -> str:
        return f"{CacheKeys.NAME_STATS}:{user_id}:{month or 'all'}"
    
    @staticmethod
    def project_list_key(user_id: int) -> str:
        return f"{CacheKeys.PROJECT_LIST}:{user_id}"
    
    @staticmethod
    def invalidate_user_stats_pattern(user_id: int) -> str:
        """用于删除用户所有统计缓存的模式"""
        return f"*:{user_id}:*"


async def invalidate_user_cache(user_id: int):
    """清除用户相关的所有缓存"""
    patterns = [
        f"{CacheKeys.BILL_STATS}:{user_id}:*",
        f"{CacheKeys.CATEGORY_STATS}:{user_id}:*",
        f"{CacheKeys.NAME_STATS}:{user_id}:*",
        f"{CacheKeys.BILL_LIST}:{user_id}:*",
    ]
    for pattern in patterns:
        await cache_delete_pattern(pattern)
    
    # 也删除用户信息缓存和项目缓存
    await cache_delete(CacheKeys.user_key(user_id))
    _memory_cache.delete(CacheKeys.project_list_key(user_id))


async def close_redis():
    """关闭 Redis 连接"""
    global _redis_client
    if _redis_client:
        await _redis_client.close()
        _redis_client = None
        logger.info("Redis 连接已关闭")
