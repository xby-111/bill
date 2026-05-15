"""
日志配置模块

提供统一的日志配置，支持控制台和文件输出
"""
import logging
import sys
from logging.handlers import RotatingFileHandler
from pathlib import Path
import os

# 日志级别映射
LOG_LEVELS = {
    "DEBUG": logging.DEBUG,
    "INFO": logging.INFO,
    "WARNING": logging.WARNING,
    "ERROR": logging.ERROR,
    "CRITICAL": logging.CRITICAL,
}


def setup_logging(
    log_level: str = None,
    log_file: str = None,
    log_format: str = None,
):
    """
    配置应用日志
    
    Args:
        log_level: 日志级别 (DEBUG/INFO/WARNING/ERROR/CRITICAL)
        log_file: 日志文件路径 (可选，不传则只输出到控制台)
        log_format: 日志格式字符串
    """
    # 从环境变量读取配置，允许传参覆盖
    level_str = log_level or os.getenv("LOG_LEVEL", "INFO")
    level = LOG_LEVELS.get(level_str.upper(), logging.INFO)
    
    file_path = log_file or os.getenv("LOG_FILE")
    
    format_str = log_format or os.getenv(
        "LOG_FORMAT",
        "%(asctime)s | %(levelname)-8s | %(name)s:%(lineno)d | %(message)s"
    )
    
    # 创建格式化器
    formatter = logging.Formatter(format_str, datefmt="%Y-%m-%d %H:%M:%S")
    
    # 配置根日志器
    root_logger = logging.getLogger()
    root_logger.setLevel(level)
    
    # 清除已有处理器
    root_logger.handlers.clear()
    
    # 控制台处理器
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(level)
    console_handler.setFormatter(formatter)
    root_logger.addHandler(console_handler)
    
    # 文件处理器（如果配置了）
    if file_path:
        log_dir = Path(file_path).parent
        log_dir.mkdir(parents=True, exist_ok=True)
        
        file_handler = RotatingFileHandler(
            file_path,
            maxBytes=10 * 1024 * 1024,  # 10MB
            backupCount=5,
            encoding="utf-8"
        )
        file_handler.setLevel(level)
        file_handler.setFormatter(formatter)
        root_logger.addHandler(file_handler)
    
    # 设置第三方库日志级别（降低噪音）
    logging.getLogger("uvicorn").setLevel(logging.INFO)
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)
    
    # 输出初始化日志
    logger = logging.getLogger(__name__)
    logger.info(f"日志系统初始化完成 | 级别: {level_str} | 文件: {file_path or '无'}")
    
    return root_logger


def get_logger(name: str) -> logging.Logger:
    """获取指定名称的日志器"""
    return logging.getLogger(name)
