#!/bin/bash
# ==========================================
# 快速部署脚本 - 在服务器上执行
# ==========================================
# 在服务器上执行此脚本
# 使用方法：bash deploy_on_server.sh

set -e

SERVER_DIR="/root/bill"
cd $SERVER_DIR

echo "======================================="
echo "  停止现有服务"
echo "======================================="
docker-compose down api 2>/dev/null || echo "没有运行中的 api 容器"

echo ""
echo "======================================="
echo "  构建新镜像"
echo "======================================="
docker-compose build api --no-cache

echo ""
echo "======================================="
echo "  启动服务"
echo "======================================="
docker-compose up -d

echo ""
echo "等待服务启动..."
sleep 5

echo ""
echo "======================================="
echo "  检查容器状态"
echo "======================================="
docker-compose ps

echo ""
echo "======================================="
echo "  应用日志（最后30行）"
echo "======================================="
docker-compose logs --tail=30 api

echo ""
echo "✅ 部署完成！"
echo ""
echo "📝 访问地址："
echo "  - API: http://39.106.76.85:8000"
echo "  - 文档: http://39.106.76.85:8000/docs"
echo "  - 健康检查: http://39.106.76.85:8000/api/v1/monitor/health"
echo ""
echo "📝 常用命令："
echo "  查看日志: docker-compose logs -f api"
echo "  重启服务: docker-compose restart api"
echo "  停止服务: docker-compose down"
echo ""
