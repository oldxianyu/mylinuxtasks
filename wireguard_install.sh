#!/usr/bin/env bash
#
# wgset — WireGuard 管理脚本（自动安装 + 管理菜单）
# 用法：
#   sudo wgset       # 第一次安装 WireGuard + 创建第一个客户端 + 进入菜单
#   sudo wgset       # 以后直接进入管理菜单
#

# ------------------------------------------------
# 自动把脚本安装为 wgset 命令（只执行一次）
# ------------------------------------------------
install_wgset_cmd() {
    local TARGET="/usr/local/bin/wgset"
    # 如果 wgset 命令已经存在就不重复安装
    if [ -f "$TARGET" ]; then
        return
    fi
    echo "正在安装 wgset 命令..."
    cp "$0" "$TARGET"
    chmod +x "$TARGET"
    echo "命令已安装完成！以后你可以直接运行： wgset"
}

install_wgset_cmd

echo "
WireGuard 安装脚本
==========================
"

# 如果你希望第一次安装时自动备份 systemd-resolved.conf、配置 DNS，可以保留下面部分
>/etc/systemd/resolved.conf
if [[ ! -f ./wg.txt ]]; then
  echo "1" >./wg.txt
fi

if [[ $(cat ./wg.txt) -eq 1 ]]; then
  systemctl stop systemd-resolved #停用systemd-resolved服务
  ping -c1 www.google.com &>/dev/null
  if [ $? == 0 ]; then # 判断是否能ping通
    mv /etc/systemd/resolved.conf /etc/systemd/resolved.conf.bak
    echo "备份系统DNS配置成功>> 目录/etc/systemd/resolved.conf.bak"
    echo "当前服务器可以正常访问外网>>DNS配置1.1.1.1"
    echo "
      [Resolve]
    DNS=1.1.1.1  #国外DNS
    DNSStubListener=no
" >>/etc/systemd/resolved.conf

    echo "2" >./wg.txt
    ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
    iptables -I INPUT -p UDP --dport 53 -j ACCEPT
  else
    mv /etc/systemd/resolved.conf /etc/systemd/resolved.conf.bak
    echo "备份系统DNS配置成功>> 目录/etc/systemd/resolved.conf.bak"
    echo "当前服务器无法正常访问外网>>DNS配置223.5.5.5"
    echo "
     [Resolve]
    DNS=223.5.5.5  #国内DNS
    DNSStubListener=no
" >>/etc/systemd/resolved.conf
    echo "2" >./wg.txt
    ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
    iptables -I INPUT -p UDP --dport 53 -j ACCEPT
  fi
fi

# 错误退出函数：输出错误信息并退出（状态码1）
exiterr() {
  echo "错误：$1" >&2
  exit 1
}
# 错误退出函数：apt-get安装失败时调用
exiterr2() { exiterr "'apt-get install' 命令执行失败。"; }
# 错误退出函数：yum安装失败时调用
exiterr3() { exiterr "'yum install' 命令执行失败。"; }
# 错误退出函数：zypper安装失败时调用
exiterr4() { exiterr "'zypper install' 命令执行失败。"; }

# 检查IP地址格式（IPv4）
check_ip() {
  IP_REGEX='^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$'
  printf '%s' "$1" | tr -d '\n' | grep -Eq "$IP_REGEX"
}

# 检查私有IP地址格式（IPv4）
check_pvt_ip() {
  IPP_REGEX='^(10|127|172\.(1[6-9]|2[0-9]|3[0-1])|192\.168|169\.254)\.'
  printf '%s' "$1" | tr -d '\n' | grep -Eq "$IPP_REGEX"
}

# 检查DNS域名格式（完全限定域名FQDN）
check_dns_name() {
  FQDN_REGEX='^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'
  printf '%s' "$1" | tr -d '\n' | grep -Eq "$FQDN_REGEX"
}

# 检查是否以root用户身份运行
check_root() {
  if [ "$(id -u)" != 0 ]; then
    exiterr "此安装脚本必须以root用户身份运行。请尝试执行 'sudo wgset'"
  fi
}

# 检查是否使用bash执行脚本（避免Debian用户用sh执行）
check_shell() {
  if readlink /proc/$$/exe | grep -q "dash"; then
    exiterr "此安装脚本需使用 'bash' 执行，不可使用 'sh'。"
  fi
}

