#!/bin/bash

WG_CONF_DIR="/etc/wireguard"
WG_SERVER_CONF="$WG_CONF_DIR/wg0.conf"
PORT=41820
IP6=""

# 安装 WireGuard
install_wireguard() {
    if ! command -v wg &>/dev/null || ! command -v wg-quick &>/dev/null; then
        echo "WireGuard 未安装，正在安装..."
        apt update -y
        apt install -y wireguard qrencode
    fi
}

# 获取服务器公网IP
find_public_ip() {
    ip_url1="http://ipv4.icanhazip.com"
    ip_url2="http://ip1.dynupdate.no-ip.com"
    get_public_ip=$(grep -m 1 -oE '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' <<<"$(wget -T 10 -t 1 -4qO- "$ip_url1" || curl -m 10 -4Ls "$ip_url1")")
    if [[ ! $get_public_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        get_public_ip=$(grep -m 1 -oE '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' <<<"$(wget -T 10 -t 1 -4qO- "$ip_url2" || curl -m 10 -4Ls "$ip_url2")")
    fi
    echo "$get_public_ip"
}

# 防火墙规则（保持原样）
create_firewall_rules() {
    if systemctl is-active --quiet firewalld.service; then
        firewall-cmd -q --add-port="$PORT"/udp
        firewall-cmd -q --zone=trusted --add-source=10.7.0.0/24
        firewall-cmd -q --permanent --add-port="$PORT"/udp
        firewall-cmd -q --permanent --zone=trusted --add-source=10.7.0.0/24
        firewall-cmd -q --direct --add-rule ipv4 nat POSTROUTING 0 -s 10.7.0.0/24 ! -d 10.7.0.0/24 -j MASQUERADE
        firewall-cmd -q --permanent --direct --add-rule ipv4 nat POSTROUTING 0 -s 10.7.0.0/24 ! -d 10.7.0.0/24 -j MASQUERADE
    else
        iptables_path=$(command -v iptables)
        echo "[Unit]
After=network-online.target
Wants=network-online.target
[Service]
Type=oneshot
ExecStart=$iptables_path -w 5 -t nat -A POSTROUTING -s 10.7.0.0/24 ! -d 10.7.0.0/24 -j MASQUERADE
ExecStart=$iptables_path -w 5 -I INPUT -p udp --dport $PORT -j ACCEPT
ExecStart=$iptables_path -w 5 -I FORWARD -s 10.7.0.0/24 -j ACCEPT
ExecStart=$iptables_path -w 5 -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
ExecStop=$iptables_path -w 5 -t nat -D POSTROUTING -s 10.7.0.0/24 ! -d 10.7.0.0/24 -j MASQUERADE
ExecStop=$iptables_path -w 5 -D INPUT -p udp --dport $PORT -j ACCEPT
ExecStop=$iptables_path -w 5 -D FORWARD -s 10.7.0.0/24 -j ACCEPT
ExecStop=$iptables_path -w 5 -D FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target" >/etc/systemd/system/wg-iptables.service
        systemctl enable --now wg-iptables.service >/dev/null 2>&1
    fi
}

# -------- 主流程 --------
install_wireguard

SERVER_IP=$(find_public_ip)
echo "服务器公网IP: $SERVER_IP"

mkdir -p "$WG_CONF_DIR"

# 如果服务端配置不存在，生成服务端密钥和配置
if [[ ! -f "$WG_SERVER_CONF" ]]; then
    SERVER_PRIVATE_KEY=$(wg genkey)
    SERVER_PUBLIC_KEY=$(echo "$SERVER_PRIVATE_KEY" | wg pubkey)
    cat > "$WG_SERVER_CONF" <<EOF
[Interface]
Address = 10.7.0.1/24
ListenPort = $PORT
PrivateKey = $SERVER_PRIVATE_KEY
EOF

    echo "启动 WireGuard..."
    systemctl start wg-quick@wg0
else
    # 读取服务端公钥
    SERVER_PRIVATE_KEY=$(grep PrivateKey "$WG_SERVER_CONF" | awk '{print $3}')
    SERVER_PUBLIC_KEY=$(echo "$SERVER_PRIVATE_KEY" | wg pubkey)
fi

# 确定客户端名字和IP
CLIENT_NAME="Client0"
i=0
while [[ -f "$WG_CONF_DIR/${CLIENT_NAME}.conf" ]]; do
    ((i++))
    CLIENT_NAME="Client$i"
done

CLIENT_IP="10.7.0.$((i+2))/32"

# 生成客户端密钥
CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo "$CLIENT_PRIVATE_KEY" | wg pubkey)

# 保存到服务端配置文件
echo -e "\n[Peer]\nPublicKey = $CLIENT_PUBLIC_KEY\nAllowedIPs = $CLIENT_IP" >> "$WG_SERVER_CONF"

# 动态添加客户端到正在运行的 wg0
wg set wg0 peer "$CLIENT_PUBLIC_KEY" allowed-ips "$CLIENT_IP"

# 生成客户端配置文件
CLIENT_CONF="$WG_CONF_DIR/${CLIENT_NAME}.conf"
cat > "$CLIENT_CONF" <<EOF
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_IP
DNS = 1.1.1.1

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_IP:$PORT
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

echo -e "\n======= 复制以下$CLIENT_NAME 配置导入客户端 ======="
cat "$CLIENT_CONF"
echo "客户端配置已保存: $CLIENT_CONF"

# 添加防火墙规则
create_firewall_rules
