#!/bin/bash
# ==========================================
# Flutter Web (PWA) 构建脚本
# ==========================================
# 
# 用法:
#   本地开发:    ./build_web.sh dev
#   生产构建:    ./build_web.sh prod
#   自定义 API:  ./build_web.sh prod --api-url=https://api.example.com
#
# 构建产物输出到: flutter_app/build/web/
# ==========================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
FLUTTER_APP_DIR="$PROJECT_ROOT/flutter_app"

# 默认参数
MODE="${1:-prod}"
API_URL=""

# 解析参数
for arg in "$@"; do
    case $arg in
        --api-url=*)
            API_URL="${arg#*=}"
            shift
            ;;
    esac
done

echo "========================================"
echo "  家庭记账 PWA - Web 构建"
echo "========================================"
echo "  模式: $MODE"
echo "  API URL: ${API_URL:-使用默认值}"
echo "========================================"

cd "$FLUTTER_APP_DIR"

# 获取依赖
echo "[1/3] 获取依赖..."
flutter pub get

# 构建参数
BUILD_ARGS="--release"

if [ "$MODE" = "prod" ]; then
    # 生产模式：Web/PWA 使用空的 API_BASE_URL，由 Nginx 反向代理
    if [ -z "$API_URL" ]; then
        BUILD_ARGS="$BUILD_ARGS --dart-define=API_BASE_URL="
    else
        BUILD_ARGS="$BUILD_ARGS --dart-define=API_BASE_URL=$API_URL"
    fi
    BUILD_ARGS="$BUILD_ARGS --dart-define=DEBUG=false"
elif [ "$MODE" = "dev" ]; then
    # 开发模式：直连后端
    if [ -z "$API_URL" ]; then
        API_URL="http://localhost:8000"
    fi
    BUILD_ARGS="$BUILD_ARGS --dart-define=API_BASE_URL=$API_URL --dart-define=DEBUG=true"
fi

# 执行构建
echo "[2/3] 编译 Flutter Web..."
flutter build web $BUILD_ARGS

# 确认产物
echo "[3/3] 构建完成!"
echo ""
echo "构建产物位于: $FLUTTER_APP_DIR/build/web/"
echo ""

if [ "$MODE" = "prod" ]; then
    echo "部署方式:"
    echo "  1. 将 build/web/ 目录上传到服务器"
    echo "  2. 通过 Nginx 托管静态文件并反向代理 API"
    echo "  3. 或使用 docker-compose.pwa.yml 一键部署"
fi

echo ""
echo "========== 构建成功 =========="