# 检查内核版本（排除 OpenVZ 6 的旧内核）
check_kernel() {
  if [[ $(uname -r | cut -d "." -f 1) -eq 2 ]]; then
    exiterr "当前系统运行的内核版本过旧，与本安装脚本不兼容。"
  fi
}

# 检测操作系统类型及版本
check_os() {
  if grep -qs "ubuntu" /etc/os-release; then
    os="ubuntu"
    os_version=$(grep 'VERSION_ID' /etc/os-release | cut -d '"' -f 2 | tr -d '.')
  elif [[ -e /etc/debian_version ]]; then
    os="debian"
    os_version=$(grep -oE '[0-9]+' /etc/debian_version | head -1)
  elif [[ -e /etc/almalinux-release || -e /etc/rocky-release || -e /etc/centos-release ]]; then
    os="centos"
    os_version=$(grep -shoE '[0-9]+' /etc/almalinux-release /etc/rocky-release /etc/centos-release | head -1)
  elif [[ -e /etc/fedora-release ]]; then
    os="fedora"
    os_version=$(grep -oE '[0-9]+' /etc/fedora-release | head -1)
  elif [[ -e /etc/SUSE-brand && "$(head -1 /etc/SUSE-brand)" == "openSUSE" ]]; then
    os="openSUSE"
    os_version=$(tail -1 /etc/SUSE-brand | grep -oE '[0-9\.]+')
  else
    exiterr "此安装脚本似乎运行在不支持的操作系统上。支持 Ubuntu, Debian, CentOS/AlmaLinux/Rocky, Fedora, openSUSE。"
  fi
}

check_os_ver() {
  if [[ "$os" == "ubuntu" && "$os_version" -lt 2004 ]]; then
    exiterr "本安装脚本要求 Ubuntu 20.04 或更高版本。"
  fi
  if [[ "$os" == "debian" && "$os_version" -lt 11 ]]; then
    exiterr "本安装脚本要求 Debian 11 或更高版本。"
  fi
  if [[ "$os" == "centos" && "$os_version" -lt 8 ]]; then
    exiterr "本安装脚本要求 CentOS/AlmaLinux/Rocky 8 或更高版本。"
  fi
}

check_container() {
  if systemd-detect-virt -cq 2>/dev/null; then
    exiterr "当前系统运行在容器环境中，本安装脚本不支持容器。"
  fi
}

set_client_name() {
  client=$(sed 's/[^0-9a-zA-Z_-]/_/g' <<<"$unsanitized_client" | cut -c-15)
}

parse_args() {
  # 保留原来的参数处理逻辑
  while [ "$#" -gt 0 ]; do
    case $1 in
      --auto) auto=1; shift ;;
      --addclient) add_client=1; unsanitized_client="$2"; shift 2 ;;
      --listclients) list_clients=1; shift ;;
      --removeclient) remove_client=1; unsanitized_client="$2"; shift 2 ;;
      --showclientqr) show_client_qr=1; unsanitized_client="$2"; shift 2 ;;
      --uninstall) remove_wg=1; shift ;;
      --serveraddr) server_addr="$2"; shift 2 ;;
      --port) server_port="$2"; shift 2 ;;
      --clientname) first_client_name="$2"; shift 2 ;;
      --dns1) dns1="$2"; shift 2 ;;
      --dns2) dns2="$2"; shift 2 ;;
      -y|--yes) assume_yes=1; shift ;;
      -h|--help) show_usage; ;
      *) show_usage "未知参数：$1"; ;
    esac
  done
}

check_args() {
  # 保留原脚本的参数合法性检查逻辑（如有需要请复制完整）
  :
}

install_wget() {
  if ! hash wget 2>/dev/null && ! hash curl 2>/dev/null; then
    export DEBIAN_FRONTEND=noninteractive
    (apt-get -yqq update && apt-get -yqq install wget >/dev/null) || exiterr2
  fi
}

install_iproute() {
  if ! hash ip 2>/dev/null; then
    if [[ "$os" == "debian" || "$os" == "ubuntu" ]]; then
      export DEBIAN_FRONTEND=noninteractive
      (apt-get -yqq update && apt-get -yqq install iproute2 >/dev/null) || exiterr2
    elif [[ "$os" == "openSUSE" ]]; then
      zypper install -y iproute2 >/dev/null || exiterr4
    else
      yum -y -q install iproute >/dev/null || exiterr3
    fi
  fi
}

