#!/bin/bash

# Shell Options
# e : エラーがあったら直ちにシェルを終了
# u : 未定義変数を使用したときにエラーとする
# o : シェルオプションを有効にする
# pipefail : パイプラインの返り値を最後のエラー終了値にする (エラー終了値がない場合は0を返す)
set -euo pipefail

IP=$(command -v ip)

AWS_CIDR="172.16.0.0/16"

RULE_PREF_100=10010
RULE_PREF_200=10020

case "${PLUTO_VERB}" in
  up-client)
    # --- まず地雷(全通信lookup 220)を除去：冪等 ---
    # ※失敗しても落とさない
    ${IP} rule del pref 220 2>/dev/null || true
    ${IP} rule del lookup 220 2>/dev/null || true

    MARK_OUT="${PLUTO_MARK_OUT%%/*}"
    MARK_IN="${PLUTO_MARK_IN%%/*}"

    case "${MARK_OUT}" in
      100|0x64)
        VTI="vti1"
        LOCAL_INSIDE="169.254.208.48/30"
        TABLE_ID="100"
        RULE_PREF="${RULE_PREF_100}"
        ;;
      200|0xc8)
        VTI="vti2"
        LOCAL_INSIDE="169.254.125.244/30"
        TABLE_ID="200"
        RULE_PREF="${RULE_PREF_200}"
        ;;
      *)
        echo "unexpected PLUTO_MARK_OUT=${PLUTO_MARK_OUT}" >&2
        exit 1
        ;;
    esac

    # VTI 作成（既にあってもOK）
    ${IP} link add "${VTI}" type vti \
      local "${PLUTO_ME}" remote "${PLUTO_PEER}" \
      ikey "${MARK_IN}" okey "${MARK_OUT}" 2>/dev/null || true

    ${IP} addr replace "${LOCAL_INSIDE}" dev "${VTI}"
    ${IP} link set "${VTI}" up

    # VTI でよく入れる調整
    sysctl -w "net.ipv4.conf.${VTI}.disable_policy=1" >/dev/null
    sysctl -w "net.ipv4.conf.${VTI}.rp_filter=0" >/dev/null

    # mark付きだけ別テーブル参照（fwmark selector）
    ${IP} rule add pref "${RULE_PREF}" fwmark "${MARK_OUT}" lookup "${TABLE_ID}" 2>/dev/null || true

    # 172.16/16 を該当VTIへ（table側に入れる）
    ${IP} route replace "${AWS_CIDR}" dev "${VTI}" table "${TABLE_ID}"

    ;;

  down-client)
    # ルールとルートを掃除（冪等）
    ${IP} rule del pref "${RULE_PREF_100}" 2>/dev/null || true
    ${IP} rule del pref "${RULE_PREF_200}" 2>/dev/null || true
    ${IP} route del "${AWS_CIDR}" table 100 2>/dev/null || true
    ${IP} route del "${AWS_CIDR}" table 200 2>/dev/null || true
    ${IP} link del vti1 2>/dev/null || true
    ${IP} link del vti2 2>/dev/null || true
    ;;
esac