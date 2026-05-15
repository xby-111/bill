from datetime import datetime, timedelta
from typing import Optional
import hashlib
from jose import JWTError, jwt
from schemas.user import TokenData
from config import settings
from collections import OrderedDict
from threading import RLock
import time

SECRET_KEY = settings.SECRET_KEY
ALGORITHM = settings.ALGORITHM
ACCESS_TOKEN_EXPIRE_MINUTES = settings.ACCESS_TOKEN_EXPIRE_MINUTES


class TokenCache:
    """
    JWT Token 验证缓存
    
    缓存已验证的 token 结果，避免重复解码
    - 使用 token hash 作为 key（安全性）
    - 设置较短 TTL（5分钟）
    - LRU 淘汰策略
    """
    
    def __init__(self, maxsize: int = 1000, ttl: int = 300):
        self.maxsize = maxsize
        self.ttl = ttl
        self._cache: OrderedDict = OrderedDict()
        self._lock = RLock()
    
    def _hash_token(self, token: str) -> str:
        """对 token 进行哈希（安全性，不存储原始 token）"""
        return hashlib.sha256(token.encode()).hexdigest()[:32]
    
    def get(self, token: str) -> Optional[TokenData]:
        """从缓存获取验证结果"""
        with self._lock:
            key = self._hash_token(token)
            if key not in self._cache:
                return None
            
            data, expire_at = self._cache[key]
            if time.time() > expire_at:
                del self._cache[key]
                return None
            
            # LRU: 移到末尾
            self._cache.move_to_end(key)
            return data
    
    def set(self, token: str, data: TokenData, ttl: Optional[int] = None):
        """缓存验证结果"""
        with self._lock:
            key = self._hash_token(token)
            expire_at = time.time() + (ttl or self.ttl)
            self._cache[key] = (data, expire_at)
            self._cache.move_to_end(key)
            self._cleanup()
    
    def invalidate(self, token: str):
        """使缓存失效"""
        with self._lock:
            key = self._hash_token(token)
            self._cache.pop(key, None)
    
    def clear(self):
        """清空缓存"""
        with self._lock:
            self._cache.clear()
    
    def _cleanup(self):
        """清理过期和超限项"""
        now = time.time()
        # 删除过期项
        expired = [k for k, (_, exp) in self._cache.items() if now > exp]
        for k in expired:
            del self._cache[k]
        # 删除超限项
        while len(self._cache) > self.maxsize:
            self._cache.popitem(last=False)


# 全局 Token 缓存实例
_token_cache = TokenCache(maxsize=2000, ttl=300)


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt


def verify_token(token: str, credentials_exception):
    """
    验证 JWT Token（带缓存优化）
    
    首先检查缓存，命中则直接返回；
    否则进行解码验证，并缓存结果。
    """
    # 1. 检查缓存
    cached = _token_cache.get(token)
    if cached is not None:
        return cached
    
    # 2. 解码验证
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise credentials_exception
        token_data = TokenData(username=username)
    except JWTError:
        raise credentials_exception
    
    # 3. 缓存结果（TTL 不超过 token 有效期）
    exp = payload.get("exp")
    if exp:
        remaining_ttl = int(exp - time.time())
        # 缓存时间取 5分钟 和剩余有效期的较小值
        cache_ttl = min(300, max(0, remaining_ttl))
        if cache_ttl > 0:
            _token_cache.set(token, token_data, cache_ttl)
    
    return token_data


def invalidate_token(token: str):
    """使 token 缓存失效（用于登出等场景）"""
    _token_cache.invalidate(token)


def clear_token_cache():
    """清空 token 缓存（用于密钥轮换等场景）"""
    _token_cache.clear()