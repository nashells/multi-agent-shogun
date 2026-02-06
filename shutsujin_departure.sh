#!/bin/bash
# 🏯 multi-agent-shogun 出陣スクリプト（毎日の起動用）
# Daily Deployment Script for Multi-Agent Orchestration System
# Agent Teams 版
#
# 使用方法:
#   ./shutsujin_departure.sh           # 将軍起動（Agent Teams がチームを構成）
#   ./shutsujin_departure.sh -h        # ヘルプ表示

set -e

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 言語設定を読み取り（デフォルト: ja）
LANG_SETTING="ja"
if [ -f "./config/settings.yaml" ]; then
    LANG_SETTING=$(grep "^language:" ./config/settings.yaml 2>/dev/null | awk '{print $2}' || echo "ja")
fi

# 足軽数を読み取り（デフォルト: 3）
ASHIGARU_COUNT=3
if [ -f "./config/settings.yaml" ]; then
    ASHIGARU_COUNT=$(grep "^ashigaru_count:" ./config/settings.yaml 2>/dev/null | awk '{print $2}' || echo "3")
    ASHIGARU_COUNT=${ASHIGARU_COUNT:-3}
fi

# 色付きログ関数（戦国風）
log_info() {
    echo -e "\033[1;33m【報】\033[0m $1"
}

log_success() {
    echo -e "\033[1;32m【成】\033[0m $1"
}

log_war() {
    echo -e "\033[1;31m【戦】\033[0m $1"
}

# ═══════════════════════════════════════════════════════════════════════════════
# オプション解析
# ═══════════════════════════════════════════════════════════════════════════════

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            echo ""
            echo "🏯 multi-agent-shogun 出陣スクリプト（Agent Teams 版）"
            echo ""
            echo "使用方法: ./shutsujin_departure.sh [オプション]"
            echo ""
            echo "オプション:"
            echo "  -h, --help        このヘルプを表示"
            echo ""
            echo "例:"
            echo "  ./shutsujin_departure.sh      # 将軍を起動（Agent Teams がチームを構成）"
            echo ""
            echo "Agent Teams がエージェントの tmux セッション管理を自動で行います。"
            echo ""
            exit 0
            ;;
        *)
            echo "不明なオプション: $1"
            echo "./shutsujin_departure.sh -h でヘルプを表示"
            exit 1
            ;;
    esac
done

