#!/bin/bash
# ==========================================
# 一键安装文件下载服务脚本 + 快捷命令
# 功能：
# 1. 创建 /opt/start_file_server.sh
# 2. 设置可执行权限
# 3. 创建快捷命令 wenjian
# 4. 启动 Nginx 文件下载服务（中文支持，wget 下载）
# NAS 文件目录：/vol1/1000/work
# 外网端口：9002
# ==========================================

WORK_DIR="/vol1/1000/work"
SCRIPT_PATH="/opt/start_file_server.sh"
LINK_PATH="/usr/local/bin/wenjian"

# 检查 Docker 是否安装
if ! command -v docker &> /dev/null; then
    echo "Docker 未安装，请先安装 Docker"
    exit 1
fi

# 检查工作目录
if [ ! -d "$WORK_DIR" ]; then
    echo "目录 $WORK_DIR 不存在，正在创建..."
    mkdir -p "$WORK_DIR"
fi

# 设置工作目录权限
chmod -R 755 "$WORK_DIR"

# 创建 start_file_server.sh 脚本
cat > "$SCRIPT_PATH" <<'EOF'
#!/bin/bash
WORK_DIR="/vol1/1000/work"

# 创建临时 nginx 配置
NGINX_CONF=$(mktemp)
cat > "$NGINX_CONF" <<NGCONF
server {
    listen 80;
    server_name localhost;

    charset utf-8;
    location / {
        root /usr/share/nginx/html;
        autoindex on;
        autoindex_exact_size off;
        autoindex_localtime on;
    }
}
NGCONF

# 拉取 nginx 镜像
docker pull nginx:latest

# 删除已有容器
if docker ps -a --format '{{.Names}}' | grep -q "^file-server\$"; then
    docker rm -f file-server
fi

# 启动容器
docker run -d \
    --name file-server \
    --restart unless-stopped \
    -p 9002:80 \
    -v "$WORK_DIR":/usr/share/nginx/html:ro \
    -v "$NGINX_CONF":/etc/nginx/conf.d/default.conf:ro \
    nginx:latest

echo "=========================================="
echo "✅ 文件下载服务已启动！"
echo "访问：http://allin1.cn:9002"
echo "Linux 用户可直接 wget 下载"
echo "=========================================="

# 删除临时配置
rm -f "$NGINX_CONF"
EOF

# 设置脚本可执行
chmod +x "$SCRIPT_PATH"

# 删除旧快捷命令（如果存在）
if [ -L "$LINK_PATH" ]; then
    rm -f "$LINK_PATH"
fi

# 创建软链接
ln -s "$SCRIPT_PATH" "$LINK_PATH"

echo "=========================================="
echo "一键安装完成！"
echo "使用命令启动文件下载服务：wenjian"
echo "NAS 重启后容器会自动启动"
echo "=========================================="
