# ==========================================
# Flutter Web (PWA) 构建脚本 (Windows)
# ==========================================
#
# 用法:
#   生产构建:    .\build_web.ps1
#   开发构建:    .\build_web.ps1 -Mode dev
#   自定义 API:  .\build_web.ps1 -Mode prod -ApiUrl "https://api.example.com"
#
# 构建产物输出到: flutter_app\build\web\
# ==========================================

param(
    [ValidateSet("dev", "prod")]
    [string]$Mode = "prod",
    [string]$ApiUrl = ""
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  家庭记账 PWA - Web 构建" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  模式: $Mode"
Write-Host "  API URL: $(if ($ApiUrl) { $ApiUrl } else { '使用默认值' })"
Write-Host "========================================" -ForegroundColor Cyan

$flutterAppDir = Join-Path $PSScriptRoot "..\flutter_app"
Push-Location $flutterAppDir

try {
    # 1. 获取依赖
    Write-Host "[1/3] 获取依赖..." -ForegroundColor Green
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw "flutter pub get 失败" }

    # 2. 构建参数
    $buildArgs = @("build", "web", "--release")

    if ($Mode -eq "prod") {
        if ([string]::IsNullOrEmpty($ApiUrl)) {
            # 生产模式：PWA 使用空的 API_BASE_URL，由 Nginx 反向代理
            $buildArgs += "--dart-define=API_BASE_URL="
        } else {
            $buildArgs += "--dart-define=API_BASE_URL=$ApiUrl"
        }
        $buildArgs += "--dart-define=DEBUG=false"
    } elseif ($Mode -eq "dev") {
        if ([string]::IsNullOrEmpty($ApiUrl)) {
            $ApiUrl = "http://localhost:8000"
        }
        $buildArgs += "--dart-define=API_BASE_URL=$ApiUrl"
        $buildArgs += "--dart-define=DEBUG=true"
    }

    # 3. 执行构建
    Write-Host "[2/3] 编译 Flutter Web..." -ForegroundColor Green
    & flutter @buildArgs
    if ($LASTEXITCODE -ne 0) { throw "flutter build web 失败" }

    # 4. 完成
    Write-Host "[3/3] 构建完成!" -ForegroundColor Green
    Write-Host ""
    Write-Host "构建产物位于: $flutterAppDir\build\web\" -ForegroundColor Yellow
    Write-Host ""

    if ($Mode -eq "prod") {
        Write-Host "部署方式:" -ForegroundColor Cyan
        Write-Host "  1. 将 build\web\ 目录上传到服务器"
        Write-Host "  2. 通过 Nginx 托管静态文件并反向代理 API"
        Write-Host "  3. 或使用 docker-compose.pwa.yml 一键部署"
    }

    Write-Host ""
    Write-Host "========== 构建成功 ==========" -ForegroundColor Green

} catch {
    Write-Host "构建失败: $_" -ForegroundColor Red
    exit 1
} finally {
    Pop-Location
}
