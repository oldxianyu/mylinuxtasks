#!/bin/bash
# ==========================================
# Xianyu 文件下载站启动脚本（保持默认 Index of 标题）
# ==========================================

PORT=9002
SERVER_NAME="file-server"
WORK_DIR="/vol1/1000/work"
TITLE="Xianyu"
SHORT_CMD="wenjian"

# 检查 Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker 未安装，请先安装 Docker"
    exit 1
fi

# 创建文件目录
mkdir -p "$WORK_DIR"
chmod -R 755 "$WORK_DIR"

# 创建 Nginx 配置文件
NGINX_CONF="/opt/file_server_nginx.conf"
cat > "$NGINX_CONF" <<EOF
server {
    listen 80;
    server_name localhost;

    charset utf-8;
    autoindex on;
    autoindex_exact_size off;
    autoindex_localtime on;

    location / {
        root /usr/share/nginx/html;
    }

    gzip off;
}
EOF

# 拉取最新 nginx 镜像
docker pull nginx:latest

# 删除旧容器
if docker ps -a --format '{{.Names}}' | grep -q "^$SERVER_NAME\$"; then
    echo "🔄 删除旧容器 $SERVER_NAME..."
    docker rm -f "$SERVER_NAME"
fi

# 启动容器
docker run -d \
    --name "$SERVER_NAME" \
    -p "$PORT":80 \
    -v "$WORK_DIR":/usr/share/nginx/html:ro \
    -v "$NGINX_CONF":/etc/nginx/conf.d/default.conf:ro \
    --restart unless-stopped \
    nginx:latest

# -------------------------------
# 自动赋权和创建快捷命令
# -------------------------------

# 保存自己到 /opt/start_file_server.sh
if [ "$(readlink -f $0)" != "/opt/start_file_server.sh" ]; then
    cp "$0" /opt/start_file_server.sh
fi

# 赋执行权限
chmod +x /opt/start_file_server.sh

# 创建快捷命令
ln -sf /opt/start_file_server.sh /usr/local/bin/$SHORT_CMD

# 输出信息
echo "=========================================="
echo "✅ $TITLE 文件服务器已启动成功！"
echo "访问地址：http://$(hostname -I | awk '{print $1}'):$PORT/"
echo "公网访问：http://allin1.cn:$PORT/"
echo
echo "Linux 用户可直接下载："
echo "wget http://allin1.cn:$PORT/文件名"
echo
echo "容器名：$SERVER_NAME"
echo "端口：$PORT"
echo "目录：$WORK_DIR"
echo "自启策略：unless-stopped（开机自动运行）"
echo
echo "快捷命令已创建：$SHORT_CMD"
echo "以后可直接运行：$SHORT_CMD"
echo "=========================================="
