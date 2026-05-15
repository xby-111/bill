"""
性能监控工具模块

提供：
- 请求性能统计
- 数据库查询统计
- 缓存命中率统计
- 慢请求监控
"""
import time
import logging
from typing import Optional, Dict, Any
from collections import defaultdict
from threading import RLock
from functools import wraps
from dataclasses import dataclass
from datetime import datetime

logger = logging.getLogger(__name__)


@dataclass
class RequestMetrics:
    """请求性能指标"""
    total_requests: int = 0
    total_time: float = 0.0
    slow_requests: int = 0  # 超过 1 秒的请求
    errors: int = 0
    
    @property
    def avg_time(self) -> float:
        return self.total_time / self.total_requests if self.total_requests > 0 else 0.0


@dataclass 
class CacheMetrics:
    """缓存命中率指标"""
    hits: int = 0
    misses: int = 0
    
    @property
    def hit_rate(self) -> float:
        total = self.hits + self.misses
        return self.hits / total if total > 0 else 0.0


class PerformanceMonitor:
    """
    性能监控器（单例）
    
    收集和统计各项性能指标
    """
    _instance = None
    _lock = RLock()
    
    def __new__(cls):
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
                    cls._instance._initialized = False
        return cls._instance
    
    def __init__(self):
        if self._initialized:
            return
        
        self._lock = RLock()
        self._request_metrics: Dict[str, RequestMetrics] = defaultdict(RequestMetrics)
        self._cache_metrics = CacheMetrics()
        self._db_query_count = 0
        self._db_query_time = 0.0
        self._slow_queries: list = []
        self._start_time = datetime.utcnow()
        self._initialized = True
    
    def record_request(self, endpoint: str, duration: float, is_error: bool = False):
        """记录请求性能"""
        with self._lock:
            metrics = self._request_metrics[endpoint]
            metrics.total_requests += 1
            metrics.total_time += duration
            if duration > 1.0:
                metrics.slow_requests += 1
            if is_error:
                metrics.errors += 1
    
    def record_cache_hit(self):
        """记录缓存命中"""
        with self._lock:
            self._cache_metrics.hits += 1
    
    def record_cache_miss(self):
        """记录缓存未命中"""
        with self._lock:
            self._cache_metrics.misses += 1
    
    def record_db_query(self, duration: float, sql: Optional[str] = None):
        """记录数据库查询"""
        with self._lock:
            self._db_query_count += 1
            self._db_query_time += duration
            if duration > 0.5 and sql:
                self._slow_queries.append({
                    "time": datetime.utcnow().isoformat(),
                    "duration": duration,
                    "sql": sql[:500]
                })
                # 只保留最近 100 条慢查询
                if len(self._slow_queries) > 100:
                    self._slow_queries.pop(0)
    
    def get_stats(self) -> Dict[str, Any]:
        """获取统计信息"""
        with self._lock:
            uptime = (datetime.utcnow() - self._start_time).total_seconds()
            
            # 请求统计
            total_requests = sum(m.total_requests for m in self._request_metrics.values())
            total_errors = sum(m.errors for m in self._request_metrics.values())
            total_slow = sum(m.slow_requests for m in self._request_metrics.values())
            
            # Top 5 慢端点
            sorted_endpoints = sorted(
                self._request_metrics.items(),
                key=lambda x: x[1].avg_time,
                reverse=True
            )[:5]
            
            return {
                "uptime_seconds": uptime,
                "requests": {
                    "total": total_requests,
                    "errors": total_errors,
                    "slow": total_slow,
                    "error_rate": total_errors / total_requests if total_requests > 0 else 0,
                },
                "cache": {
                    "hits": self._cache_metrics.hits,
                    "misses": self._cache_metrics.misses,
                    "hit_rate": f"{self._cache_metrics.hit_rate:.2%}",
                },
                "database": {
                    "query_count": self._db_query_count,
                    "total_time": self._db_query_time,
                    "avg_time": self._db_query_time / self._db_query_count if self._db_query_count > 0 else 0,
                    "slow_queries": len(self._slow_queries),
                },
                "slowest_endpoints": [
                    {"endpoint": ep, "avg_time": m.avg_time, "count": m.total_requests}
                    for ep, m in sorted_endpoints
                ],
            }
    
    def reset(self):
        """重置统计"""
        with self._lock:
            self._request_metrics.clear()
            self._cache_metrics = CacheMetrics()
            self._db_query_count = 0
            self._db_query_time = 0.0
            self._slow_queries.clear()
            self._start_time = datetime.utcnow()


# 全局监控实例
monitor = PerformanceMonitor()


def timed(func):
    """
    计时装饰器
    
    自动记录函数执行时间
    """
    @wraps(func)
    async def async_wrapper(*args, **kwargs):
        start = time.time()
        try:
            result = await func(*args, **kwargs)
            duration = time.time() - start
            if duration > 1.0:
                logger.warning(f"慢函数 {func.__name__}: {duration:.3f}s")
            return result
        except Exception as e:
            duration = time.time() - start
            logger.error(f"函数异常 {func.__name__}: {e}, 耗时: {duration:.3f}s")
            raise
    
    @wraps(func)
    def sync_wrapper(*args, **kwargs):
        start = time.time()
        try:
            result = func(*args, **kwargs)
            duration = time.time() - start
            if duration > 1.0:
                logger.warning(f"慢函数 {func.__name__}: {duration:.3f}s")
            return result
        except Exception as e:
            duration = time.time() - start
            logger.error(f"函数异常 {func.__name__}: {e}, 耗时: {duration:.3f}s")
            raise
    
    import asyncio
    if asyncio.iscoroutinefunction(func):
        return async_wrapper
    return sync_wrapper
