# 🎯 渐进式部署方案 - 分步实施

> 策略：先部署数据库 → 本地连接测试优化 → 最后部署完整应用

---

## 📋 部署优势

✅ **降低风险**：分步验证，每一步都可以单独测试  
✅ **便于开发**：本地连接云端数据库，边开发边测试  
✅ **节省成本**：数据库可以长期运行，应用可以本地调试  
✅ **易于回滚**：出问题只影响单个组件

---

## 🚀 第一阶段：仅部署数据库到云端

### 1.1 在服务器上创建简化的 docker-compose 文件

SSH 登录服务器后：

```bash
# 登录服务器
ssh root@你的阿里云IP

# 创建项目目录
mkdir -p ~/bill_db
cd ~/bill_db

# 创建数据库专用的 docker-compose 文件
cat > docker-compose.db.yml <<'EOF'
version: '3.8'

services:
  # 仅数据库服务
  db:
    image: postgres:15-alpine
    container_name: bill_db_prod
    restart: always
    ports:
      - "5432:5432"  # 暴露给外部访问
    environment:
      POSTGRES_USER: bill_user
      POSTGRES_PASSWORD: YourStrongPassword123!@#  # 请修改！
      POSTGRES_DB: family_ledger
      POSTGRES_INITDB_ARGS: "-E UTF8 --locale=C"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U bill_user"]
      interval: 10s
      timeout: 5s
      retries: 5
    deploy:
      resources:
        limits:
          memory: 512M

volumes:
  postgres_data:
    driver: local
EOF
```

### 1.2 启动数据库容器

```bash
# 启动
docker-compose -f docker-compose.db.yml up -d

# 查看状态
docker-compose -f docker-compose.db.yml ps

# 查看日志
docker-compose -f docker-compose.db.yml logs -f db
```

### 1.3 配置阿里云安全组

在阿里云控制台添加安全组规则：

| 端口 | 授权对象 | 说明 |
|------|---------|------|
| 5432 | **你的本地IP/32** | PostgreSQL（仅允许你的 IP，注意安全！）|
| 22 | 你的IP/32 | SSH 登录 |

⚠️ **安全警告**：
- **不要开放 5432 给全网**（0.0.0.0/0），极易被攻击
- 使用强密码
- 定期备份数据

### 1.4 测试数据库连接

在服务器上测试：

```bash
# 进入容器测试
docker exec -it bill_db_prod psql -U bill_user -d family_ledger

# 显示数据库列表
\l

# 退出
\q
```

---

## 💻 第二阶段：本地代码连接云端数据库

### 2.1 创建本地开发环境变量文件

在你的本地项目 `d:\Projects\bill` 目录下：

```powershell
# 创建连接云端数据库的配置
New-Item -Path "config\env\.env.cloud" -ItemType File -Force
```

编辑 `.env.cloud` 文件内容：

```env
# ===========================================
# 本地开发 - 连接云端数据库配置
# ===========================================

# 应用配置
DEBUG=true

# 云端 PostgreSQL 数据库配置
DB_TYPE=postgresql
DB_HOST=你的阿里云服务器IP        # 例如: 47.100.123.45
DB_PORT=5432
DB_NAME=family_ledger
DB_USER=bill_user
DB_PASSWORD=YourStrongPassword123!@#  # 与服务器上设置的一致

# JWT 配置（本地开发用临时密钥）
SECRET_KEY=dev-local-cloud-test-key-32-chars-min

# Token 有效期（分钟）
TOKEN_EXPIRE_MINUTES=10080

# 日志配置
LOG_LEVEL=DEBUG

# CORS 配置（允许本地调试）
CORS_ORIGINS=*

# Redis 缓存（暂不配置，使用内存缓存）
# REDIS_URL=

# DeepSeek API（如果需要 AI 功能）
# DEEPSEEK_API_KEY=你的API密钥
```

### 2.2 创建配置切换脚本（可选但推荐）

在项目根目录创建 `switch_env.ps1`：

```powershell
# 环境切换脚本
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("local", "cloud", "example")]
    [string]$env
)

$source = "config\env\.env.$env"
$target = ".env"

if (Test-Path $source) {
    Copy-Item $source $target -Force
    Write-Host "已切换到 $env 环境" -ForegroundColor Green
    Write-Host "配置文件: $source -> $target" -ForegroundColor Cyan
} else {
    Write-Host "配置文件不存在: $source" -ForegroundColor Red
}
```

### 2.3 切换到云端数据库配置

