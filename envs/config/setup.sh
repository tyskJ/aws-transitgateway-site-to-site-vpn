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
${nw_conf}
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
# AddressにはEC2のInsideIPを入れる
cat <<EOF > /etc/systemd/system/xfrm-ifaces.service
${xfrm_conf}
EOF
systemctl enable --now xfrm-ifaces.service

########################################
# Strongswan settings
########################################
TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
CGWPIP=`curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4`
cat <<EOF > /etc/swanctl/conf.d/tgw.conf
connections {

  #####################################################################
  # Tunnel 1 : EC2(このホスト) <-> AWS VPN Endpoint(Outside IP #1)
  #####################################################################
  tgw-tunnel1 {

    # IKE バージョン。AWS Site-to-Site VPN (IKEv2) なので version=2。
    version = 2

    # 証明書は送らない（PSK運用のため）。
    # PSK構成では send_cert=never が一般的。
    send_cert = never

    # IKE SA（フェーズ1）の暗号提案（IKE proposal）
    # 例: aes256 + sha256 + DH group 2048(modp2048)
    proposals = aes256-sha256-modp2048

    # IKE の送信元アドレス（このEC2の実アドレス）
    # ※このIPからUDP/500,4500でAWS outsideへ向けて張る
    # VPN を貼るENIのプライベートIP
    local_addrs  = $CGWPIP

    # IKE の宛先アドレス（AWS の outside IP / tunnel endpoint）
    remote_addrs = ${awsside_tunnel1_gip}

    local {
      # 認証方式。事前共有鍵（PSK）
      auth = psk

      # IKE ID（この装置の識別子）
      # ※local_addrs は "送信元IP"、id は "認証上のID" という別概念。
      id = ${cgw_gip}
    }

    remote {
      # 相手もPSK
      auth = psk

      # 相手の IKE ID
      # 多くのAWS設定では outside IP をそのまま ID として扱うことが多い。
      id = ${awsside_tunnel1_gip}
    }

    children {
      #################################################################
      # CHILD SA（フェーズ2 / ESP）: 実データ(IPv4)を運ぶ SA
      #################################################################
      tgw-child1 {

        # IPsec モード。AWS S2S VPN は通常 tunnel mode
        mode = tunnel

        # トラフィックセレクタ（TS）
        # 0.0.0.0/0 <-> 0.0.0.0/0 にして「どんな通信でもIPsec化できる」前提にする。
        # ※route-based では "どの通信を通すか" はルーティングで決めるため、
        #   TS は広めに取るのが定石（複数SA運用でも if_id で分離できる）。[1](https://repost.aws/knowledge-center/vpn-dynamic-routing-with-microtik-router)
        local_ts  = 0.0.0.0/0
        remote_ts = 0.0.0.0/0

        # ESP（フェーズ2）暗号提案
        # IKE proposals と似ているがこちらは ESP(データ) の暗号。
        esp_proposals = aes256-sha256-modp2048

        #################################################################
        # ★ XFRM interface 連携の肝 ★
        #
        # VTI方式では mark_in/mark_out を使って VTI key と結びつけていたが、
        # XFRM interface 方式では if_id_in/out を使って
        # "XFRM interface ID" と SA/Policy を直接紐づける。[1](https://repost.aws/knowledge-center/vpn-dynamic-routing-with-microtik-router)
        #
        # ここで指定した 101 は、
        #  - systemd unit で作った xfrm101 の if_id=101
        # と一致させる必要がある。
        #
        # ルーティングで xfrm101 に流れたトラフィックだけが
        # if_id=101 に紐づく IPsec SA/Policy にマッチして暗号化される。
        # （逆に interface が無い/IDが違うと動作しない/落ちる）[1](https://repost.aws/knowledge-center/vpn-dynamic-routing-with-microtik-router)
        #################################################################
        if_id_in  = 101
        if_id_out = 101

        #################################################################
        # DPD / 起動動作 / クローズ動作
        #################################################################

        # DPD (Dead Peer Detection) で死活監視して、失敗時は再起動
        dpd_action = restart

        # サービス起動時に CHILD SA を張りに行く（常時UPの思想）
        start_action = start

        # SAが閉じたら再度張り直す（瞬断対策）
        close_action = restart

        #################################################################
        # ライフタイム / リキー
        #################################################################

        # rekey_time：この時間でリキー（鍵更新）を実施
        # AWS側の提案と整合をとるのが基本
        rekey_time = 3600

        # life_time：SAの最大寿命（この時間で期限切れ）
        # リキーにより通常はこの前に更新される
        life_time  = 28800

        #################################################################
        # VTIのときに必要だった updown は削除！
        #
        # updown = /etc/swanctl/scripts/vti-updown.sh  ←不要
        #
        # 理由：
        # - VTI は strongSwan が自動生成しないので、updown で ip tunnel add が必要になりがち。
        # - XFRM interface は OS起動時に常設し、if_id で結びつけるため updown 不要。[1](https://repost.aws/knowledge-center/vpn-dynamic-routing-with-microtik-router)
        #################################################################
      }
    }
  }

  #####################################################################
  # Tunnel 2 : EC2 <-> AWS VPN Endpoint(Outside IP #2)
  #####################################################################
  tgw-tunnel2 {
    version = 2
    send_cert = never
    proposals = aes256-sha256-modp2048

    local_addrs  = $CGWPIP
    remote_addrs = ${awsside_tunnel2_gip}

    local {
      auth = psk
      id = ${cgw_gip}
    }

    remote {
      auth = psk
      id = ${awsside_tunnel2_gip}
    }

    children {
      tgw-child2 {
        mode = tunnel

        # Tunnel 1 と同じ思想（TSは広め。分離は if_id で担保）[1](https://repost.aws/knowledge-center/vpn-dynamic-routing-with-microtik-router)
        local_ts  = 0.0.0.0/0
        remote_ts = 0.0.0.0/0

        esp_proposals = aes256-sha256-modp2048

        #################################################################
        # Tunnel2 は xfrm102 (if_id=102) に紐づけ
        #################################################################
        if_id_in  = 102
        if_id_out = 102

        dpd_action   = restart
        start_action = start
        close_action = restart

        rekey_time = 3600
        life_time  = 28800
      }
    }
  }
}

