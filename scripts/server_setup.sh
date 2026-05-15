#!/bin/bash
# 数据库初始化和后端启动脚本

set -e

echo "=== 1. 设置数据库权限 ==="
sudo -u postgres psql -c "ALTER USER bill_user WITH PASSWORD 'QWEqwe111!';"
sudo -u postgres psql -c "ALTER USER bill_user CREATEDB;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE family_ledger TO bill_user;"
sudo -u postgres psql -d family_ledger -c "GRANT ALL ON SCHEMA public TO bill_user;"
echo "数据库权限已设置"

# 确保 pg_hba.conf 允许密码认证
PG_HBA=$(find /etc/postgresql -name pg_hba.conf 2>/dev/null | head -1)
if [ -n "$PG_HBA" ]; then
    if ! grep -q "bill_user" "$PG_HBA"; then
        echo "host    all    bill_user    127.0.0.1/32    md5" >> "$PG_HBA"
        echo "local   all    bill_user                    md5" >> "$PG_HBA"
        echo "已添加 bill_user 到 pg_hba.conf"
    fi
    systemctl reload postgresql
fi

echo "=== 2. 测试数据库连接 ==="
PGPASSWORD='QWEqwe111!' psql -h 127.0.0.1 -U bill_user -d family_ledger -c "SELECT 1 AS connected;"

echo "=== 3. 创建日志目录 ==="
mkdir -p /root/bill/logs

echo "=== 4. 创建 systemd 服务 ==="
cat > /etc/systemd/system/bill-api.service << 'EOF'
[Unit]
Description=Family Ledger API (FastAPI)
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=exec
User=root
WorkingDirectory=/root/bill
EnvironmentFile=/root/bill/.env
ExecStart=/root/bill/venv/bin/gunicorn main:app -w 2 -k uvicorn.workers.UvicornWorker --bind 127.0.0.1:8000 --timeout 120 --graceful-timeout 30 --access-logfile /root/bill/logs/access.log --error-logfile /root/bill/logs/error.log
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable bill-api
systemctl restart bill-api
sleep 3

echo "=== 5. 检查服务状态 ==="
systemctl status bill-api --no-pager -l

echo ""
echo "=== 6. 测试 API ==="
curl -s http://127.0.0.1:8000/api/v1/monitor/health 2>/dev/null || curl -s http://127.0.0.1:8000/docs 2>/dev/null | head -5 || echo "API 尚未响应"

echo ""
echo "=== 完成 ==="
