# 家庭工时记账系统 - 手动部署步骤

## 📦 方式一：使用自动部署脚本（推荐）

```powershell
# 在本地项目目录执行
.\deploy.ps1
```

此脚本会自动：
- ✅ 排除 venv、__pycache__ 等文件
- ✅ 创建生产环境配置
- ✅ 上传文件到服务器
- ✅ 在服务器上构建和启动服务

---

## 📦 方式二：手动部署（分步骤）

### 步骤1：在本地打包文件

```powershell
# 创建临时目录
$temp = "$env:TEMP\bill_deploy"
New-Item -Path $temp -ItemType Directory -Force

# 复制需要的文件（排除 venv）
Copy-Item -Path "config", "db", "docker", "models", "routers", "schemas", "services", "utils", "tests", "main.py", "requirements.txt", ".gitignore" -Destination $temp -Recurse

# 清理 __pycache__
Get-ChildItem -Path $temp -Recurse -Directory -Filter "__pycache__" | Remove-Item -Recurse -Force

# 打开文件夹
explorer $temp
```

### 步骤2：上传到服务器

```powershell
# 使用 scp 上传
scp -r $temp\* root@39.106.76.85:/root/bill/
```

或者使用 WinSCP、FileZilla 等工具手动上传。

### 步骤3：在服务器上创建配置文件

SSH 登录服务器：
```bash
ssh root@39.106.76.85
cd /root/bill
```

创建 `.env` 文件：
```bash
cat > .env <<'EOF'
DEBUG=false
DB_TYPE=postgresql
DB_HOST=db
DB_PORT=5432
DB_NAME=family_ledger
DB_USER=bill_user
DB_PASSWORD=QWEqwe111!
DB_POOL_SIZE=10
DB_MAX_OVERFLOW=5
SECRET_KEY=prod-secret-key-change-this-to-random-string-minimum-32-chars
TOKEN_EXPIRE_MINUTES=10080
LOG_LEVEL=INFO
LOG_FILE=logs/app.log
CORS_ORIGINS=*
TZ_OFFSET_HOURS=8
EOF
```

创建 `docker-compose.yml`：
```bash
cat > docker-compose.yml <<'EOF'
version: '3.8'

services:
  db:
    image: postgres:15-alpine
    container_name: bill_db_prod
    restart: always
    environment:
      POSTGRES_USER: bill_user
      POSTGRES_PASSWORD: QWEqwe111!
      POSTGRES_DB: family_ledger
    volumes:
      - postgres_data_prod:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U bill_user"]
      interval: 10s
      timeout: 5s
      retries: 5

  api:
    build:
      context: .
      dockerfile: docker/Dockerfile
    container_name: bill_api_prod
    restart: always
    depends_on:
      db:
        condition: service_healthy
    ports:
      - "8000:8000"
    env_file:
      - .env
    volumes:
      - ./logs:/app/logs

volumes:
  postgres_data_prod:
    external: true
EOF
```

### 步骤4：构建和启动

```bash
# 停止旧容器（如果有）
docker-compose down api

# 构建镜像
docker-compose build api

# 启动服务
docker-compose up -d

# 查看状态
docker-compose ps

# 查看日志
docker-compose logs -f api
```

---

## 🔍 部署后检查

### 1. 检查容器状态
```bash
docker-compose ps
```
应该看到 `api` 和 `db` 两个容器都是 `Up` 状态。

### 2. 检查应用日志
```bash
docker-compose logs --tail=50 api
```

### 3. 测试 API
```bash
# 健康检查
curl http://localhost:8000/api/v1/monitor/health

# 访问文档
curl http://localhost:8000/docs
```

### 4. 从本地访问
在浏览器打开：
- http://39.106.76.85:8000/docs
- http://39.106.76.85:8000/api/v1/monitor/health

---

## 🔧 常见问题

### Q1: 端口 8000 无法访问？
**A:** 检查阿里云安全组规则，确保开放了 8000 端口：
```
类型: 自定义 TCP
端口: 8000
授权对象: 0.0.0.0/0
```

### Q2: 数据库连接失败？
**A:** 检查数据库容器状态和数据卷：
```bash
# 检查数据库容器
docker-compose logs db

# 检查数据卷
docker volume ls | grep postgres_data_prod

# 如果数据卷不存在，创建它
docker volume create postgres_data_prod
```

### Q3: 镜像构建失败？
**A:** 检查 Dockerfile 和依赖：
```bash
# 重新构建（不使用缓存）
docker-compose build --no-cache api

# 查看构建日志
docker-compose build api
```

### Q4: 需要更新代码？
**A:** 重新上传代码并重启：
```bash
# 上传新代码后
cd /root/bill
docker-compose down api
docker-compose build api
docker-compose up -d
docker-compose logs -f api
```

---

## 📝 文件清单

需要上传到服务器的文件：
```
/root/bill/
├── config/           # 配置模块
├── db/              # 数据库模块
├── docker/          # Docker 配置
│   ├── Dockerfile
│   └── docker-compose.prod.yml
├── models/          # 数据模型
├── routers/         # 路由
├── schemas/         # Pydantic schemas
├── services/        # 业务逻辑
├── utils/           # 工具函数
├── main.py          # 入口文件
├── requirements.txt # Python 依赖
├── .env            # 环境变量（服务器上创建）
└── docker-compose.yml  # Docker 编排（服务器上创建）
```

**不要上传的文件：**
- ❌ venv/（虚拟环境）
- ❌ __pycache__/（Python 缓存）
- ❌ *.db（本地数据库）
- ❌ data/（本地数据）
- ❌ logs/（本地日志）
- ❌ .vscode/（编辑器配置）
- ❌ flutter_app/（前端代码，单独部署）

---

## 🎯 下一步

1. ✅ 确保服务正常运行
2. 修改 SECRET_KEY 为更安全的随机字符串
3. 配置域名（可选）
4. 配置 HTTPS（可选，推荐使用 Nginx + Let's Encrypt）
5. 设置自动备份数据库