```powershell
# 方法一：使用切换脚本
.\switch_env.ps1 -env cloud

# 方法二：手动复制
Copy-Item config\env\.env.cloud .env -Force
```

### 2.4 测试连接

```powershell
# 启动本地开发服务器
python main.py

# 或使用开发脚本
python start_dev.py
```

检查日志输出，应该看到：
```
INFO | 数据库类型: postgresql
INFO | 数据库已连接: 你的IP:5432/family_ledger
```

浏览器访问：`http://localhost:8000/docs`

---

## 🔧 第三阶段：本地优化开发

现在你可以在本地进行各种优化，数据会实时保存到云端数据库：

### 3.1 推荐的优化方向

#### A. 性能优化
```python
# 1. 添加数据库索引
# 2. 优化 SQL 查询
# 3. 启用查询缓存
```

#### B. 功能优化
```python
# 1. 完善异常处理
# 2. 添加数据验证
# 3. 优化 API 响应格式
```

#### C. 安全优化
```python
# 1. 加强密码验证
# 2. 添加请求签名
# 3. SQL 注入防护
```

### 3.2 本地测试流程

```powershell
# 1. 运行测试
pytest tests/ -v

# 2. 启动开发服务器
python start_dev.py

# 3. 测试 API
# 使用 http://localhost:8000/docs 进行测试

# 4. 查看数据库
# 可以直接查看云端数据库的变化
```

### 3.3 建议的配置文件调整

在进行本地开发时，建议创建 `config\env\.env.local`（纯本地 SQLite）：

```env
DEBUG=true
DB_TYPE=sqlite
SQLITE_PATH=./data_local.db
SECRET_KEY=dev-local-sqlite-test-key-32-chars
```

这样你可以：
- `.env.local` - 完全本地开发（SQLite）
- `.env.cloud` - 连接云端数据库测试
- 随时切换：`.\switch_env.ps1 -env local` 或 `.\switch_env.ps1 -env cloud`

---

## 🚢 第四阶段：部署完整应用到云端

### 4.1 确认优化完成

```powershell
# 1. 本地测试通过
pytest tests/ -v

# 2. 检查代码质量
# 无严重警告和错误

# 3. 准备提交
git add .
git commit -m "优化完成，准备部署"
git push
```

### 4.2 上传代码到服务器

**方法一：使用 Git（推荐）**

```bash
# 在服务器上
cd ~
git clone https://github.com/你的用户名/bill.git
cd bill
```

**方法二：使用 SCP 上传**

在本地 PowerShell：

```powershell
# 压缩项目（排除不需要的文件）
$excludes = @('__pycache__', 'venv', 'data.db', '*.pyc', '.git', 'flutter_app/build')
Compress-Archive -Path "d:\Projects\bill\*" -DestinationPath "d:\bill_deploy.zip" -Force

# 上传到服务器
scp d:\bill_deploy.zip root@你的IP:~/

# 在服务器上解压
ssh root@你的IP
unzip bill_deploy.zip -d ~/bill
cd ~/bill
```

### 4.3 修改部署配置

在服务器上，修改 `docker/docker-compose.prod.yml`：

```bash
cd ~/bill/docker

# 创建生产环境变量
cat > .env <<EOF
# 数据库配置（使用已有的数据库容器）
DB_TYPE=postgresql
DB_HOST=bill_db_prod  # 容器名称
DB_PORT=5432
DB_USER=bill_user
DB_PASSWORD=YourStrongPassword123!@#
DB_NAME=family_ledger

# JWT 密钥（生产环境必须改！）
SECRET_KEY=$(openssl rand -hex 32)

# DeepSeek API
DEEPSEEK_API_KEY=你的密钥

# 生产配置
DEBUG=false
TOKEN_EXPIRE_MINUTES=10080
EOF
```

### 4.4 调整 docker-compose 配置

编辑 `docker/docker-compose.prod.yml`，使用外部已有的数据库：

```yaml
version: '3.8'

services:
  # 后端应用服务
  api:
    build: ..  # 注意路径
    container_name: bill_api_prod
    restart: always
    ports:
      - "8000:8000"
    environment:
      DB_TYPE: postgresql
      DB_HOST: bill_db_prod  # 使用已有的数据库容器名
      DB_PORT: 5432
      DB_USER: ${DB_USER}
      DB_PASSWORD: ${DB_PASSWORD}
      DB_NAME: ${DB_NAME}
      SECRET_KEY: ${SECRET_KEY}
      DEEPSEEK_API_KEY: ${DEEPSEEK_API_KEY}
      DEBUG: "false"
      TOKEN_EXPIRE_MINUTES: 10080
    networks:
      - bill_network
    deploy:
      resources:
        limits:
          memory: 512M

networks:
  bill_network:
    external: true  # 使用外部网络
```