show_header() {
  cat <<'EOF'
WireGuard 安装脚本
https://github.com/oldxianyu/mylinuxtasks
EOF
}

show_header2() {
  cat <<'EOF'

欢迎使用 WireGuard 服务器安装脚本！

EOF
}

show_header3() {
  cat <<'EOF'

版权所有 (c) 2025-2025
EOF
}

show_usage() {
  if [ -n "$1" ]; then
    echo "错误：$1" >&2
  fi
  show_header
  show_header3
  cat 1>&2 <<EOF

用法：bash $0 [选项]
...
EOF
  exit 1
}

show_welcome() {
  if [ "$auto" = 0 ]; then
    show_header2
    echo "开始配置前，需要向您确认几个问题。"
    echo "若您接受默认选项，直接按回车键即可。"
  else
    show_header
    echo
    echo "正在使用默认或自定义选项配置 WireGuard。"
  fi
}

show_dns_name_note() {
  cat <<EOF

注意：请确保 DNS 名称 '$1'
      已正确解析到该服务器的 IPv4 地址。
EOF
}

# ... (以下继续保留你脚本后续所有函数及逻辑：detect_ip, check_nat_ip, select_port, enter_first_client_name, update_sysctl, update_rclocal, install_pkgs, create_server_config, create_firewall_rules, new_client, get_export_dir, select_dns, select_client_ip, remove_pkgs, remove_firewall_rules, start_wg_service, show_client_qr_code, menu 相关逻辑 等等) ...

# 我省略后续完全相同的内容，为了展示关键修改 — 你可以直接把原脚本内容完整粘上来
# —————— end of original script content ——————

# -------------------------------
# 管理菜单逻辑
# -------------------------------
wg_manage_menu() {
  while true; do
    echo
    echo "请选择操作："
    echo "   1) 添加新客户端"
    echo "   2) 列出所有已存在的客户端"
    echo "   3) 删除指定客户端"
    echo "   4) 显示指定客户端的 QR 码"
    echo "   5) 卸载 WireGuard"
    echo "   6) 退出"
    read -rp "选择操作 [1-6]：" option
    case "$option" in
      1)
        unsanitized_client=""
        read -rp "请输入新客户端名称：" unsanitized_client
        set_client_name
        add_client=1
        parse_args --addclient "$unsanitized_client"
        # 假设你的脚本有 add_client 分支逻辑，可以调用 main install/addclient 函数
        # 例如 new_client + update 防火墙 + 生成配置 + 显示 QR
        # 这里直接调用原脚本相应逻辑
        # 你需要确保原脚本中 add 客户端的逻辑可以被复用
        exec /usr/local/bin/wgset --addclient "$client"
        ;;
      2)
        list_clients=1
        exec /usr/local/bin/wgset --listclients
        ;;
      3)
        unsanitized_client=""
        read -rp "请输入要删除的客户端名称：" unsanitized_client
        set_client_name
        remove_client=1
        parse_args --removeclient "$client"
        exec /usr/local/bin/wgset --removeclient "$client"
        ;;
      4)
        unsanitized_client=""
        read -rp "请输入要显示 QR 的客户端名称：" unsanitized_client
        set_client_name
        show_client_qr=1
        parse_args --showclientqr "$client"
        exec /usr/local/bin/wgset --showclientqr "$client"
        ;;
      5)
        remove_wg=1
        parse_args --uninstall
        exec /usr/local/bin/wgset --uninstall
        ;;
      6)
        exit 0
        ;;
      *)
        echo "无效选择。请输入 1–6 之间数字。"
        ;;
    esac
  done
}

# -------------------------------
# 主入口
# -------------------------------
main() {
  check_root
  WG_CONF="/etc/wireguard/wg0.conf"

  if [ ! -f "$WG_CONF" ]; then
    # 第一次运行：安装 WireGuard + 创建第一个客户端 + 启动服务
    wgsetup "$@"
  fi

  # 已安装后 / 以后运行：进入管理菜单
  wg_manage_menu
}

# 执行主入口
main "$@"
