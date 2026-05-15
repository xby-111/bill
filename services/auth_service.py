from sqlalchemy.orm import Session
from models.user import User
from schemas.user import UserCreate, UserLogin
from utils.exceptions import AppException, UnauthorizedException, ConflictException
import bcrypt
import re
from datetime import timedelta
from utils.jwt import create_access_token
from config import settings


def validate_password_strength(password: str) -> tuple[bool, str]:
    """
    验证密码强度
    
    要求：
    - 至少 6 个字符
    
    Returns:
        (is_valid, error_message)
    """
    # 家庭使用场景，只要求最少6个字符
    if len(password) < 6:
        return False, "密码长度至少为 6 个字符"
    
    return True, ""


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """验证密码"""
    return bcrypt.checkpw(
        plain_password.encode('utf-8'), 
        hashed_password.encode('utf-8')
    )


def get_password_hash(password: str) -> str:
    """生成密码哈希"""
    return bcrypt.hashpw(
        password.encode('utf-8'), 
        bcrypt.gensalt()
    ).decode('utf-8')


def get_user_by_username(db: Session, username: str) -> User | None:
    """根据用户名查询用户"""
    return db.query(User).filter(User.username == username).first()


def get_user_by_email(db: Session, email: str) -> User | None:
    """根据邮箱查询用户"""
    return db.query(User).filter(User.email == email).first()


def create_user(db: Session, user: UserCreate) -> User:
    """
    创建新用户
    
    Args:
        db: 数据库会话
        user: 用户创建数据
        
    Returns:
        创建的用户对象
        
    Raises:
        AppException: 密码强度不足
        ConflictException: 用户名或邮箱已存在
    """
    # 验证密码强度
    is_valid, error_msg = validate_password_strength(user.password)
    if not is_valid:
        raise AppException(
            message=error_msg,
            error_code="WEAK_PASSWORD"
        )
    
    db_user = get_user_by_username(db, username=user.username)
    if db_user:
        raise ConflictException("用户名已存在")
    
    db_user = get_user_by_email(db, email=user.email)
    if db_user:
        raise ConflictException("邮箱已存在")
    
    hashed_password = get_password_hash(user.password)
    db_user = User(
        username=user.username,
        email=user.email,
        hashed_password=hashed_password
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

def authenticate_user(db: Session, user: UserLogin) -> User | bool:
    """
    验证用户凭据
    
    Args:
        db: 数据库会话
        user: 登录信息
        
    Returns:
        验证成功返回用户对象，否则返回 False
    """
    db_user = get_user_by_username(db, username=user.username)
    if not db_user:
        return False
    if not verify_password(user.password, db_user.hashed_password):
        return False
    return db_user


def login_user(db: Session, user: UserLogin) -> dict:
    """
    用户登录
    
    Args:
        db: 数据库会话
        user: 登录信息
        
    Returns:
        包含 access_token 和 token_type 的字典
        
    Raises:
        UnauthorizedException: 用户名或密码错误
    """
    db_user = authenticate_user(db, user)
    if not db_user:
        raise UnauthorizedException("用户名或密码错误")
    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": db_user.username}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}