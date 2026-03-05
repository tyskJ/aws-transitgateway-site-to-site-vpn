#!/bin/bash

# Shell Options
# e : エラーがあったら直ちにシェルを終了
# u : 未定義変数を使用したときにエラーとする
# o : シェルオプションを有効にする
# pipefail : パイプラインの返り値を最後のエラー終了値にする (エラー終了値がない場合は0を返す)
set -euo pipefail

########################################
# Package Update
########################################
apt update -y

########################################
# TimeZone
########################################
timedatectl set-timezone Asia/Tokyo

########################################
# Locale & Keymap
########################################
localectl set-locale LANG=ja_JP.UTF-8
sed -i 's/^XKBLAYOUT=.*/XKBLAYOUT="jp"/' /etc/default/keyboard
dpkg-reconfigure -f noninteractive keyboard-configuration # 設定再構築
setupcon # ttyへ即時反映

########################################
# Firewall 
########################################
ufw disable

########################################
# Network 
### all: 全インターフェース適用
### default: インターフェース側で未設定の場合に適用
### ip_forward = 1 [あるNICで受信したバケットを別NICへ送出する]
### rp_filter = 0 [複数のNICからパケットが出入りするため Reverse Path Filteringを無効化]
### accept_source_route = 0 [ソースルーティングパケットの受入無効化]
### ip_no_pmtu_disc = 0 [通信遅延をなくすためPath MTU Discoveryを無効化]
### accept_redirects = 0 [セキュリティ上の理由よりICMPリダイレクトパケットの受入無効化]
### send_redirects = 0 [セキュリティ上の理由よりICMPリダイレクトパケットの送出無効化]
########################################
cat <<EOF > /etc/sysctl.d/99-vpn.conf
net.ipv4.ip_forward = 1
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.ip_no_pmtu_disc=0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
EOF
### /etc/sysctl.d/* を適用する
### sysctl -p は /etc/sysctl.conf のみ反映される
sysctl --system

########################################
# Strongswan install
### strongswan-swanctlもインストールされる&サービス自動起動有効化される
########################################
apt install charon-systemd -y
### strongswan-charon strongswan-starter 自動削除
apt autoremove -y

########################################
# XFMR 
########################################
# AddressにはTGWのトンネル定義の値を入れること
cat <<EOF > /etc/systemd/system/xfrm-ifaces.service
[Unit]
Description=Create XFRM interfaces for IPsec (idempotent)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes

# ---- 既存があれば消す（無ければ何もしない）----
ExecStartPre=/bin/sh -c 'ip link show xfrm101 >/dev/null 2>&1 && ip link del xfrm101 || true'
ExecStartPre=/bin/sh -c 'ip link show xfrm102 >/dev/null 2>&1 && ip link del xfrm102 || true'

# ---- xfrm101（if_id=101）----
ExecStart=/usr/sbin/ip link add xfrm101 type xfrm if_id 101
ExecStart=/usr/sbin/ip addr add 169.254.208.48/30 dev xfrm101
ExecStart=/usr/sbin/ip link set xfrm101 up

# ---- xfrm102（if_id=102） ----
ExecStart=/usr/sbin/ip link add xfrm102 type xfrm if_id 102
ExecStart=/usr/sbin/ip addr add 169.254.125.244/30 dev xfrm102
ExecStart=/usr/sbin/ip link set xfrm102 up

# ---- 停止時に削除（無くてもOK）----
ExecStop=/bin/sh -c 'ip link show xfrm101 >/dev/null 2>&1 && ip link del xfrm101 || true'
ExecStop=/bin/sh -c 'ip link show xfrm102 >/dev/null 2>&1 && ip link del xfrm102 || true'

[Install]
WantedBy=multi-user.target
EOF
systemctl enable --now xfrm-ifaces.service

########################################
# BGP
########################################
apt install frr -y
sed -i 's/^bgpd=no/bgpd=yes/' /etc/frr/daemons
systemctl enable --now frr

cat <<EOF > /etc/frr/frr.conf
EOF

########################################
# Strongswan settings
########################################
cat <<EOF > /etc/swanctl/conf.d/tgw.tf
EOF

cat <<EOF > /etc/strongswan.d/add-charon.conf
charon {

    # Install routes into a separate routing table for established IPsec
    # tunnels.
    install_routes = no

    # Install virtual IP addresses.
    install_virtual_ip = no

}
EOF