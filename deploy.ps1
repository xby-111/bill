# ==========================================
# Deployment Script - Deploy to Aliyun Server
# ==========================================
# Usage: .\deploy.ps1 -ServerIP "123.56.84.181"
# 部署内容: 后端 API + PWA 前端 + Nginx + PostgreSQL

param(
    [string]$ServerIP = "123.56.84.181",
    [string]$ServerUser = "root",
    [string]$RemotePath = "/root/bill",
    [switch]$SkipWebBuild = $false
)

# Fix encoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Family Ledger System - Deployment" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Target Server: $ServerUser@$ServerIP"
Write-Host ""

# 0. Build Flutter Web (PWA)
if (-not $SkipWebBuild) {
    Write-Host "[*] 0. Building Flutter Web (PWA)..." -ForegroundColor Green
    $flutterAppDir = Join-Path $PSScriptRoot "flutter_app"
    Push-Location $flutterAppDir
    try {
        # 使用空的 API_BASE_URL，让 Nginx 反向代理处理
        flutter build web --release --dart-define=API_BASE_URL= --dart-define=DEBUG=false 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        if (-not (Test-Path (Join-Path $flutterAppDir "build\web\index.html"))) {
            Write-Host "[!] Flutter Web build failed! index.html not found." -ForegroundColor Red
            exit 1
        }
        Write-Host "  [+] Flutter Web build successful" -ForegroundColor Green
    } finally {
        Pop-Location
    }
} else {
    Write-Host "[*] 0. Skipping Flutter Web build (-SkipWebBuild)" -ForegroundColor Yellow
}

# 1. Create temp directory
$tempDir = Join-Path $PSScriptRoot "_deploy_temp"
Write-Host "[*] 1. Preparing local temp directory: $tempDir" -ForegroundColor Green

if (Test-Path $tempDir) {
    Remove-Item -Path $tempDir -Recurse -Force
}
New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

# 2. Copy files
$itemsToCopy = @(
    "config",
    "db", 
    "docker",
    "models",
    "routers",
    "schemas",
    "services",
    "utils",
    # "tests", # Not needed for prod
    "main.py",
    "requirements.txt",
    ".gitignore"
)