#####################################################################
# Secrets（PSK）
# - IKE ID の組み合わせ（id-1/id-2）で PSK を選択する
# - id-1 は "自分の IKE ID"（EIP）
# - id-2 は "相手の IKE ID"（AWS outside IP）
#####################################################################
secrets {

  ike-tunnel1 {
    id-1 = ${cgw_gip}
    id-2 = ${awsside_tunnel1_gip}
    secret = ${tunnel1_psk}
  }

  ike-tunnel2 {
    id-1 = ${cgw_gip}
    id-2 = ${awsside_tunnel2_gip}
    secret = ${tunnel2_psk}
  }
}
EOF

cat <<EOF > /etc/strongswan.d/add-charon.conf
${charon_conf}
EOF

systemctl restart strongswan

########################################
# Router Routing
########################################
### テーブル作成
echo "100 tgw" >> /etc/iproute2/rt_tables
### ens6 network
cat <<EOF > /etc/systemd/network/20-ens6.network
${ens6_conf}
EOF
### 反映
networkctl reload
### tgwテーブルルートルールサービス化
cat <<EOF > /etc/systemd/system/tgw-ecmp.service
${rtbrule_conf}
EOF
systemctl enable --now tgw-ecmp.service

########################################
# BGP
########################################
apt install frr -y
sed -i 's/^bgpd=no/bgpd=yes/' /etc/frr/daemons
echo 'watchfrr_enable=yes' >> /etc/frr/daemons
systemctl enable --now frr

cat <<EOF > /etc/frr/frr.conf
${frr_conf}
EOF
chown frr:frr /etc/frr/frr.conf
chmod 640 /etc/frr/frr.conf
systemctl restart frr

########################################
# NAT
########################################
apt install ipset -y
mkdir -p /etc/ipset
cat <<EOF > /etc/ipset/snat_sources.conf
${snat_conf}
EOF
cat <<EOF > /etc/systemd/system/nat-ens5-ipset.service
${ipset_conf}
EOF
systemctl enable --now nat-ens5-ipset.service