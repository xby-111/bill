"""
应用常量定义模块

统一管理应用中使用的常量值，避免魔法字符串
"""
from enum import Enum
from typing import List


class BillType(str, Enum):
    """账单类型枚举"""
    INCOME = "income"
    EXPENSE = "expense"
    
    @classmethod
    def values(cls) -> List[str]:
        """获取所有有效值"""
        return [item.value for item in cls]


class OperationType(str, Enum):
    """操作类型枚举（用于历史记录）"""
    UPDATE = "UPDATE"
    DELETE = "DELETE"
    CREATE = "CREATE"


class DatabaseType(str, Enum):
    """数据库类型枚举"""
    SQLITE = "sqlite"
    POSTGRESQL = "postgresql"
    MYSQL = "mysql"


class LogLevel(str, Enum):
    """日志级别枚举"""
    DEBUG = "DEBUG"
    INFO = "INFO"
    WARNING = "WARNING"
    ERROR = "ERROR"
    CRITICAL = "CRITICAL"


# 默认分类列表
DEFAULT_CATEGORIES = [
    "人工",
    "材料",
    "餐饮",
    "交通",
    "住宿",
    "设备",
    "其他",
]


# 支付方式列表
PAYMENT_METHODS = [
    "现金",
    "微信",
    "支付宝",
    "银行转账",
    "其他",
]


# 分页相关常量
class Pagination:
    """分页常量"""
    DEFAULT_SKIP = 0
    DEFAULT_LIMIT = 100
    MAX_LIMIT = 500
    MIN_LIMIT = 1


# 字段长度限制
class FieldLimits:
    """字段长度限制"""
    USERNAME_MIN = 3
    USERNAME_MAX = 30
    PASSWORD_MIN = 6
    BILL_NAME_MAX = 200
    CATEGORY_MAX = 50
    NOTE_MAX = 500
    PROJECT_NAME_MAX = 100
    PROJECT_DESC_MAX = 500
    PAY_METHOD_MAX = 30


# 时间相关常量
class TimeConstants:
    """时间相关常量"""
    DEFAULT_TZ_OFFSET_HOURS = 8  # 东八区
    MAX_WORK_HOURS_PER_DAY = 24
    MIN_WORK_HOURS = 0