# ═══════════════════════════════════════════════════════════════════════════════
# 出陣バナー表示（CC0ライセンスASCIIアート使用）
# ───────────────────────────────────────────────────────────────────────────────
# 【著作権・ライセンス表示】
# 忍者ASCIIアート: syntax-samurai/ryu - CC0 1.0 Universal (Public Domain)
# 出典: https://github.com/syntax-samurai/ryu
# "all files and scripts in this repo are released CC0 / kopimi!"
# ═══════════════════════════════════════════════════════════════════════════════
show_battle_cry() {
    clear

    # タイトルバナー（色付き）
    echo ""
    echo -e "\033[1;31m╔══════════════════════════════════════════════════════════════════════════════════╗\033[0m"
    echo -e "\033[1;31m║\033[0m \033[1;33m███████╗██╗  ██╗██╗   ██╗████████╗███████╗██╗   ██╗     ██╗██╗███╗   ██╗\033[0m \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m \033[1;33m██╔════╝██║  ██║██║   ██║╚══██╔══╝██╔════╝██║   ██║     ██║██║████╗  ██║\033[0m \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m \033[1;33m███████╗███████║██║   ██║   ██║   ███████╗██║   ██║     ██║██║██╔██╗ ██║\033[0m \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m \033[1;33m╚════██║██╔══██║██║   ██║   ██║   ╚════██║██║   ██║██   ██║██║██║╚██╗██║\033[0m \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m \033[1;33m███████║██║  ██║╚██████╔╝   ██║   ███████║╚██████╔╝╚█████╔╝██║██║ ╚████║\033[0m \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m \033[1;33m╚══════╝╚═╝  ╚═╝ ╚═════╝    ╚═╝   ╚══════╝ ╚═════╝  ╚════╝ ╚═╝╚═╝  ╚═══╝\033[0m \033[1;31m║\033[0m"
    echo -e "\033[1;31m╠══════════════════════════════════════════════════════════════════════════════════╣\033[0m"
    echo -e "\033[1;31m║\033[0m       \033[1;37m出陣じゃーーー！！！\033[0m    \033[1;36m⚔\033[0m    \033[1;35m天下布武！\033[0m                          \033[1;31m║\033[0m"
    echo -e "\033[1;31m╚══════════════════════════════════════════════════════════════════════════════════╝\033[0m"
    echo ""

    # ═══════════════════════════════════════════════════════════════════════════
    # 足軽隊列（動的生成）
    # ═══════════════════════════════════════════════════════════════════════════
    # 足軽数に応じた漢数字（bash 3.x 互換）
    case $ASHIGARU_COUNT in
        1) KANJI_COUNT="一" ;;
        2) KANJI_COUNT="二" ;;
        3) KANJI_COUNT="三" ;;
        4) KANJI_COUNT="四" ;;
        5) KANJI_COUNT="五" ;;
        6) KANJI_COUNT="六" ;;
        7) KANJI_COUNT="七" ;;
        8) KANJI_COUNT="八" ;;
        *) KANJI_COUNT="$ASHIGARU_COUNT" ;;
    esac

    echo -e "\033[1;34m  ╔═════════════════════════════════════════════════════════════════════════════╗\033[0m"
    echo -e "\033[1;34m  ║\033[0m                    \033[1;37m【 足 軽 隊 列 ・ ${KANJI_COUNT} 名 配 備 】\033[0m                      \033[1;34m║\033[0m"
    echo -e "\033[1;34m  ╚═════════════════════════════════════════════════════════════════════════════╝\033[0m"

    # 足軽ASCIIアートを動的に生成
    echo ""
    LINE1="      "
    LINE2="      "
    LINE3="     "
    LINE4="       "
    LINE5="      "
    LINE6="      "
    LINE7="     "
    for i in $(seq 1 $ASHIGARU_COUNT); do
        LINE1+="/\\      "
        LINE2+="/||\\    "
        LINE3+="/_||\\   "
        LINE4+="||      "
        LINE5+="/||\\    "
        LINE6+="/  \\    "
        LINE7+="[足$i]   "
    done
    echo "$LINE1"
    echo "$LINE2"
    echo "$LINE3"
    echo "$LINE4"
    echo "$LINE5"
    echo "$LINE6"
    echo "$LINE7"
    echo ""

    echo -e "                    \033[1;36m「「「 はっ！！ 出陣いたす！！ 」」」\033[0m"
    echo ""

    # ═══════════════════════════════════════════════════════════════════════════
    # システム情報
    # ═══════════════════════════════════════════════════════════════════════════
    echo -e "\033[1;33m  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓\033[0m"
    echo -e "\033[1;33m  ┃\033[0m  \033[1;37m🏯 multi-agent-shogun\033[0m  〜 \033[1;36mAgent Teams 戦国マルチエージェント\033[0m 〜           \033[1;33m┃\033[0m"
    echo -e "\033[1;33m  ┃\033[0m                                                                           \033[1;33m┃\033[0m"
    echo -e "\033[1;33m  ┃\033[0m    \033[1;35m将軍\033[0m: 統括  \033[1;31m家老\033[0m: 管理  \033[1;32m目付\033[0m: 品質保証  \033[1;34m足軽\033[0m×$ASHIGARU_COUNT: 実働      \033[1;33m┃\033[0m"
    echo -e "\033[1;33m  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛\033[0m"
    echo ""
}

# バナー表示実行
show_battle_cry

echo -e "  \033[1;33m天下布武！出陣準備を開始いたす\033[0m"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 1: 前回記録のバックアップ（内容がある場合のみ）
# ═══════════════════════════════════════════════════════════════════════════════
BACKUP_DIR="./logs/backup_$(date '+%Y%m%d_%H%M%S')"
NEED_BACKUP=false

if [ -f "./dashboard.md" ]; then
    if grep -q "cmd_" "./dashboard.md" 2>/dev/null; then
        NEED_BACKUP=true
    fi
fi

if [ "$NEED_BACKUP" = true ]; then
    mkdir -p "$BACKUP_DIR" || true
    cp "./dashboard.md" "$BACKUP_DIR/" 2>/dev/null || true
    log_info "📦 前回の記録をバックアップ: $BACKUP_DIR"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 2: ダッシュボード初期化
# ═══════════════════════════════════════════════════════════════════════════════
log_info "📊 戦況報告板を初期化中..."
TIMESTAMP=$(date "+%Y-%m-%d %H:%M")

