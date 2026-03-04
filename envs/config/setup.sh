#!/bin/bash

# Shell Options
# e : エラーがあったら直ちにシェルを終了
# u : 未定義変数を使用したときにエラーとする
# o : シェルオプションを有効にする
# pipefail : パイプラインの返り値を最後のエラー終了値にする (エラー終了値がない場合は0を返す)
set -euo pipefail

# Package Update
dnf update -y

# Timezone
timedatectl set-timezone Asia/Tokyo

# Locale
localectl set-locale LANG=ja_JP.UTF-8
localectl set-keymap jp-OADG109A