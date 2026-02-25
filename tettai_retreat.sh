#!/bin/bash
# 🏯 multi-agent-shogun 撤退スクリプト（全終了用）
# Retreat Script - Graceful shutdown of all agents
# Agent Teams 版
#
# 使用方法:
#   ./tettai_retreat.sh                        # 通常撤退（カレントディレクトリの .shogun/ を使用）
#   ./tettai_retreat.sh --project-dir=/path     # 指定ディレクトリのプロジェクトを撤退
#   ./tettai_retreat.sh -f                      # 強制撤退（バックアップなし）
#   ./tettai_retreat.sh -h                      # ヘルプ表示

set -e

# shogun システムのルートディレクトリ
SHOGUN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 色付きログ関数（戦国風）
log_info() {
    echo -e "\033[1;33m【報】\033[0m $1"
}

log_success() {
    echo -e "\033[1;32m【成】\033[0m $1"
}

log_retreat() {
    echo -e "\033[1;36m【退】\033[0m $1"
}

# ═══════════════════════════════════════════════════════════════════════════════
# オプション解析
# ═══════════════════════════════════════════════════════════════════════════════
FORCE_MODE=false
PROJECT_DIR=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE_MODE=true
            shift
            ;;
        --project-dir=*)
            PROJECT_DIR="${1#*=}"
            shift
            ;;
        -h|--help)
            echo ""
            echo "🏯 multi-agent-shogun 撤退スクリプト（Agent Teams 版）"
            echo ""
            echo "使用方法: ./tettai_retreat.sh [オプション]"
            echo ""
            echo "オプション:"
            echo "  -f, --force              強制撤退（バックアップなし）"
            echo "  --project-dir=<path>     撤退対象のプロジェクトディレクトリを指定"
            echo "  -h, --help               このヘルプを表示"
            echo ""
            echo "例:"
            echo "  ./tettai_retreat.sh                          # カレントディレクトリのプロジェクトを撤退"
            echo "  ./tettai_retreat.sh --project-dir=/path/to/project"
            echo "  ./tettai_retreat.sh -f                       # 強制撤退（即座に終了）"
            echo ""
            echo "WORK_DIR 発見ロジック:"
            echo "  1. --project-dir= で指定されたディレクトリ（.shogun/ が存在する場合）"
            echo "  2. \$(pwd)/.shogun が存在すればカレントディレクトリ"
            echo "  3. フォールバック: SHOGUN_ROOT"
            echo ""
            exit 0
            ;;
        *)
            echo "不明なオプション: $1"
            echo "./tettai_retreat.sh -h でヘルプを表示"
            exit 1
            ;;
    esac
done

# ═══════════════════════════════════════════════════════════════════════════════
# WORK_DIR 発見ロジック
# ═══════════════════════════════════════════════════════════════════════════════
if [ -n "$PROJECT_DIR" ] && [ -d "${PROJECT_DIR}/.shogun" ]; then
    WORK_DIR="$PROJECT_DIR"
elif [ -d "$(pwd)/.shogun" ]; then
    WORK_DIR="$(pwd)"
else
    WORK_DIR="$SHOGUN_ROOT"
fi

# プロジェクト共通変数を読み込み
source "${SHOGUN_ROOT}/scripts/project-env.sh"

