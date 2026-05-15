"""
全局异常处理中间件

统一处理 FastAPI 应用中的各类异常，返回规范化的错误响应
"""
from fastapi import Request, status
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from sqlalchemy.exc import SQLAlchemyError, IntegrityError
import logging

logger = logging.getLogger(__name__)


class AppException(Exception):
    """应用自定义异常基类"""
    def __init__(
        self,
        message: str,
        status_code: int = status.HTTP_400_BAD_REQUEST,
        error_code: str = "APP_ERROR"
    ):
        self.message = message
        self.status_code = status_code
        self.error_code = error_code
        super().__init__(message)


class NotFoundException(AppException):
    """资源未找到异常"""
    def __init__(self, resource: str = "资源", resource_id: int = None):
        message = f"{resource}不存在"
        if resource_id:
            message = f"{resource} (ID: {resource_id}) 不存在"
        super().__init__(
            message=message,
            status_code=status.HTTP_404_NOT_FOUND,
            error_code="NOT_FOUND"
        )


class UnauthorizedException(AppException):
    """未授权异常"""
    def __init__(self, message: str = "未授权访问"):
        super().__init__(
            message=message,
            status_code=status.HTTP_401_UNAUTHORIZED,
            error_code="UNAUTHORIZED"
        )


class ForbiddenException(AppException):
    """禁止访问异常"""
    def __init__(self, message: str = "无权限执行此操作"):
        super().__init__(
            message=message,
            status_code=status.HTTP_403_FORBIDDEN,
            error_code="FORBIDDEN"
        )


class ConflictException(AppException):
    """资源冲突异常（如重复创建）"""
    def __init__(self, message: str = "资源已存在"):
        super().__init__(
            message=message,
            status_code=status.HTTP_409_CONFLICT,
            error_code="CONFLICT"
        )


def create_error_response(
    status_code: int,
    message: str,
    error_code: str = None,
    details: dict = None
) -> JSONResponse:
    """创建标准化错误响应"""
    content = {
        "success": False,
        "error": {
            "code": error_code or "ERROR",
            "message": message
        }
    }
    if details:
        content["error"]["details"] = details
    
    return JSONResponse(
        status_code=status_code,
        content=content
    )


async def app_exception_handler(request: Request, exc: AppException):
    """处理应用自定义异常"""
    logger.warning(f"AppException: {exc.error_code} - {exc.message}")
    return create_error_response(
        status_code=exc.status_code,
        message=exc.message,
        error_code=exc.error_code
    )


async def validation_exception_handler(request: Request, exc: RequestValidationError):
    """处理请求参数验证异常"""
    errors = exc.errors()
    messages = []
    # 清理 errors，移除不可序列化的对象
    serializable_errors = []
    for error in errors:
        loc = " -> ".join(str(l) for l in error["loc"])
        messages.append(f"{loc}: {error['msg']}")
        # 只保留可序列化的字段
        serializable_errors.append({
            "type": error.get("type", ""),
            "loc": error.get("loc", []),
            "msg": error.get("msg", ""),
            "input": str(error.get("input", "")) if error.get("input") else None,
        })
    
    logger.warning(f"ValidationError: {messages}")
    return create_error_response(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        message="请求参数验证失败",
        error_code="VALIDATION_ERROR",
        details={"errors": serializable_errors}
    )


async def sqlalchemy_exception_handler(request: Request, exc: SQLAlchemyError):
    """处理数据库异常"""
    logger.error(f"DatabaseError: {str(exc)}")
    
    if isinstance(exc, IntegrityError):
        return create_error_response(
            status_code=status.HTTP_409_CONFLICT,
            message="数据完整性冲突，可能存在重复数据",
            error_code="DATABASE_INTEGRITY_ERROR"
        )
    
    return create_error_response(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        message="数据库操作失败",
        error_code="DATABASE_ERROR"
    )


async def generic_exception_handler(request: Request, exc: Exception):
    """处理未捕获的通用异常"""
    logger.exception(f"UnhandledException: {str(exc)}")
    return create_error_response(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        message="服务器内部错误",
        error_code="INTERNAL_ERROR"
    )


def register_exception_handlers(app):
    """注册所有异常处理器到 FastAPI 应用"""
    app.add_exception_handler(AppException, app_exception_handler)
    app.add_exception_handler(RequestValidationError, validation_exception_handler)
    app.add_exception_handler(SQLAlchemyError, sqlalchemy_exception_handler)
    # 通用异常处理（作为兜底）
    app.add_exception_handler(Exception, generic_exception_handler)
