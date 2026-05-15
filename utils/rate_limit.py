"""
简单的内存速率限制器

用于保护登录、注册等敏感接口，防止暴力破解
"""
import time
from collections import defaultdict
from typing import Tuple
from functools import wraps
from fastapi import HTTPException, status, Request


class RateLimiter:
    """
    简单的内存速率限制器
    
    注意：这是单进程内存实现，不适合多进程/分布式部署
    生产环境建议使用 Redis 实现
    """
    
    def __init__(self):
        # 存储格式: {key: [(timestamp1, count1), (timestamp2, count2), ...]}
        self._requests = defaultdict(list)
        self._cleanup_interval = 60  # 每60秒清理一次过期数据
        self._last_cleanup = time.time()
    
    def _cleanup(self):
        """清理过期的请求记录"""
        now = time.time()
        if now - self._last_cleanup < self._cleanup_interval:
            return
        
        self._last_cleanup = now
        expired_keys = []
        
        for key, requests in self._requests.items():
            # 保留最近5分钟的记录
            self._requests[key] = [r for r in requests if now - r < 300]
            if not self._requests[key]:
                expired_keys.append(key)
        
        for key in expired_keys:
            del self._requests[key]
    
    def is_rate_limited(
        self, 
        key: str, 
        max_requests: int, 
        window_seconds: int
    ) -> Tuple[bool, int]:
        """
        检查是否超过速率限制
        
        Args:
            key: 限制的键（如用户IP或用户名）
            max_requests: 时间窗口内最大请求数
            window_seconds: 时间窗口（秒）
        
        Returns:
            (是否被限制, 剩余可用请求数)
        """
        self._cleanup()
        
        now = time.time()
        window_start = now - window_seconds
        
        # 获取时间窗口内的请求
        recent_requests = [r for r in self._requests[key] if r > window_start]
        self._requests[key] = recent_requests
        
        if len(recent_requests) >= max_requests:
            return True, 0
        
        # 记录本次请求
        self._requests[key].append(now)
        return False, max_requests - len(recent_requests)
    
    def get_retry_after(self, key: str, window_seconds: int) -> int:
        """获取需要等待的秒数"""
        if key not in self._requests or not self._requests[key]:
            return 0
        
        oldest_request = min(self._requests[key])
        wait_time = window_seconds - (time.time() - oldest_request)
        return max(0, int(wait_time))


# 全局速率限制器实例
rate_limiter = RateLimiter()


def get_client_ip(request: Request) -> str:
    """获取客户端真实 IP"""
    # 优先从代理头获取
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        return forwarded.split(",")[0].strip()
    
    real_ip = request.headers.get("X-Real-IP")
    if real_ip:
        return real_ip
    
    return request.client.host if request.client else "unknown"


def rate_limit(max_requests: int = 5, window_seconds: int = 60):
    """
    速率限制装饰器
    
    Args:
        max_requests: 时间窗口内最大请求数
        window_seconds: 时间窗口（秒）
    
    Usage:
        @router.post("/login")
        @rate_limit(max_requests=5, window_seconds=60)
        def login(request: Request, ...):
            ...
    """
    def decorator(func):
        @wraps(func)
        async def async_wrapper(*args, **kwargs):
            # 从 kwargs 中获取 request
            request = kwargs.get('request')
            if not request:
                # 尝试从 args 中查找 Request 对象
                for arg in args:
                    if isinstance(arg, Request):
                        request = arg
                        break
            
            if request:
                client_ip = get_client_ip(request)
                key = f"{func.__name__}:{client_ip}"
                
                is_limited, remaining = rate_limiter.is_rate_limited(
                    key, max_requests, window_seconds
                )
                
                if is_limited:
                    retry_after = rate_limiter.get_retry_after(key, window_seconds)
                    raise HTTPException(
                        status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                        detail=f"请求过于频繁，请在 {retry_after} 秒后重试",
                        headers={"Retry-After": str(retry_after)}
                    )
            
            return await func(*args, **kwargs)
        
        @wraps(func)
        def sync_wrapper(*args, **kwargs):
            request = kwargs.get('request')
            if not request:
                for arg in args:
                    if isinstance(arg, Request):
                        request = arg
                        break
            
            if request:
                client_ip = get_client_ip(request)
                key = f"{func.__name__}:{client_ip}"
                
                is_limited, remaining = rate_limiter.is_rate_limited(
                    key, max_requests, window_seconds
                )
                
                if is_limited:
                    retry_after = rate_limiter.get_retry_after(key, window_seconds)
                    raise HTTPException(
                        status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                        detail=f"请求过于频繁，请在 {retry_after} 秒后重试",
                        headers={"Retry-After": str(retry_after)}
                    )
            
            return func(*args, **kwargs)
        
        # 根据原函数类型返回对应的包装器
        import asyncio
        if asyncio.iscoroutinefunction(func):
            return async_wrapper
        return sync_wrapper
    
    return decorator


def check_rate_limit(
    request: Request, 
    action: str, 
    max_requests: int = 5, 
    window_seconds: int = 60
) -> None:
    """
    检查速率限制（函数版本，用于更灵活的场景）
    
    Args:
        request: FastAPI Request 对象
        action: 操作名称（如 "login", "register"）
        max_requests: 最大请求数
        window_seconds: 时间窗口
    
    Raises:
        HTTPException: 超过限制时抛出 429 错误
    """
    client_ip = get_client_ip(request)
    key = f"{action}:{client_ip}"
    
    is_limited, remaining = rate_limiter.is_rate_limited(
        key, max_requests, window_seconds
    )
    
    if is_limited:
        retry_after = rate_limiter.get_retry_after(key, window_seconds)
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"请求过于频繁，请在 {retry_after} 秒后重试",
            headers={"Retry-After": str(retry_after)}
        )