# ═══════════════════════════════════════════════════════════════════════════════
# 撤退バナー表示
# ═══════════════════════════════════════════════════════════════════════════════
show_retreat_banner() {
    clear
    echo ""
    echo -e "\033[1;36m╔══════════════════════════════════════════════════════════════════════════════════╗\033[0m"
    echo -e "\033[1;36m║\033[0m \033[1;37m████████╗███████╗████████╗████████╗ █████╗ ██╗\033[0m                                 \033[1;36m║\033[0m"
    echo -e "\033[1;36m║\033[0m \033[1;37m╚══██╔══╝██╔════╝╚══██╔══╝╚══██╔══╝██╔══██╗██║\033[0m                                 \033[1;36m║\033[0m"
    echo -e "\033[1;36m║\033[0m \033[1;37m   ██║   █████╗     ██║      ██║   ███████║██║\033[0m                                 \033[1;36m║\033[0m"
    echo -e "\033[1;36m║\033[0m \033[1;37m   ██║   ██╔══╝     ██║      ██║   ██╔══██║██║\033[0m                                 \033[1;36m║\033[0m"
    echo -e "\033[1;36m║\033[0m \033[1;37m   ██║   ███████╗   ██║      ██║   ██║  ██║██║\033[0m                                 \033[1;36m║\033[0m"
    echo -e "\033[1;36m║\033[0m \033[1;37m   ╚═╝   ╚══════╝   ╚═╝      ╚═╝   ╚═╝  ╚═╝╚═╝\033[0m                                 \033[1;36m║\033[0m"
    echo -e "\033[1;36m╠══════════════════════════════════════════════════════════════════════════════════╣\033[0m"
    echo -e "\033[1;36m║\033[0m       \033[1;37m撤退じゃーーー！！！\033[0m    \033[1;35m⚔\033[0m    \033[1;33m本日の戦、ここまで！\033[0m                    \033[1;36m║\033[0m"
    echo -e "\033[1;36m╚══════════════════════════════════════════════════════════════════════════════════╝\033[0m"
    echo ""
}

# バナー表示
show_retreat_banner

log_info "プロジェクト: ${PROJECT_NAME_SAFE} (${WORK_DIR})"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# 存在確認（tmux セッション + Agent Teams データ）
# ═══════════════════════════════════════════════════════════════════════════════
SHOGUN_EXISTS=false
MULTIAGENT_EXISTS=false
TEAM_DATA_EXISTS=false

if tmux has-session -t "${TMUX_SHOGUN}" 2>/dev/null; then
    SHOGUN_EXISTS=true
fi

if tmux has-session -t "${TMUX_MULTIAGENT}" 2>/dev/null; then
    MULTIAGENT_EXISTS=true
fi

if [ -d "$TEAM_DIR" ] || [ -d "$TASK_DIR" ]; then
    TEAM_DATA_EXISTS=true
fi

if [ "$SHOGUN_EXISTS" = false ] && [ "$MULTIAGENT_EXISTS" = false ] && [ "$TEAM_DATA_EXISTS" = false ]; then
    log_info "陣は既に撤収済みでござる（セッション・チームデータなし）"
    echo ""
    exit 0
fi

# 現在の状態を表示
log_info "現在の陣容:"
[ "$SHOGUN_EXISTS" = true ] && log_info "  ├─ tmux: ${TMUX_SHOGUN} セッション ... 稼働中"
[ "$MULTIAGENT_EXISTS" = true ] && log_info "  ├─ tmux: ${TMUX_MULTIAGENT} セッション ... 稼働中"
[ "$TEAM_DATA_EXISTS" = true ] && log_info "  ├─ Agent Teams: チームデータ (${TEAM_NAME}) ... 存在"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# バックアップ（強制モードでなければ）
# ═══════════════════════════════════════════════════════════════════════════════
if [ "$FORCE_MODE" = false ]; then
    BACKUP_DIR="${LOGS_DIR}/backup_$(date '+%Y%m%d_%H%M%S')"
    NEED_BACKUP=false

    # dashboard.md のバックアップ判定
    if [ -f "${DASHBOARD_PATH}" ]; then
        if grep -q "cmd_" "${DASHBOARD_PATH}" 2>/dev/null; then
            NEED_BACKUP=true
        fi
    fi

    # Agent Teams タスクデータの存在確認
    if [ -d "$TASK_DIR" ]; then
        NEED_BACKUP=true
    fi

    if [ "$NEED_BACKUP" = true ]; then
        log_info "📦 戦況記録をバックアップ中..."
        mkdir -p "$BACKUP_DIR" || true

        # dashboard.md のバックアップ
        if [ -f "${DASHBOARD_PATH}" ]; then
            cp "${DASHBOARD_PATH}" "$BACKUP_DIR/" 2>/dev/null || true
            log_success "  ├─ dashboard.md バックアップ完了"
        fi

        # Agent Teams タスクデータのバックアップ
        if [ -d "$TASK_DIR" ]; then
            cp -r "$TASK_DIR" "$BACKUP_DIR/tasks-${TEAM_NAME}" 2>/dev/null || true
            log_success "  ├─ Agent Teams タスクデータ バックアップ完了"
        fi

        log_success "  └─ バックアップ先: $BACKUP_DIR"
        echo ""
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# 未完了タスク情報の収集（セッションログ・未完了タスク保存で共用）
# ═══════════════════════════════════════════════════════════════════════════════
PENDING_COUNT=0
PENDING_ENTRIES=""
PENDING_TASKS_MD=""

