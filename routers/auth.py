from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.orm import Session
from db.database import get_db
from schemas.user import UserCreate, UserLogin, UserResponse, Token
from services.auth_service import create_user, login_user, get_user_by_username
from utils.jwt import verify_token
from utils.rate_limit import check_rate_limit
from utils.cache import CacheKeys, _memory_cache
from fastapi.security import OAuth2PasswordBearer

# 注：认证路由保持同步设计
# 原因：1) 认证是安全关键路径，稳定性优先 2) 访问频率低，无需异步优化 3) 密码哈希是CPU密集操作而非I/O
router = APIRouter(prefix="/auth", tags=["认证"])
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")

# 用户缓存TTL（秒）- 5分钟
USER_CACHE_TTL = 300


def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    """
    获取当前登录用户（带缓存优化）
    
    优化策略：
    1. 先验证 Token（CPU操作，无IO）
    2. 根据用户名从缓存获取用户信息
    3. 缓存未命中时才查询数据库
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="无法验证凭据",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    # 1. 验证 Token
    token_data = verify_token(token, credentials_exception)
    username = token_data.username
    
    # 2. 尝试从缓存获取用户
    cache_key = CacheKeys.user_by_name_key(username)
    cached_user = _memory_cache.get(cache_key)
    if cached_user is not None:
        return cached_user
    
    # 3. 缓存未命中，查询数据库
    user = get_user_by_username(db, username=username)
    if user is None:
        raise credentials_exception
    
    # 4. 缓存用户信息（存储 UserResponse 格式）
    user_response = UserResponse(
        id=user.id,
        username=user.username,
        email=user.email,
        created_at=user.created_at
    )
    _memory_cache.set(cache_key, user_response, USER_CACHE_TTL)
    
    return user_response


@router.post("/register", response_model=UserResponse, summary="用户注册")
def register(
    user: UserCreate, 
    request: Request,
    db: Session = Depends(get_db)
):
    """
    注册新用户
    
    - **username**: 用户名（3-30个字符，支持中文）
    - **email**: 有效的电子邮箱
    - **password**: 密码（至少6个字符）
    """
    # 速率限制：每IP每分钟最多5次注册尝试
    check_rate_limit(request, "register", max_requests=5, window_seconds=60)
    return create_user(db=db, user=user)


@router.post("/login", response_model=Token, summary="用户登录")
def login(
    user: UserLogin, 
    request: Request,
    db: Session = Depends(get_db)
):
    """
    用户登录获取 JWT Token
    
    - **username**: 用户名
    - **password**: 密码
    
    返回 access_token，在后续请求中通过 Authorization: Bearer {token} 使用
    """
    # 速率限制：每IP每分钟最多10次登录尝试
    check_rate_limit(request, "login", max_requests=10, window_seconds=60)
    return login_user(db=db, user=user)


@router.get("/me", response_model=UserResponse, summary="获取当前用户")
def read_users_me(current_user: UserResponse = Depends(get_current_user)):
    """获取当前登录用户的信息"""
    return current_user