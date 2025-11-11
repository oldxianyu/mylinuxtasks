#!/bin/bash
# ==========================================
# xianyu下载站 文件服务器启动脚本（替换 Index of /）
# ==========================================

PORT=9002
SERVER_NAME="file-server"
WORK_DIR="/vol1/1000/work"
TITLE="Xianyu"

echo "🔄 检查 docker 是否已安装..."
if ! command -v docker &> /dev/null; then
    echo "❌ 未检测到 Docker，请先安装 Docker。"
    exit 1
fi

echo "✅ Docker 已安装。"

# 删除旧容器
if [ "$(docker ps -aq -f name=$SERVER_NAME)" ]; then
    echo "🧹 删除旧容器..."
    docker rm -f $SERVER_NAME >/dev/null 2>&1
fi

# 创建自定义 nginx 配置
NGINX_CONF="/opt/file_server_nginx.conf"
cat > $NGINX_CONF <<EOF
server {
    listen 80;
    server_name localhost;

    charset utf-8;
    autoindex on;
    autoindex_exact_size off;
    autoindex_localtime on;

    location / {
        root /usr/share/nginx/html;
        sub_filter 'Index of /' '$TITLE';
        sub_filter_once off;
    }

    # 启用 gzip 避免乱码
    gzip off;
}
EOF

echo "📁 目录检查..."
mkdir -p "$WORK_DIR"

echo "🚀 启动容器..."
docker run -d \
  --name $SERVER_NAME \
  -p $PORT:80 \
  -v "$WORK_DIR":/usr/share/nginx/html:ro \
  -v "$NGINX_CONF":/etc/nginx/conf.d/default.conf:ro \
  --restart unless-stopped \
  nginx

echo "✅ $TITLE 已启动成功！"
echo "=========================================="
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
echo "=========================================="
