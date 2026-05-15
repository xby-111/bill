"""
应用配置模块

统一管理所有配置项，支持从环境变量读取
优先级：环境变量 > .env 文件 > 默认值
"""
import os
from functools import lru_cache
from typing import List, Optional
from dotenv import load_dotenv

# 加载 .env 文件
load_dotenv()


class Settings:
    """应用配置类"""
    
    # ==================== 应用信息 ====================
    APP_NAME: str = "个人账单管理系统"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = os.getenv("DEBUG", "false").lower() == "true"
    
    # ==================== JWT 配置 ====================
    SECRET_KEY: str = os.getenv("SECRET_KEY", "dev-secret-key-change-in-production-INSECURE" if os.getenv("DEBUG", "false").lower() == "true" else "")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = int(os.getenv("TOKEN_EXPIRE_MINUTES", "30"))
    
    # ==================== 数据库配置 ====================
    DB_TYPE: str = os.getenv("DB_TYPE", "sqlite")
    DB_HOST: str = os.getenv("DB_HOST", "localhost")
    DB_PORT: str = os.getenv("DB_PORT", "5432")
    DB_USER: str = os.getenv("DB_USER", "")
    DB_PASSWORD: str = os.getenv("DB_PASSWORD", "")
    DB_NAME: str = os.getenv("DB_NAME", "family_ledger")
    SQLITE_PATH: str = os.getenv("SQLITE_PATH", "./data.db")
    
    # 连接池配置
    DB_POOL_SIZE: int = int(os.getenv("DB_POOL_SIZE", "10"))
    DB_MAX_OVERFLOW: int = int(os.getenv("DB_MAX_OVERFLOW", "5"))
    
    # ==================== Redis 缓存配置 ====================
    # Redis URL (可选，不配置时自动降级到内存缓存)
    # 格式: redis://[[username]:[password]@][host][:port][/database]
    REDIS_URL: str = os.getenv("REDIS_URL", "")
    REDIS_MAX_CONNECTIONS: int = int(os.getenv("REDIS_MAX_CONNECTIONS", "20"))
    
    # 缓存 TTL 配置（秒）
    CACHE_TTL_USER: int = int(os.getenv("CACHE_TTL_USER", "300"))       # 用户信息缓存 5 分钟
    CACHE_TTL_STATS: int = int(os.getenv("CACHE_TTL_STATS", "300"))     # 统计数据缓存 5 分钟
    CACHE_TTL_TOKEN: int = int(os.getenv("CACHE_TTL_TOKEN", "300"))     # Token 验证缓存 5 分钟
    
    # ==================== 日志配置 ====================
    LOG_LEVEL: str = os.getenv("LOG_LEVEL", "INFO")
    LOG_FILE: str = os.getenv("LOG_FILE", "")
    LOG_FORMAT: str = os.getenv("LOG_FORMAT", "%(asctime)s | %(levelname)-8s | %(name)s:%(lineno)d | %(message)s")
    
    # ==================== CORS 配置 ====================
    _cors_origins: Optional[List[str]] = None
    
    @property
    def CORS_ORIGINS(self) -> List[str]:
        """解析 CORS 配置，支持逗号分隔的多个域名"""
        if self._cors_origins is None:
            origins = os.getenv("CORS_ORIGINS", "*")
            if origins == "*":
                self._cors_origins = ["*"]
            else:
                self._cors_origins = [origin.strip() for origin in origins.split(",") if origin.strip()]
        return self._cors_origins
    
    # ==================== 速率限制配置 ====================
    RATE_LIMIT_LOGIN: int = int(os.getenv("RATE_LIMIT_LOGIN", "10"))  # 登录每分钟次数
    RATE_LIMIT_REGISTER: int = int(os.getenv("RATE_LIMIT_REGISTER", "5"))  # 注册每分钟次数
    
    # ==================== 时区配置 ====================
    TZ_OFFSET_HOURS: int = int(os.getenv("TZ_OFFSET_HOURS", "8"))  # 默认东八区
    
    @property
    def is_production(self) -> bool:
        """是否为生产环境"""
        return not self.DEBUG and not self.SECRET_KEY.startswith("dev-secret-key")
    
    def validate(self):
        """验证关键配置"""
        errors = []
        
        # 验证 SECRET_KEY
        if not self.SECRET_KEY:
            errors.append("必须设置 SECRET_KEY 环境变量")
        elif self.SECRET_KEY.startswith("dev-secret-key"):
            if not self.DEBUG:
                errors.append("生产环境必须设置安全的 SECRET_KEY")
            else:
                import warnings
                warnings.warn("警告：正在使用不安全的开发密钥，仅限本地测试使用！")
        elif len(self.SECRET_KEY) < 32:
            errors.append("SECRET_KEY 长度必须至少32个字符")
        
        # 验证数据库配置
        if self.DB_TYPE not in ["sqlite", "postgresql", "mysql"]:
            errors.append(f"不支持的数据库类型: {self.DB_TYPE}，支持: sqlite, postgresql, mysql")
        
        if self.DB_TYPE in ["postgresql", "mysql"]:
            if not self.DB_USER:
                errors.append(f"{self.DB_TYPE} 数据库必须设置 DB_USER")
            if not self.DB_PASSWORD:
                errors.append(f"{self.DB_TYPE} 数据库必须设置 DB_PASSWORD")
        
        # 验证日志级别
        valid_log_levels = ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]
        if self.LOG_LEVEL.upper() not in valid_log_levels:
            errors.append(f"无效的日志级别: {self.LOG_LEVEL}，有效值: {valid_log_levels}")
        
        if errors:
            raise ValueError("\n".join(errors))
    
    def to_dict(self) -> dict:
        """导出配置为字典（脱敏后）"""
        return {
            "app_name": self.APP_NAME,
            "version": self.APP_VERSION,
            "debug": self.DEBUG,
            "db_type": self.DB_TYPE,
            "db_host": self.DB_HOST,
            "db_name": self.DB_NAME,
            "log_level": self.LOG_LEVEL,
            "cors_origins": self.CORS_ORIGINS,
            "is_production": self.is_production,
        }


@lru_cache()
def get_settings() -> Settings:
    """获取配置单例"""
    settings = Settings()
    return settings


# 便捷访问
settings = get_settings()