if [ -d "$TASK_DIR" ] && command -v jq &>/dev/null; then
    for task_file in "$TASK_DIR"/*.json; do
        [ -f "$task_file" ] || continue

        task_status=$(jq -r '.status // empty' "$task_file" 2>/dev/null) || continue
        [ "$task_status" = "completed" ] && continue

        task_id=$(jq -r '.id // empty' "$task_file" 2>/dev/null) || true
        task_subject=$(jq -r '.subject // empty' "$task_file" 2>/dev/null) || true
        task_description=$(jq -r '.description // empty' "$task_file" 2>/dev/null) || true
        task_owner=$(jq -r '.owner // empty' "$task_file" 2>/dev/null) || true
        task_blocked_by=$(jq -r '(.blockedBy // []) | map(tostring) | join(", ")' "$task_file" 2>/dev/null) || true

        # バックスラッシュ・ダブルクォートをエスケープ（YAML用）
        task_id_esc="${task_id//\\/\\\\}"
        task_id_esc="${task_id_esc//\"/\\\"}"
        task_subject_esc="${task_subject//\\/\\\\}"
        task_subject_esc="${task_subject_esc//\"/\\\"}"
        task_owner_esc="${task_owner//\\/\\\\}"
        task_owner_esc="${task_owner_esc//\"/\\\"}"
        task_status_esc="${task_status//\\/\\\\}"
        task_status_esc="${task_status_esc//\"/\\\"}"

        # YAML エントリを構築（pending_tasks.yaml 用、description はリテラルブロック）
        PENDING_ENTRIES="${PENDING_ENTRIES}  - id: \"${task_id_esc}\"
    subject: \"${task_subject_esc}\"
    description: |
$(echo "$task_description" | sed 's/^/      /')
    owner: \"${task_owner_esc}\"
    status: \"${task_status_esc}\"
    blockedBy: [${task_blocked_by}]
"
        # Markdown エントリ（セッションログ用）
        PENDING_TASKS_MD="${PENDING_TASKS_MD}- #${task_id} ${task_subject} (owner: ${task_owner}, status: ${task_status})
"
        PENDING_COUNT=$((PENDING_COUNT + 1))
    done
elif [ -d "$TASK_DIR" ] && ! command -v jq &>/dev/null; then
    echo "WARNING: jq が未インストール。未完了タスクの収集をスキップします" >&2
fi

# ═══════════════════════════════════════════════════════════════════════════════
# セッションログ保存（-f モードでも実行）
# ═══════════════════════════════════════════════════════════════════════════════
log_info "📝 セッションログを保存中..."
mkdir -p "${SESSIONS_DIR}"
_now=$(date '+%Y%m%d_%H%M%S')
SESSION_TIMESTAMP="$_now"
SESSION_DATETIME="${_now:0:4}-${_now:4:2}-${_now:6:2} ${_now:9:2}:${_now:11:2}:${_now:13:2}"
SESSION_DATETIME_SHORT="${SESSION_DATETIME%:*}"
SESSION_LOG="${SESSIONS_DIR}/session_${SESSION_TIMESTAMP}.md"

# 戦果（完了タスク）の抽出
SENKA_CONTENT="なし"
if [ -f "${DASHBOARD_PATH}" ]; then
    SENKA_TABLE=$(awk '/^## ✅ 本日の戦果/{found=1; next} /^## /{if(found) exit} found{print}' "${DASHBOARD_PATH}")
    # テーブルのデータ行をカウント（ヘッダ行+セパレータ行=2、データ行があれば3以上）
    SENKA_DATA_ROWS=$(echo "$SENKA_TABLE" | grep -cE '^\|' || true)
    if [ "$SENKA_DATA_ROWS" -gt 2 ]; then
        SENKA_CONTENT="$SENKA_TABLE"
    fi
fi

# 未完了タスクの Markdown
if [ "$PENDING_COUNT" -gt 0 ]; then
    PENDING_MD_CONTENT="${PENDING_TASKS_MD}"
else
    PENDING_MD_CONTENT="なし"
fi

# ダッシュボード最終状態
if [ -f "${DASHBOARD_PATH}" ]; then
    DASHBOARD_CONTENT=$(cat "${DASHBOARD_PATH}")
else
    DASHBOARD_CONTENT="ダッシュボードなし"
fi

# セッションログ生成
{
    echo "# セッションログ ${SESSION_DATETIME_SHORT}"
    echo ""
    echo "- 撤退時刻: ${SESSION_DATETIME}"
    echo "- プロジェクト: ${PROJECT_NAME_SAFE}"
    echo "- 作業ディレクトリ: ${WORK_DIR}"
    echo ""
    echo "## 戦果（完了タスク）"
    printf '%s\n' "${SENKA_CONTENT}"
    echo ""
    echo "## 未完了タスク"
    printf '%s\n' "${PENDING_MD_CONTENT}"
    echo ""
    echo "## ダッシュボード最終状態"
    printf '%s\n' "${DASHBOARD_CONTENT}"
} > "${SESSION_LOG}"

log_success "  └─ セッションログ保存完了: ${SESSION_LOG}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# 未完了タスク保存（-f モードでも実行）
# ═══════════════════════════════════════════════════════════════════════════════
if [ "$PENDING_COUNT" -gt 0 ]; then
    PENDING_YAML="${STATUS_DIR}/pending_tasks.yaml"
    mkdir -p "${STATUS_DIR}"
    SAVED_AT=$(date "+%Y-%m-%d %H:%M")
    {
        echo "# 未完了タスク一覧（撤退時自動保存）"
        echo "# 再出陣時に将軍が読み込み、家老にタスクを再割り当てする"
        echo "saved_at: \"${SAVED_AT}\""
        echo "tasks:"
        printf '%s' "$PENDING_ENTRIES"
    } > "$PENDING_YAML"
    log_info "📜 未完了の陣立て ${PENDING_COUNT} 件を保存いたした"
    log_success "  └─ 保存先: ${PENDING_YAML}"
    echo ""
else
    log_info "📜 未完了の陣立てなし（全任務完了済み）"
    echo ""
fi

# ═══════════════════════════════════════════════════════════════════════════════
# 将軍セッションID保存（-f モードでない場合）
# ═══════════════════════════════════════════════════════════════════════════════
# Claude Code のセッションファイルは ~/.claude/projects/<sanitized-path>/<uuid>.jsonl
# に保存される。将軍のセッションIDを保存しておくと再出陣時に --continue で復元できる。
SESSION_ID_FILE="${STATUS_DIR}/shogun_session_id"

if [ "$FORCE_MODE" = false ] && [ "$SHOGUN_EXISTS" = true ]; then
    # WORK_DIR からセッションディレクトリを導出（/ を - に置換）
    CLAUDE_PROJECT_DIR="$HOME/.claude/projects/$(echo "$WORK_DIR" | tr '/' '-')"

    if [ -d "$CLAUDE_PROJECT_DIR" ]; then
        # 最新の .jsonl ファイル（将軍のセッション）を取得
        LATEST_SESSION=$(ls -t "$CLAUDE_PROJECT_DIR"/*.jsonl 2>/dev/null | head -1)
        if [ -n "$LATEST_SESSION" ]; then
            SESSION_ID=$(basename "$LATEST_SESSION" .jsonl)
            mkdir -p "${STATUS_DIR}"
            echo "$SESSION_ID" > "$SESSION_ID_FILE"
            log_info "📎 将軍のセッションID を保存: ${SESSION_ID:0:8}..."
        fi
    fi
elif [ "$FORCE_MODE" = true ]; then
    # 強制撤退: セッションIDファイルを削除（再開不可にする）
    if [ -f "$SESSION_ID_FILE" ]; then
        trash "$SESSION_ID_FILE" 2>/dev/null || true
        log_info "📎 強制撤退のため、セッションID を破棄"
    fi
fi

# ═══════════════════════════════════════════════════════════════════════════════
# 撤退処理
# ═══════════════════════════════════════════════════════════════════════════════
log_retreat "🏯 全軍撤退開始..."
echo ""

# STEP 1: tmux セッション終了（Claude Code プロセスも終了する）
if [ "$MULTIAGENT_EXISTS" = true ]; then
    log_retreat "  └─ 家老・目付・足軽の陣を撤収中..."
    tmux kill-session -t "${TMUX_MULTIAGENT}" 2>/dev/null || true
    log_success "     └─ ${TMUX_MULTIAGENT} 陣、撤収完了"
fi

if [ "$SHOGUN_EXISTS" = true ]; then
    log_retreat "  └─ 将軍の本陣を撤収中..."
    tmux kill-session -t "${TMUX_SHOGUN}" 2>/dev/null || true
    log_success "     └─ ${TMUX_SHOGUN} 本陣、撤収完了"
fi

# STEP 2: Agent Teams チームデータのクリーンアップ
if [ "$TEAM_DATA_EXISTS" = true ]; then
    log_retreat "  └─ Agent Teams チームデータを撤収中..."

    if [ -d "$TEAM_DIR" ]; then
        trash "$TEAM_DIR" 2>/dev/null || true
        log_success "     └─ チーム設定（teams/${TEAM_NAME}）撤収完了"
    fi

    if [ -d "$TASK_DIR" ]; then
        trash "$TASK_DIR" 2>/dev/null || true
        log_success "     └─ タスクデータ（tasks/${TEAM_NAME}）撤収完了"
    fi
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# 完了メッセージ
# ═══════════════════════════════════════════════════════════════════════════════
echo -e "\033[1;36m  ╔══════════════════════════════════════════════════════════╗\033[0m"
echo -e "\033[1;36m  ║\033[0m  \033[1;37m🏯 撤退完了！本日の戦、お疲れ様でござった！\033[0m              \033[1;36m║\033[0m"
echo -e "\033[1;36m  ╚══════════════════════════════════════════════════════════╝\033[0m"
echo ""
echo "  次回出陣するには:"
echo "  ┌──────────────────────────────────────────────────────────┐"
echo "  │  新規出陣:                                                │"
echo "  │    .shogun/bin/shutsujin.sh                               │"
if [ -f "$SESSION_ID_FILE" ]; then
echo "  │                                                          │"
echo "  │  前回セッション引き継ぎ:                                  │"
echo "  │    .shogun/bin/shutsujin.sh --resume                     │"
fi
echo "  └──────────────────────────────────────────────────────────┘"
echo ""
echo "  ════════════════════════════════════════════════════════════"
echo "   また明日も勝利を掴もうぞ！ (Let's seize victory again!)"
echo "  ════════════════════════════════════════════════════════════"
echo ""
