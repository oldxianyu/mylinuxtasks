#!/bin/bash
set -e

WG_UI_VERSION="v0.5.2"
WG_UI_PORT="51822"

# 邮箱配置
EMAIL_FROM_ADDRESS="admin@qq.com"
EMAIL_FROM_NAME="admin"
SMTP_HOSTNAME="smtp.exmail.qq.com"
SMTP_PORT="465"
SMTP_USERNAME="admin@qq.com"
SMTP_PASSWORD="Ps1234"
SMTP_AUTH_TYPE="LOGIN"
SMTP_ENCRYPTION="SSL"

# WireGuard 配置
WG_INTERFACE="wg0"
WG_ADDRESS="10.8.0.1/24"
WG_PORT="51820"
WG_NETMASK="10.8.0.0/24"
WG_NETCARD="eth0"  # 公网网卡名，按实际修改

# ==== 选择操作 ====
echo "请选择操作："
echo "1) 部署 WireGuard + UI"
echo "2) 卸载 WireGuard + UI"
read -rp "请输入 1 或 2: " ACTION

if [[ "$ACTION" == "1" ]]; then
    echo "=== 开始部署 ==="

    # ==== 安装依赖 ====
    apt update
    apt install -y wget tree qrencode

    if ! command -v wg >/dev/null 2>&1; then
        echo "=== 安装 WireGuard ==="
        apt install -y wireguard
    fi

    # 生成 WireGuard 密钥
    WG_PRIVATE_KEY=$(wg genkey)
    WG_PUBLIC_KEY=$(echo "$WG_PRIVATE_KEY" | wg pubkey)

    # ==== 下载 WireGuard-UI ====
    echo "=== 下载 WireGuard-UI ==="
    mkdir -p /opt/wireguard-ui
    wget -O /opt/wireguard-ui.tar.gz --max-redirect=20 \
      "https://github.502211.xyz/https://github.com/ngoduykhanh/wireguard-ui/releases/download/${WG_UI_VERSION}/wireguard-ui-${WG_UI_VERSION}-linux-amd64.tar.gz"

    tar -zxvf /opt/wireguard-ui.tar.gz -C /opt/wireguard-ui/

    # ==== 配置 WireGuard-UI 环境变量 ====
    cat <<EOF >/opt/wireguard-ui/.env
BIND_ADDRESS=0.0.0.0:${WG_UI_PORT}
EMAIL_FROM_ADDRESS=${EMAIL_FROM_ADDRESS}
EMAIL_FROM_NAME=${EMAIL_FROM_NAME}
SMTP_HOSTNAME=${SMTP_HOSTNAME}
SMTP_PORT=${SMTP_PORT}
SMTP_USERNAME=${SMTP_USERNAME}
SMTP_PASSWORD=${SMTP_PASSWORD}
SMTP_AUTH_TYPE=${SMTP_AUTH_TYPE}
SMTP_ENCRYPTION=${SMTP_ENCRYPTION}
EOF

    # ==== 生成 wg0.conf ====
    mkdir -p /etc/wireguard
    cat <<EOF >/etc/wireguard/${WG_INTERFACE}.conf
[Interface]
Address = ${WG_ADDRESS}
ListenPort = ${WG_PORT}
PrivateKey = ${WG_PRIVATE_KEY}
MTU = 1420
SaveConfig = true
PostUp = sysctl -w net.ipv4.ip_forward=1; iptables -t nat -A POSTROUTING -s ${WG_NETMASK} -o ${WG_NETCARD} -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -s ${WG_NETMASK} -o ${WG_NETCARD} -j MASQUERADE
Table = auto

# 示例客户端
# [Peer]
# PublicKey = <client_public_key>
# AllowedIPs = 10.8.0.2/32
EOF

    chmod 600 /etc/wireguard/${WG_INTERFACE}.conf

    # ==== 创建 systemd 服务 ====
    cat <<EOF >/etc/systemd/system/wireguard-ui.service
[Unit]
Description=WireGuard UI Daemon
Wants=network-online.target
After=network-online.target

[Service]
User=root
Group=root
Type=simple
WorkingDirectory=/opt/wireguard-ui
EnvironmentFile=/opt/wireguard-ui/.env
ExecStart=/opt/wireguard-ui/wireguard-ui

[Install]
WantedBy=multi-user.target
EOF

    cat <<EOF >/etc/systemd/system/wgui.service
[Unit]
Description=Restart WireGuard
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/systemctl reload wg-quick@${WG_INTERFACE}.service
User=root

[Install]
RequiredBy=wgui.path
EOF

    cat <<EOF >/etc/systemd/system/wgui.path
[Unit]
Description=Watch /etc/wireguard/${WG_INTERFACE}.conf for changes

[Path]
PathModified=/etc/wireguard/${WG_INTERFACE}.conf

[Install]
WantedBy=multi-user.target
EOF

    # ==== 启动服务 ====
    systemctl daemon-reload

    systemctl enable wireguard-ui.service
    systemctl start wireguard-ui.service

    systemctl enable wg-quick@${WG_INTERFACE}.service
    systemctl start wg-quick@${WG_INTERFACE}.service

    systemctl enable wgui.path
    systemctl start wgui.path

    systemctl enable wgui.service
    systemctl start wgui.service

    echo "=== 部署完成 ==="
    echo "访问 UI: http://<服务器IP>:${WG_UI_PORT}"
    echo "WireGuard 配置文件: /etc/wireguard/${WG_INTERFACE}.conf"

elif [[ "$ACTION" == "2" ]]; then
    echo "=== 开始卸载 ==="

    systemctl stop wireguard-ui.service || true
    systemctl disable wireguard-ui.service || true

    systemctl stop wg-quick@${WG_INTERFACE}.service || true
    systemctl disable wg-quick@${WG_INTERFACE}.service || true

    systemctl stop wgui.service || true
    systemctl disable wgui.service || true

    systemctl stop wgui.path || true
    systemctl disable wgui.path || true

    rm -f /etc/systemd/system/wireguard-ui.service
    rm -f /etc/systemd/system/wgui.service
    rm -f /etc/systemd/system/wgui.path
    systemctl daemon-reload

    rm -rf /opt/wireguard-ui
    rm -f /etc/wireguard/${WG_INTERFACE}.conf

    apt remove --purge -y wireguard
    apt autoremove -y

    echo "=== 卸载完成 ==="
else
    echo "输入无效，请输入 1 或 2"
    exit 1
fi
