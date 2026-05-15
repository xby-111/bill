"""
时区工具模块

统一处理时区转换，确保：
- 数据库存储使用 UTC
- API 返回使用 UTC（带时区标记）
- 前端展示时转换为本地时间

注意：此模块使用 Python 标准库的 timezone
如需更复杂的时区处理，可安装 pytz 或 zoneinfo
"""
from datetime import datetime, timezone, timedelta
from typing import Optional
import os

# 默认本地时区偏移（东八区，北京时间）
# 可通过环境变量 TZ_OFFSET_HOURS 自定义
DEFAULT_TZ_OFFSET_HOURS = int(os.getenv("TZ_OFFSET_HOURS", "8"))


def get_local_timezone() -> timezone:
    """获取本地时区对象"""
    return timezone(timedelta(hours=DEFAULT_TZ_OFFSET_HOURS))


def to_utc(dt: Optional[datetime]) -> Optional[datetime]:
    """
    将任意时区的 datetime 转换为 UTC
    
    Args:
        dt: 输入的 datetime 对象
    
    Returns:
        UTC 时区的 datetime 对象
    
    行为说明：
        - 如果 dt 已有时区信息：转换为 UTC
        - 如果 dt 无时区信息：假设为本地时间，先附加本地时区再转换
    """
    if dt is None:
        return None
    
    if dt.tzinfo is None:
        # 无时区信息，假设为本地时间
        local_tz = get_local_timezone()
        dt = dt.replace(tzinfo=local_tz)
    
    # 转换为 UTC
    return dt.astimezone(timezone.utc)


def from_utc_to_local(dt: Optional[datetime]) -> Optional[datetime]:
    """
    将 UTC 时间转换为本地时间
    
    注意：实际的本地时间转换应该在前端完成
    此函数仅用于后端日志或特殊场景
    
    Args:
        dt: UTC 时区的 datetime 对象
    
    Returns:
        本地时区的 datetime 对象
    """
    if dt is None:
        return None
    
    if dt.tzinfo is None:
        # 如果没有时区信息，假设为 UTC
        dt = dt.replace(tzinfo=timezone.utc)
    
    # 转换为本地时间
    local_tz = get_local_timezone()
    return dt.astimezone(local_tz)


def ensure_utc(dt: Optional[datetime]) -> Optional[datetime]:
    """
    确保 datetime 是 UTC 时区
    
    用于数据库存储前的验证和转换
    
    Args:
        dt: 输入的 datetime 对象
    
    Returns:
        确保是 UTC 的 datetime 对象
    """
    if dt is None:
        return None
    
    if dt.tzinfo is None:
        # 无时区信息，假设为本地时间并转换为 UTC
        local_tz = get_local_timezone()
        dt = dt.replace(tzinfo=local_tz)
        return dt.astimezone(timezone.utc)
    
    # 有时区信息，转换为 UTC
    return dt.astimezone(timezone.utc)


def now_utc() -> datetime:
    """获取当前 UTC 时间（带时区信息）"""
    return datetime.now(timezone.utc)


def now_local() -> datetime:
    """获取当前本地时间（带时区信息）"""
    return datetime.now(get_local_timezone())


def format_datetime(dt: Optional[datetime], fmt: str = "%Y-%m-%d %H:%M:%S") -> str:
    """格式化日期时间为字符串"""
    if dt is None:
        return ""
    return dt.strftime(fmt)


def parse_datetime(dt_str: str, fmt: str = "%Y-%m-%d %H:%M:%S") -> Optional[datetime]:
    """
    解析日期时间字符串
    
    Args:
        dt_str: 日期时间字符串
        fmt: 格式字符串
    
    Returns:
        解析后的 datetime 对象（无时区信息）
    """
    if not dt_str:
        return None
    try:
        return datetime.strptime(dt_str, fmt)
    except ValueError:
        return None