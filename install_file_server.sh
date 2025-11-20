#!/bin/bash

# ==========================
# Xianyu 文件下载站安装脚本（纯默认 Index of）
# ==========================

PORT=9002
SERVER_NAME="file-server"
WORK_DIR="/vol2/1000/work"
SHORT_CMD="wenjian"
NGINX_CONF="/opt/file_server_nginx.conf"

echo "=== 检查 Docker ==="
if ! command -v docker &> /dev/null; then
    echo "Docker 未安装，退出"
    exit 1
fi

echo "=== 创建文件目录 ==="
mkdir -p "$WORK_DIR"
chmod -R 755 "$WORK_DIR"

echo "=== 写入 Nginx 配置（使用默认 Index of）==="
cat > "$NGINX_CONF" <<EOF
server {
    listen 80;
    autoindex on;
    autoindex_localtime on;

    location / {
        root /usr/share/nginx/html;
    }
}
EOF

echo "=== 拉取最新 nginx 镜像 ==="
docker pull nginx:latest

echo "=== 删除旧容器（如果有） ==="
docker rm -f "$SERVER_NAME" >/dev/null 2>&1 || true

echo "=== 启动新容器 ==="
docker run -d \
    --name "$SERVER_NAME" \
    -p "$PORT":80 \
    -v "$WORK_DIR":/usr/share/nginx/html:ro \
    -v "$NGINX_CONF":/etc/nginx/conf.d/default.conf:ro \
    --restart unless-stopped \
    nginx:latest

RUN_RESULT=$?

if [ $RUN_RESULT -ne 0 ]; then
    echo "❌ docker run 启动失败，请执行："
    echo "docker logs $SERVER_NAME"
    exit 1
fi

echo "=== 保存脚本为 /opt/start_file_server.sh ==="
if [ "$(readlink -f $0)" != "/opt/start_file_server.sh" ]; then
    cp "$0" /opt/start_file_server.sh
fi
chmod +x /opt/start_file_server.sh

echo "=== 创建快捷命令 $SHORT_CMD ==="
ln -sf /opt/start_file_server.sh /usr/local/bin/$SHORT_CMD

echo
echo "=========================================="
echo "✅ 文件下载站启动成功！"
echo
echo "内网访问： http://$(hostname -I | awk '{print $1}'):$PORT/"
echo "公网访问： http://nas.allin1.cn:$PORT/"
echo
echo "下载命令示例："
echo "wget http://nas.allin1.cn:$PORT/文件名"
echo
echo "容器名：$SERVER_NAME"
echo "端口：$PORT"
echo "目录：$WORK_DIR"
echo "自启策略：unless-stopped"
echo
echo "已经创建快捷命令：$SHORT_CMD"
echo "以后可直接运行： $SHORT_CMD"
echo "=========================================="