foreach ($item in $itemsToCopy) {
    $sourcePath = Join-Path $PSScriptRoot $item
    if (Test-Path $sourcePath) {
        Write-Host "  [+] Copying $item" -ForegroundColor Gray
        Copy-Item -Path $sourcePath -Destination $tempDir -Recurse -Force
        
        # Clean __pycache__
        if (Test-Path (Join-Path $tempDir $item)) {
            Get-ChildItem -Path (Join-Path $tempDir $item) -Recurse -Directory -Filter "__pycache__" | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# Copy Flutter Web build output
$webBuildPath = Join-Path $PSScriptRoot "flutter_app\build\web"
if (Test-Path $webBuildPath) {
    $webDestDir = Join-Path $tempDir "flutter_app\build\web"
    Write-Host "  [+] Copying flutter_app/build/web (PWA)" -ForegroundColor Gray
    New-Item -Path $webDestDir -ItemType Directory -Force | Out-Null
    Copy-Item -Path "$webBuildPath\*" -Destination $webDestDir -Recurse -Force
} else {
    Write-Host "  [!] Warning: flutter_app/build/web not found, PWA will not be deployed" -ForegroundColor Yellow
}

# 3. Create production .env
Write-Host "[*] 2. Generating production config..." -ForegroundColor Green
$prodEnvContent = @"
# =============================================
# Production Configuration
# =============================================

# App Config
DEBUG=false
TZ_OFFSET_HOURS=8

# PostgreSQL Config
DB_TYPE=postgresql
DB_HOST=db
DB_PORT=5432
DB_NAME=family_ledger
DB_USER=bill_user
DB_PASSWORD=QWEqwe111!

# JWT Security
SECRET_KEY=prod-secret-key-$(New-Guid)
TOKEN_EXPIRE_MINUTES=10080

# Logs
LOG_LEVEL=INFO
LOG_FILE=logs/app.log

# CORS
CORS_ORIGINS=*

# Rate Limits
RATE_LIMIT_LOGIN=10
RATE_LIMIT_REGISTER=5
"@
Set-Content -Path (Join-Path $tempDir ".env") -Value $prodEnvContent -Encoding UTF8

# 4. Create production docker-compose.yml
Write-Host "[*] 3. Generating Docker Compose config..." -ForegroundColor Green
$dockerComposeContent = @"
version: '3.8'

services:
  # PostgreSQL Database
  db:
    image: postgres:15-alpine
    container_name: bill_db_prod
    restart: always
    environment:
      POSTGRES_USER: bill_user
      POSTGRES_PASSWORD: QWEqwe111!
      POSTGRES_DB: family_ledger
      POSTGRES_INITDB_ARGS: "-E UTF8 --locale=C"
    volumes:
      - postgres_data_prod:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U bill_user"]
      interval: 10s
      timeout: 5s
      retries: 5
    deploy:
      resources:
        limits:
          memory: 512M

  # FastAPI App
  api:
    build:
      context: .
      dockerfile: docker/Dockerfile
    container_name: bill_api_prod
    restart: always
    depends_on:
      db:
        condition: service_healthy
    expose:
      - "8000"
    env_file:
      - .env
    volumes:
      - ./logs:/app/logs
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '1.0'

  # Nginx - PWA static files + API reverse proxy
  web:
    image: nginx:alpine
    container_name: bill_web_prod
    restart: always
    depends_on:
      - api
    ports:
      - "80:80"
    volumes:
      - ./docker/nginx.conf:/etc/nginx/conf.d/default.conf:ro
      - ./flutter_app/build/web:/usr/share/nginx/html:ro
    deploy:
      resources:
        limits:
          memory: 128M

volumes:
  postgres_data_prod:
    external: false 
"@

Set-Content -Path (Join-Path $tempDir "docker-compose.yml") -Value $dockerComposeContent -Encoding UTF8


# 5. Upload to server
Write-Host ""
Write-Host "[*] 4. Starting code upload..." -ForegroundColor Green
Write-Host "[!] Note: You may need to enter the server password." -ForegroundColor Yellow
Write-Host "-----------------------------------------------------"

# Ensure remote dir exists and clean it (preserve logs)
Write-Host "  [-] Cleaning remote directory (preserving logs)..." -ForegroundColor Gray
ssh "$ServerUser@$ServerIP" "mkdir -p $RemotePath && cd $RemotePath && find . -mindepth 1 -maxdepth 1 ! -name 'logs' -exec rm -rf {} +"

# SCP
# Use Push-Location to ensure we copy all files including hidden ones (like .env)
Push-Location $tempDir
try {
    scp -r . "$ServerUser@${ServerIP}:$RemotePath/"
} finally {
    Pop-Location
}

if ($LASTEXITCODE -ne 0) {
    Write-Host "[!] Upload failed! Check password or network." -ForegroundColor Red
    exit 1
}
Write-Host "[+] Code upload successful" -ForegroundColor Green

# 6. Remote build and start
Write-Host ""
Write-Host "[*] 5. Building and starting service on server..." -ForegroundColor Green
Write-Host "-----------------------------------------------------"

# Use single quotes for remote commands to avoid variable expansion issues
$remoteCommands = @'
# Configure Docker Mirror (Robust method for Ubuntu 22.04)
echo "Configuring Docker..."
mkdir -p /etc/docker

# Create daemon.json using simple echo for maximum compatibility
echo '{"registry-mirrors":["https://docker.m.daocloud.io"]}' > /etc/docker/daemon.json

# Restart Docker and check status
systemctl daemon-reload
if ! systemctl restart docker; then
    echo "[!] Docker restart failed. Trying fallback mirror..."
    echo '{"registry-mirrors":["https://huecker.io"]}' > /etc/docker/daemon.json
    if ! systemctl restart docker; then
        echo "[!] Fallback failed. Removing custom config and reverting to default..."
        rm -f /etc/docker/daemon.json
        systemctl daemon-reload
        systemctl restart docker
    fi
fi

# Wait for Docker to fully restart (max 60s)
echo "Waiting for Docker daemon..."
sleep 5
MAX_RETRIES=30
count=0
until docker info >/dev/null 2>&1; do
    echo "Waiting for Docker... ($((count + 1))/$MAX_RETRIES)"
    sleep 2
    count=$((count + 1))
    if [ $count -ge $MAX_RETRIES ]; then
        echo "[!] Timeout waiting for Docker daemon. Exiting."
        exit 1
    fi
done

cd /root/bill && \
echo "Stopping old containers..." && \
docker-compose down 2>/dev/null || true && \
echo "Starting image build..." && \
docker-compose build api && \
echo "Starting all services (db + api + nginx)..." && \
docker-compose up -d && \
echo "Pruning unused images..." && \
docker image prune -f && \
echo "Waiting for service startup..." && \
sleep 8 && \
docker-compose ps
'@

ssh "$ServerUser@$ServerIP" $remoteCommands

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "======================================" -ForegroundColor Green
    Write-Host "  [+] Deployment Successful!" -ForegroundColor Green
    Write-Host "======================================" -ForegroundColor Green
    Write-Host "PWA URL:      http://xxxby.me/" -ForegroundColor Cyan
    Write-Host "API Docs URL: http://xxxby.me/docs" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "iOS 使用方式: Safari 打开上方链接 -> 分享 -> 添加到主屏幕" -ForegroundColor Yellow
} else {
    Write-Host "[!] Remote execution failed. Check logs." -ForegroundColor Red
}

# 7. Cleanup
Write-Host "[-] Cleaning up local temp files..." -ForegroundColor Gray

# Kill any lingering ssh/scp processes that might lock files
Get-Process ssh, scp -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

# Force garbage collection
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()
Start-Sleep -Seconds 5

try {
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction Stop
} catch {
    Write-Host "[-] PowerShell cleanup failed, trying cmd..." -ForegroundColor Yellow
    cmd /c "rmdir /s /q `"$tempDir`""
}
