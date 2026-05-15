<#
.SYNOPSIS
    环境配置切换脚本

.DESCRIPTION
    快速切换不同的开发环境配置：
    - local: 本地 SQLite 数据库（完全离线）
    - cloud: 连接云端 PostgreSQL 数据库（测试真实环境）
    - example: 示例配置（参考用）

.PARAMETER env
    环境类型：local, cloud, example

.EXAMPLE
    .\switch_env.ps1 -env local
    切换到本地 SQLite 环境

.EXAMPLE
    .\switch_env.ps1 -env cloud
    切换到云端 PostgreSQL 环境
#>

param(
    [Parameter(Mandatory=$true, HelpMessage="选择环境: local, cloud, example")]
    [ValidateSet("local", "cloud", "example")]
    [string]$env
)

# 配置文件路径
$sourceFile = "config\env\.env.$env"
$targetFile = ".env"

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "  🔄 环境配置切换工具" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Cyan

# 检查源文件是否存在
if (-not (Test-Path $sourceFile)) {
    Write-Host "❌ 错误：配置文件不存在" -ForegroundColor Red
    Write-Host "   文件路径: $sourceFile`n" -ForegroundColor Yellow
    exit 1
}

# 备份当前配置（如果存在）
if (Test-Path $targetFile) {
    $backupFile = ".env.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item $targetFile $backupFile -Force
    Write-Host "📦 已备份当前配置: $backupFile" -ForegroundColor Yellow
}

# 复制配置文件
try {
    Copy-Item $sourceFile $targetFile -Force
    Write-Host "✅ 配置切换成功！`n" -ForegroundColor Green
    
    # 显示环境信息
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "📋 当前环境信息" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    
    switch ($env) {
        "local" {
            Write-Host "🏠 环境类型: 本地开发环境" -ForegroundColor Green
            Write-Host "💾 数据库: SQLite (./data/data_local.db)" -ForegroundColor Green
            Write-Host "🌐 网络: 离线模式" -ForegroundColor Green
            Write-Host "📝 用途: 快速开发、离线测试`n" -ForegroundColor Gray
        }
        "cloud" {
            Write-Host "☁️  环境类型: 云端测试环境" -ForegroundColor Blue
            Write-Host "💾 数据库: PostgreSQL (阿里云)" -ForegroundColor Blue
            Write-Host "🌐 网络: 需要连接云服务器" -ForegroundColor Blue
            Write-Host "📝 用途: 真实环境测试`n" -ForegroundColor Gray
            Write-Host "⚠️  注意：请确保已配置正确的服务器 IP 和密码！" -ForegroundColor Yellow
        }
        "example" {
            Write-Host "📖 环境类型: 示例配置" -ForegroundColor Magenta
            Write-Host "📝 用途: 参考配置说明`n" -ForegroundColor Gray
        }
    }
    
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "🚀 下一步操作" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    
    if ($env -eq "cloud") {
        Write-Host "1️⃣  编辑 .env 文件，填入云服务器 IP 和密码" -ForegroundColor White
        Write-Host "2️⃣  确保阿里云安全组已开放 5432 端口" -ForegroundColor White
        Write-Host "3️⃣  启动开发服务器: python start_dev.py" -ForegroundColor White
    } else {
        Write-Host "1️⃣  启动开发服务器: python start_dev.py" -ForegroundColor White
        Write-Host "2️⃣  访问 API 文档: http://localhost:8000/docs" -ForegroundColor White
    }
    
    Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Cyan
    
} catch {
    Write-Host "❌ 复制配置文件失败: $($_.Exception.Message)`n" -ForegroundColor Red
    exit 1
}