### 4.5 配置 Docker 网络

```bash
# 创建共享网络
docker network create bill_network

# 将现有数据库容器连接到网络
docker network connect bill_network bill_db_prod

# 启动 API 服务
cd ~/bill
docker-compose -f docker/docker-compose.prod.yml up -d --build
```

### 4.6 验证部署

```bash
# 检查容器状态
docker ps

# 查看日志
docker logs -f bill_api_prod

# 健康检查
curl http://localhost:8000/api/v1/monitor/health

# 测试 API
curl http://你的IP:8000/docs
```

---

## 📊 配置对比总结

| 阶段 | 数据库位置 | 应用位置 | 用途 |
|------|----------|---------|------|
| **阶段一** | 云端 | - | 部署数据库 |
| **阶段二** | 云端 | 本地 | 连接测试 |
| **阶段三** | 云端/本地可切换 | 本地 | 开发优化 |
| **阶段四** | 云端 | 云端 | 生产部署 |

---

## 🔐 安全建议

### 生产环境数据库安全加固

部署完应用后，建议修改数据库安全组规则：

```bash
# 1. 移除 5432 端口的公网访问
# 2. 仅允许应用容器内部访问
# 3. 在阿里云安全组中删除 5432 的公网规则
```

调整后的安全组配置：

| 端口 | 授权对象 | 说明 |
|------|---------|------|
| 22 | 你的IP/32 | SSH 登录 |
| 80 | 0.0.0.0/0 | HTTP |
| 443 | 0.0.0.0/0 | HTTPS |
| 8000 | 0.0.0.0/0 | API（或通过 Nginx 反向代理）|
| ~~5432~~ | ~~移除~~ | ~~数据库不再暴露公网~~ |

---

## 🎯 日常开发工作流

### 本地开发流程

```powershell
# 1. 切换到本地数据库
.\switch_env.ps1 -env local

# 2. 开发新功能
code .

# 3. 本地测试
pytest tests/ -v
python start_dev.py

# 4. 切换到云端数据库验证
.\switch_env.ps1 -env cloud
python start_dev.py

# 5. 确认无误后提交
git add .
git commit -m "添加新功能"
git push

# 6. 服务器上更新
ssh root@你的IP
cd ~/bill
git pull
docker-compose -f docker/docker-compose.prod.yml up -d --build
```

---

## 📝 常用命令速查

### 服务器端

```bash
# 查看数据库日志
docker logs -f bill_db_prod

# 查看应用日志
docker logs -f bill_api_prod

# 重启应用
docker restart bill_api_prod

# 进入数据库
docker exec -it bill_db_prod psql -U bill_user -d family_ledger

# 备份数据库
docker exec bill_db_prod pg_dump -U bill_user family_ledger > backup_$(date +%Y%m%d).sql
```

### 本地端

```powershell
# 切换环境
.\switch_env.ps1 -env local   # 本地 SQLite
.\switch_env.ps1 -env cloud   # 云端 PostgreSQL

# 运行测试
pytest tests/ -v

# 启动开发服务器
python start_dev.py
```

---

## ✅ 完成检查清单

- [ ] 阶段一：数据库已部署到云端
- [ ] 阶段一：本地可以连接云端数据库
- [ ] 阶段二：创建了环境切换配置
- [ ] 阶段三：本地优化开发完成
- [ ] 阶段三：代码已提交到 Git
- [ ] 阶段四：应用已部署到云端
- [ ] 阶段四：云端应用可以访问
- [ ] 阶段四：数据库端口已从公网移除
- [ ] 配置了 Nginx 反向代理（可选）
- [ ] 配置了 SSL 证书（可选）
- [ ] 设置了自动备份（可选）

---

## 🆘 问题排查

### 本地无法连接云端数据库

```powershell
# 1. 检查安全组规则是否开放 5432
# 2. 检查服务器防火墙
ssh root@你的IP
sudo ufw status

# 3. 测试端口连通性
Test-NetConnection -ComputerName 你的IP -Port 5432

# 4. 检查数据库容器状态
docker ps | grep bill_db
```

### 应用容器无法连接数据库

```bash
# 1. 检查网络配置
docker network inspect bill_network

# 2. 测试容器间连通性
docker exec bill_api_prod ping bill_db_prod

# 3. 检查环境变量
docker exec bill_api_prod env | grep DB_
```

祝部署顺利！🎉
