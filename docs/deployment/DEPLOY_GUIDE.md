# 🚀 阿里云服务器部署指南

> 从零开始，在阿里云服务器上部署家庭工时记账系统

## 📋 准备工作清单

### 1. 服务器配置要求
- **最低配置**：1核2G（适合轻量使用）
- **推荐配置**：2核4G（流畅运行）
- **操作系统**：Ubuntu 22.04 LTS 或 CentOS 8+
- **带宽**：1-5 Mbps
- **存储**：至少 20GB

### 2. 本地准备
- 服务器 IP 地址
- SSH 登录密码或密钥
- 域名（可选，建议购买）

---

## 🔧 第一步：登录并配置服务器

### 1.1 SSH 登录服务器

**Windows 用户（使用 PowerShell）：**
```bash
ssh root@你的服务器IP
# 例如: ssh root@47.100.123.45
```

**首次登录后立即修改密码：**
```bash
passwd
```

### 1.2 创建非 root 用户（安全最佳实践）

```bash
# 创建新用户
adduser deploy
# 给予 sudo 权限
usermod -aG sudo deploy

# 切换到新用户
su - deploy
```

### 1.3 更新系统

```bash
sudo apt update && sudo apt upgrade -y
```

---

## 🐳 第二步：安装 Docker 环境

### 2.1 安装 Docker

```bash
# 卸载旧版本
sudo apt remove docker docker-engine docker.io containerd runc

# 安装依赖
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

# 添加 Docker 官方 GPG 密钥
curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# 添加 Docker 仓库（使用阿里云镜像加速）
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 安装 Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io

# 启动 Docker
sudo systemctl start docker
sudo systemctl enable docker

# 验证安装
sudo docker --version
```

### 2.2 安装 Docker Compose

```bash
# 下载 Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# 设置执行权限
sudo chmod +x /usr/local/bin/docker-compose

# 验证安装
docker-compose --version
```

### 2.3 配置 Docker 镜像加速（阿里云专属）

```bash
# 创建 Docker 配置目录
sudo mkdir -p /etc/docker

# 配置镜像加速器
sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": [
    "https://registry.cn-hangzhou.aliyuncs.com",
    "https://docker.mirrors.ustc.edu.cn"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

# 重启 Docker
sudo systemctl daemon-reload
sudo systemctl restart docker
```

### 2.4 添加当前用户到 Docker 组

```bash
sudo usermod -aG docker $USER
# 退出重新登录后生效
exit
# 重新登录
ssh deploy@你的服务器IP
```

---

## 📦 第三步：部署项目

### 3.1 上传项目代码

**方法一：使用 Git（推荐）**

```bash
# 安装 Git
sudo apt install -y git

# 如果有 GitHub/Gitee 仓库
git clone https://github.com/你的用户名/bill.git ~/bill
cd ~/bill
```

**方法二：使用 SCP 从本地上传**

在你的**本地 Windows PowerShell** 中执行：
```powershell
# 压缩项目（排除不必要的文件）
Compress-Archive -Path "d:\Projects\bill\*" -DestinationPath "d:\bill.zip" -Force

# 上传到服务器
scp d:\bill.zip deploy@你的服务器IP:~/

# 然后在服务器上解压
ssh deploy@你的服务器IP
unzip bill.zip -d ~/bill
cd ~/bill
```

### 3.2 配置环境变量

```bash
cd ~/bill/docker

# 创建环境变量文件
cat > .env <<EOF
# 数据库配置
DB_USER=bill_user
DB_PASSWORD=YourStrongPassword123!@#
DB_NAME=family_ledger

# JWT 密钥（随机生成，非常重要！）
SECRET_KEY=$(openssl rand -hex 32)

# DeepSeek API Key（如果需要 AI 功能）
DEEPSEEK_API_KEY=你的DeepSeek_API_Key

# 其他配置
DEBUG=false
TOKEN_EXPIRE_MINUTES=10080
EOF

# 查看生成的配置（确认无误）
cat .env
```

### 3.3 启动服务

```bash
cd ~/bill

# 构建并启动容器（首次启动需要下载镜像，耐心等待）
docker-compose -f docker/docker-compose.prod.yml up -d --build

# 查看容器状态
docker-compose -f docker/docker-compose.prod.yml ps

# 查看日志
docker-compose -f docker/docker-compose.prod.yml logs -f api
```

### 3.4 初始化数据库

```bash
# 进入 API 容器
docker exec -it bill_api_prod bash

# 运行数据库初始化脚本（如果需要）
python db/init_db.py

# 退出容器
exit
```

---

## 🔐 第四步：配置防火墙和安全组

### 4.1 阿里云控制台配置安全组

