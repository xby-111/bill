# 使用轻量级 Python 3.11 镜像（更好的性能）
FROM python:3.11-slim

# 设置工作目录
WORKDIR /app

# 防止 Python 生成 .pyc 文件
ENV PYTHONDONTWRITEBYTECODE=1
# 确保日志即时输出
ENV PYTHONUNBUFFERED=1

# 设置时区
ENV TZ=Asia/Shanghai

# 安装系统依赖 (编译 psycopg2 需要)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 复制依赖文件
COPY requirements.txt .

# 安装 Python 依赖
# 使用国内镜像加速
RUN pip install --no-cache-dir -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple

# 复制项目代码
COPY . .

# 创建日志目录和数据目录
RUN mkdir -p logs data

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/api/v1/monitor/health || exit 1

# 暴露端口
EXPOSE 8000

# 启动命令：使用 Gunicorn 管理 Uvicorn workers
# -w 4: 启动 4 个 worker 进程 (根据服务器 CPU 核心数调整，通常 2*核心数 + 1)
# -k uvicorn.workers.UvicornWorker: 使用高性能异步 worker
# --timeout 120: 请求超时时间
# --graceful-timeout 30: 优雅关闭超时
CMD ["gunicorn", "main:app", \
     "-w", "4", \
     "-k", "uvicorn.workers.UvicornWorker", \
     "--bind", "0.0.0.0:8000", \
     "--timeout", "120", \
     "--graceful-timeout", "30", \
     "--access-logfile", "-", \
     "--error-logfile", "-", \
     "--capture-output"]
