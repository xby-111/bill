from pydantic import BaseModel, EmailStr, Field, field_validator
from datetime import datetime
from typing import Optional
import re
from utils.constants import FieldLimits


class UserBase(BaseModel):
    """用户基础模型"""
    username: str = Field(
        ..., 
        min_length=FieldLimits.USERNAME_MIN, 
        max_length=FieldLimits.USERNAME_MAX, 
        description="用户名（3-30个字符）"
    )
    email: EmailStr = Field(..., description="电子邮箱")
    
    @field_validator('username')
    @classmethod
    def validate_username(cls, v):
        if not re.match(r'^[a-zA-Z0-9_\u4e00-\u9fa5]+$', v):
            raise ValueError('用户名只能包含字母、数字、下划线和中文')
        return v


class UserCreate(UserBase):
    """用户注册请求模型"""
    password: str = Field(..., min_length=6, description="密码（至少6个字符）")
    
    @field_validator('password')
    @classmethod
    def validate_password(cls, v):
        # 家庭使用场景，只要求最少6个字符
        if len(v) < 6:
            raise ValueError('密码长度至少为 6 个字符')
        return v
    
    model_config = {
        "json_schema_extra": {
            "example": {
                "username": "zhangsan",
                "email": "zhangsan@example.com",
                "password": "123456"
            }
        }
    }


class UserLogin(BaseModel):
    """用户登录请求模型"""
    username: str = Field(..., description="用户名")
    password: str = Field(..., description="密码")
    
    model_config = {
        "json_schema_extra": {
            "example": {
                "username": "zhangsan",
                "password": "Test@123456"
            }
        }
    }


class UserResponse(UserBase):
    """用户信息响应模型"""
    id: int
    created_at: datetime
    updated_at: Optional[datetime] = None
    
    model_config = {"from_attributes": True}


class Token(BaseModel):
    """JWT Token 响应模型"""
    access_token: str = Field(..., description="访问令牌")
    token_type: str = Field(default="bearer", description="令牌类型")


class TokenData(BaseModel):
    """Token 解析后的数据"""
    username: Optional[str] = None