登录 [阿里云控制台](https://ecs.console.aliyun.com)：

1. 进入 **云服务器 ECS** → **实例**
2. 点击你的实例 → **安全组** → **配置规则**
3. 添加入方向规则：

| 端口范围 | 授权对象 | 描述 |
|---------|---------|------|
| 22/22 | 你的IP/32 | SSH 登录（限制为你的 IP）|
| 80/80 | 0.0.0.0/0 | HTTP 访问 |
| 443/443 | 0.0.0.0/0 | HTTPS 访问 |
| 8000/8000 | 0.0.0.0/0 | API 服务（临时，建议后期改为内网）|

### 4.2 服务器防火墙配置（Ubuntu）

```bash
# 安装 UFW
sudo apt install -y ufw

# 配置规则
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 8000/tcp

# 启用防火墙
sudo ufw enable
sudo ufw status
```

---

## 🌐 第五步：配置域名和 Nginx（可选但推荐）

### 5.1 安装 Nginx

```bash
sudo apt install -y nginx
sudo systemctl start nginx
sudo systemctl enable nginx
```

### 5.2 配置反向代理

```bash
# 创建站点配置文件
sudo tee /etc/nginx/sites-available/bill <<'EOF'
server {
    listen 80;
    server_name 你的域名.com;  # 替换为你的域名或服务器 IP
    
    client_max_body_size 20M;  # 允许上传大文件
    
    location / {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # 超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
EOF

# 启用站点
sudo ln -s /etc/nginx/sites-available/bill /etc/nginx/sites-enabled/

# 测试配置
sudo nginx -t

# 重启 Nginx
sudo systemctl restart nginx
```

### 5.3 配置 SSL 证书（HTTPS）

```bash
# 安装 Certbot
sudo apt install -y certbot python3-certbot-nginx

# 获取免费 SSL 证书（自动配置 Nginx）
sudo certbot --nginx -d 你的域名.com

# 自动续期测试
sudo certbot renew --dry-run
```

---

## ✅ 第六步：验证部署

### 6.1 测试 API

```bash
# 健康检查
curl http://你的服务器IP:8000/api/v1/monitor/health

# 查看 API 文档
# 浏览器访问: http://你的服务器IP:8000/docs
```

### 6.2 创建测试用户

```bash
# 使用 API 文档或 curl 创建用户
curl -X POST "http://你的服务器IP:8000/api/v1/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "admin123",
    "email": "admin@example.com"
  }'
```

---

## 🔧 第七步：日常运维命令

### 查看服务状态
```bash
cd ~/bill
docker-compose -f docker/docker-compose.prod.yml ps
```

### 查看日志
```bash
# 查看 API 日志
docker-compose -f docker/docker-compose.prod.yml logs -f api

# 查看数据库日志
docker-compose -f docker/docker-compose.prod.yml logs -f db
```

### 重启服务
```bash
docker-compose -f docker/docker-compose.prod.yml restart api
```

### 停止服务
```bash
docker-compose -f docker/docker-compose.prod.yml down
```

### 更新代码
```bash
cd ~/bill
git pull  # 或重新上传代码
docker-compose -f docker/docker-compose.prod.yml up -d --build
```

### 备份数据库
```bash
# 导出数据库
docker exec bill_db_prod pg_dump -U postgres family_ledger > backup_$(date +%Y%m%d).sql

# 恢复数据库
cat backup_20260107.sql | docker exec -i bill_db_prod psql -U postgres family_ledger
```

---

## 📱 第八步：配置 Flutter 客户端

修改 Flutter 应用的 API 地址：

编辑 `flutter_app/lib/config/app_config.dart`：

```dart
class AppConfig {
  // 开发环境
  static const String devBaseUrl = 'http://localhost:8000';
  
  // 生产环境（改为你的服务器地址）
  static const String prodBaseUrl = 'https://你的域名.com';  // 或 http://你的IP:8000
  
  // 当前使用的环境
  static const String baseUrl = prodBaseUrl;  // 切换为生产环境
}
```

然后重新编译 Flutter 应用。

---

## 🚨 常见问题排查

### 1. 容器无法启动
```bash
# 查看详细日志
docker-compose -f docker/docker-compose.prod.yml logs api

# 检查端口占用
sudo netstat -tlnp | grep 8000
```

### 2. 数据库连接失败
```bash
# 检查数据库容器
docker exec -it bill_db_prod psql -U postgres

# 检查环境变量
docker exec bill_api_prod env | grep DB_
```

### 3. 内存不足
```bash
# 查看内存使用
free -h

# 创建 Swap 分区（1核2G 服务器建议）
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### 4. 无法访问 API
```bash
# 检查防火墙
sudo ufw status

# 检查 Nginx 状态
sudo systemctl status nginx

# 检查 Docker 网络
docker network inspect bill_default
```

---

## 🎯 性能优化建议

### 1. 开启 Gzip 压缩（Nginx）
已在代码中配置 GZipMiddleware

### 2. 配置 Redis 缓存（可选）
```bash
# 在 docker-compose.prod.yml 中添加 Redis 服务
docker-compose -f docker/docker-compose.prod.yml up -d redis
```

### 3. 定期清理日志
```bash
# 添加定时任务
crontab -e

# 每周清理一次
0 0 * * 0 find ~/bill/logs -name "*.log" -mtime +7 -delete
```

---

## 📊 监控和告警（可选）

### 使用内置监控接口
```bash
# 健康检查
curl http://localhost:8000/api/v1/monitor/health

# 系统信息
curl http://localhost:8000/api/v1/monitor/system
```

### 配置云监控
在阿里云控制台配置云监控，监控：
- CPU 使用率
- 内存使用率
- 磁盘使用率
- 网络流量

---

## 🎉 完成！

现在你的应用已经成功部署在阿里云服务器上了！

**访问地址：**
- API 文档：`http://你的IP:8000/docs`
- 健康检查：`http://你的IP:8000/api/v1/monitor/health`

**下一步：**
1. 配置域名并启用 HTTPS
2. 设置自动备份
3. 配置日志轮转
4. 编译并发布 Flutter 应用

有任何问题欢迎查看日志或提交 Issue！
