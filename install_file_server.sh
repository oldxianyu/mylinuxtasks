#!/bin/bash

PORT=9002
SERVER_NAME="file-server"
WORK_DIR="/vol1/1000/work"
TITLE="Xianyu"

NGINX_CONF="/opt/file_server_nginx.conf"

echo "=== 创建文件目录 ==="
mkdir -p "$WORK_DIR"
chmod -R 755 "$WORK_DIR"

echo "=== 写入 nginx 配置 ==="
cat > "$NGINX_CONF" <<EOF
server {
    listen 80;
    autoindex on;
    autoindex_localtime on;

    location / {
        root /usr/share/nginx/html;
        sub_filter 'Index of /' '$TITLE';
        sub_filter_once off;
    }
}
EOF

echo "=== 拉取 nginx 镜像 ==="
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

if [ $? -ne 0 ]; then
    echo "❌ docker run 启动失败，请检查目录权限或配置"
    exit 1
fi

echo
echo "=========================================="
echo "✅ $TITLE 文件站启动成功！"
echo "访问地址：  http://$(hostname -I | awk '{print $1}'):$PORT/"
echo "公网访问：  http://allin1.cn:$PORT/"
echo
echo "下载示例："
echo "wget http://allin1.cn:$PORT/文件名"
echo
echo "容器名：$SERVER_NAME"
echo "端口：$PORT"
echo "目录：$WORK_DIR"
echo "自启策略：unless-stopped"
echo "=========================================="