if [ "$LANG_SETTING" = "ja" ]; then
    cat > ./dashboard.md << EOF
# 📊 戦況報告
最終更新: ${TIMESTAMP}

## 🚨 要対応 - 殿のご判断をお待ちしております
なし

## 🔄 進行中 - 只今、戦闘中でござる
なし

## ✅ 本日の戦果
| 時刻 | 戦場 | 任務 | 結果 |
|------|------|------|------|

## 🎯 スキル化候補 - 承認待ち
なし

## 🛠️ 生成されたスキル
なし

## ⏸️ 待機中
なし

## ❓ 伺い事項
なし
EOF
else
    cat > ./dashboard.md << EOF
# 📊 戦況報告 (Battle Status Report)
最終更新 (Last Updated): ${TIMESTAMP}

## 🚨 要対応 - 殿のご判断をお待ちしております (Action Required - Awaiting Lord's Decision)
なし (None)

## 🔄 進行中 - 只今、戦闘中でござる (In Progress - Currently in Battle)
なし (None)

## ✅ 本日の戦果 (Today's Achievements)
| 時刻 (Time) | 戦場 (Battlefield) | 任務 (Mission) | 結果 (Result) |
|------|------|------|------|

## 🎯 スキル化候補 - 承認待ち (Skill Candidates - Pending Approval)
なし (None)

## 🛠️ 生成されたスキル (Generated Skills)
なし (None)

## ⏸️ 待機中 (On Standby)
なし (None)

## ❓ 伺い事項 (Questions for Lord)
なし (None)
EOF
fi

log_success "  └─ ダッシュボード初期化完了 (言語: $LANG_SETTING)"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 3: Claude Code 起動（Agent Teams 方式）
# ═══════════════════════════════════════════════════════════════════════════════

# Claude Code CLI の存在チェック
if ! command -v claude &> /dev/null; then
    log_info "⚠️  claude コマンドが見つかりません"
    echo "  first_setup.sh を再実行してください:"
    echo "    ./first_setup.sh"
    exit 1
fi

# tmux の存在確認（Agent Teams の teammateMode: tmux に必要）
if ! command -v tmux &> /dev/null; then
    echo ""
    echo "  ╔════════════════════════════════════════════════════════╗"
    echo "  ║  [ERROR] tmux not found!                              ║"
    echo "  ║  Agent Teams の tmux モードには tmux が必要です       ║"
    echo "  ╚════════════════════════════════════════════════════════╝"
    echo ""
    exit 1
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 4: tmux セッション作成 + 将軍起動
# ═══════════════════════════════════════════════════════════════════════════════
# Agent Teams (teammateMode: tmux) は tmux 内で Claude を実行する必要がある。
# 将軍を tmux セッション内で起動し、Agent Teams がチームメイトの pane を自動作成する。

log_war "👑 将軍の本陣を構築中..."

# 既存セッションをクリーンアップ
tmux kill-session -t shogun 2>/dev/null && log_info "  └─ 既存の shogun セッション撤収" || true

# 将軍用 tmux セッションを作成し、claude-shogun を起動
tmux new-session -d -s shogun -n "shogun" \
    "cd '$(pwd)' && ./scripts/claude-shogun --dangerously-skip-permissions"

log_success "  └─ 将軍の本陣、構築完了"
echo ""

echo ""
echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║  🏯 出陣準備完了！天下布武！                              ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo ""

echo "  ┌──────────────────────────────────────────────────────────┐"
echo "  │  Agent Teams 方式（tmux モード）                         │"
echo "  │                                                          │"
echo "  │  将軍が tmux セッション 'shogun' で起動しました。        │"
echo "  │  Agent Teams がチームメイトを tmux pane に自動 spawn。   │"
echo "  │                                                          │"
echo "  │  将軍にアタッチして指示を出してください:                  │"
echo "  │    tmux attach -t shogun                                 │"
echo "  │                                                          │"
echo "  │  エージェント一覧:                                        │"
echo "  │    tmux ls                                               │"
echo "  │    Ctrl+b → 矢印キー でペイン切替                       │"
echo "  └──────────────────────────────────────────────────────────┘"
echo ""
echo "  ════════════════════════════════════════════════════════════"
echo "   天下布武！勝利を掴め！ (Tenka Fubu! Seize victory!)"
echo "  ════════════════════════════════════════════════════════════"
echo ""
