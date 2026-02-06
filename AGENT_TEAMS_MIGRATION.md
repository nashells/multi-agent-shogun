# Agent Teams 移行計画

> **目的**: 現行の tmux + YAML + $NOTIFY_SH 方式を、Claude Code の Agent Teams 機能に移行する
> **ステータス**: テスト実装フェーズ
> **作成日**: 2026-02-06
> **参考ドキュメント**: https://code.claude.com/docs/ja/agent-teams

---

## 1. 背景

### 1.1 現行システム（v1.x）

multi-agent-shogun は tmux + YAML + シェルスクリプトでマルチエージェント連携を実現している。

```
上様（人間）
  ↓
将軍（Shogun） ─── shogun セッション
  ↓ YAML + $NOTIFY_SH
家老（Karo） ─── multiagent:0.0
  ↓ YAML + $NOTIFY_SH
┌─────────────────┬──────────────┐
目付（Metsuke）  足軽（Ashigaru）×N
multiagent:0.1   multiagent:0.2〜
```

**課題**:
- 通信が YAML ファイル + `$NOTIFY_SH`（tmux send-keys ラッパー）で煩雑
- 通信ロスト問題（send-keys が処理中のエージェントに届かない）
- watchdog.sh でポーリング監視が必要
- 起動スクリプト（shutsujin_departure.sh）が 500 行超の巨大シェル
- コンパクション復帰時に指示書の再読み込みが必須（忘れると動作不良）

### 1.2 Agent Teams（Claude Code 新機能）

Claude Code に組み込みのマルチエージェント機能。

```
Team Leader（1つの Claude Code セッション）
  ↓ 組み込みタスクリスト + メールボックス
Team Members（独立した Claude Code インスタンス）
```

**特徴**:
- 組み込みメッセージング（自動配信、ロストなし）
- 共有タスクリスト（依存関係対応）
- delegate mode（リーダーは管理専念、コード書かない）
- plan approval（メンバーの実装計画を承認制にできる）
- アイドル通知（自動）
- split-pane モード（tmux 利用）

**制約**:
- **実験的機能**（`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` で有効化）
- ネストされたチーム不可（リーダー→メンバーの 2 層のみ）
- リーダー固定（変更不可）
- セッションあたり 1 チーム
- in-process モードでは `/resume` でメンバー復元不可

### 1.3 現行システムの実態分析

現行の 4 層構造（将軍→家老→目付/足軽）は、実態としては **2 層** で動いている:

- **将軍**: 人間との対話＋家老への指示出し（管理層）
- **家老・目付・足軽**: 全員が Claude Code インスタンス。役割の違いはプロンプト（instructions/*.md）で定義されているだけ

つまり、家老・目付・足軽はアーキテクチャ上は同じレイヤーであり、プロンプトによって「タスク管理者」「レビュアー」「実装者」に分かれているに過ぎない。

**家老を残す意義**:
- 将軍がタスク分解・割り振り中でも、人間は将軍に話しかけられる
- 家老がタスク管理を担うことで、将軍は人間対応に専念できる
- delegate mode は将軍にのみ適用し、家老は spawn プロンプトでコード編集禁止にする

### 1.4 移行の本質

本移行は **アーキテクチャ刷新ではなく、通信基盤の置き換え** である。

| 変わるもの | 変わらないもの |
|-----------|-------------|
| 通信方式（YAML + $NOTIFY_SH → 組み込みメッセージング） | 役割構造（将軍・家老・目付・足軽） |
| タスク管理（YAML手動 → 共有タスクリスト） | 各エージェントの責務 |
| アイドル検知（watchdog → 組み込み通知） | 戦国風ロールプレイ |
| 起動方式（シェルスクリプト → spawn） | dashboard.md による人間向け報告 |

---

## 2. 移行後のアーキテクチャ（v2.0）

### 2.1 構成

```
上様（人間）
  ↓
将軍（Shogun）= Team Leader（delegate mode）
  │  人間との対話 + 高レベル指揮に専念（コードに触らない）
  │
  ├── 組み込みタスクリスト + メールボックス
  │
  ├── 家老（Karo）= Team Member（Task Manager）
  │     タスク分解・割り振り・dashboard.md 更新
  │     ※ コード編集禁止（spawn プロンプトで制約）
  │
  ├── 目付（Metsuke）= Team Member（Reviewer）
  │     plan approval 必須
  │     品質チェック担当
  │     ※ コード編集禁止（spawn プロンプトで制約）
  │
  ├── 足軽1（Ashigaru1）= Team Member（Worker）
  ├── 足軽2（Ashigaru2）= Team Member（Worker）
  └── 足軽N（AshigaruN）= Team Member（Worker）
```

### 2.2 レイヤー変更

| v1.x | v2.0 | 変更内容 |
|------|------|--------|
| 将軍（指揮のみ） | Team Leader（delegate mode） | 人間対応 + 家老への指示。delegate mode でコード編集不可 |
| 家老（タスク管理） | Team Member（Task Manager） | **通信方式のみ変更**。タスク分解・割り振り・dashboard 更新は維持。コード編集禁止は spawn プロンプトで制約 |
| 目付（QA） | Team Member（Reviewer） | 品質ゲートを plan approval で実現。コード編集禁止は spawn プロンプトで制約 |
| 足軽（実働） | Team Member（Worker） | そのまま移行 |

### 2.3 通信方式の変更（移行の本質）

本移行で変わるのはこの通信基盤のみ。役割構造は維持される。

| 機能 | v1.x | v2.0 |
|------|------|------|
| エージェント間通信 | YAML + `$NOTIFY_SH` | 組み込みメールボックス（message/broadcast） |
| タスク管理 | YAMLファイル手動管理 | 共有タスクリスト（TaskCreate/TaskUpdate） |
| アイドル検知 | watchdog.sh（5分ポーリング） | 組み込み自動通知 |
| 起動 | shutsujin_departure.sh | `spawn teammate` コマンド |
| 状態確認 | `tmux capture-pane` | 組み込みステータス |
| 通信ロスト対策 | 全報告ファイルスキャン | 不要（自動配信で発生しない） |
| 品質ゲート | 目付が YAML で報告 → 家老が判断 | 目付が plan approval で提出 → 将軍が approve/reject |

---

## 3. 残すもの・変えるもの

### 3.1 残すもの

| ファイル/機能 | 理由 |
|-------------|------|
| `CLAUDE.md` | Agent Teams でも自動ロードされる。プロジェクトルール |
| `instructions/` | spawn 時のプロンプトとして活用（内容は改訂） |
| `dashboard.md` | 人間用の状況報告。Agent Teams には人間向け UI がない |
| `config/settings.yaml` | 言語設定・足軽数の設定 |
| 戦国風ロールプレイ | プロンプトで維持 |
| `context/` | プロジェクトコンテキスト |
| `skills/` | スキル定義 |

### 3.2 廃止するもの

| ファイル/機能 | 代替 |
|-------------|------|
| `scripts/notify.sh` | 組み込みメッセージング |
| `watchdog.sh` | 組み込みアイドル通知 |
| `queue/` ディレクトリ全体 | 共有タスクリスト |
| `shutsujin_departure.sh` の大部分 | 大幅簡素化 |
| `tmux capture-pane` による状態確認 | 組み込みステータス |

### 3.3 改訂するもの

| ファイル | 変更内容 |
|---------|--------|
| `CLAUDE.md` | 通信プロトコルを Agent Teams 方式に書き換え |
| `instructions/shogun.md` | Team Leader + delegate mode 用に改訂。通信方式を Agent Teams に変更 |
| `instructions/karo.md` | Team Member（Task Manager）用に改訂。通信方式のみ変更、タスク管理責務は維持 |
| `instructions/metsuke.md` | plan approval ワークフロー用に改訂 |
| `instructions/ashigaru.md` | Team Member 用に改訂。YAML 読み込み→タスクリスト参照に変更 |
| `shutsujin_departure.sh` | Agent Teams の初期化のみに簡素化 |
| `scripts/claude-shogun` | Agent Teams 環境変数の設定を追加 |

---

## 4. 実装手順

### Phase 1: 環境設定

#### 4.1 Agent Teams の有効化

settings.json（ユーザーまたはプロジェクト）に追加:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "teammateMode": "tmux"
}
```

または `~/.claude/settings.json` に設定。

#### 4.2 claude-shogun の更新

`scripts/claude-shogun` に Agent Teams 関連の環境変数を追加:

```bash
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```

### Phase 2: CLAUDE.md の改訂

現在の CLAUDE.md から以下を変更:

1. **通信プロトコル**セクション
   - 「YAML + $NOTIFY_SH」→「Agent Teams 組み込みメッセージング」
   - `$NOTIFY_SH` 関連の記述を Agent Teams のメッセージングに置換
   - ポーリング禁止は維持（Agent Teams でも不要）

2. **階層構造**セクション
   - 役割構造（将軍・家老・目付・足軽）は維持
   - 通信方式の記述を Agent Teams に更新
   - 家老 = Team Member（Task Manager）であることを明記

3. **ファイル構成**セクション
   - `queue/` 関連を削除
   - `~/.claude/teams/` と `~/.claude/tasks/` の説明を追加

4. **コンパクション復帰**セクション
   - YAML 再読み込み → タスクリスト確認に変更
   - CLAUDE.md は自動ロードされるため手順簡素化

### Phase 3: 指示書の改訂

#### 4.3 instructions/shogun.md（Team Leader 用）

家老への委譲パターンを維持。通信方式のみ Agent Teams に変更:

```markdown
---
role: team_leader
version: "3.0"
mode: delegate  # コードに触らない

forbidden_actions:
  - id: F001
    action: self_execute_task
    description: "自分でコードを書く・ファイルを編集する"
    delegate_to: team_members
  - id: F002
    action: direct_ashigaru_command
    description: "足軽に直接指示する（必ず家老を経由せよ）"
  - id: F003
    action: polling
    description: "ポーリング（待機ループ）"
  - id: F004
    action: skip_context_reading
    description: "コンテキストを読まずに作業開始"

workflow:
  - step: 1
    action: receive_command
    from: user
  - step: 2
    action: delegate_to_karo
    method: "家老に message で指示。タスク分解は家老に委譲"
    note: "将軍は人間対応に専念。詳細なタスク管理は家老の責務"
  - step: 3
    action: wait_for_report
    note: "家老からの完了報告を待つ"
  - step: 4
    action: report_to_user
---
```

重要なポイント:
- **delegate mode**: `Shift+Tab` で切り替え。リーダーは管理ツールのみ使用可能
- **家老に委譲**: タスク分解・割り振りは家老の責務。将軍は家老に message で指示を出し、即座に人間対応に戻る
- **dashboard.md の更新**: 家老の責任（v1.x と同じ）
- **spawn 時のプロンプト**: instructions/ の内容をプロンプトとして渡す

spawn の例:
```
Create a team with N+1 teammates.
- 1 task manager (Karo) using the prompt from instructions/karo_v2.md
- 1 reviewer (Metsuke) with plan approval required, using the prompt from instructions/metsuke_v2.md
- N-1 workers (Ashigaru) using the prompt from instructions/ashigaru_v2.md
Use split pane mode with tmux.
```

#### 4.3.5 instructions/karo.md（Task Manager Team Member 用）

通信方式のみ Agent Teams に変更。責務は v1.x と同一:

```markdown
---
role: task_manager
version: "3.0"

constraints:
  - "コード編集禁止（Read/Glob/Grep のみ許可）"
  - "ファイル作成・編集は足軽に委譲せよ"

responsibilities:
  - タスク分解（五つの問い）
  - 足軽・目付へのタスク割り振り
  - dashboard.md の更新
  - 足軽の報告集約・品質チェック依頼
  - IDLE 削減（足軽が遊ばないよう次タスクを先出し）

workflow:
  - step: 1
    action: receive_instruction
    from: leader  # 将軍から message で受信
  - step: 2
    action: analyze_and_decompose
    note: "五つの問い: 何を？誰が？どの順で？品質基準は？完了条件は？"
  - step: 3
    action: create_tasks
    method: "TaskCreate で共有タスクリストにタスク作成"
  - step: 4
    action: assign_to_members
    method: "message で足軽・目付に指示"
  - step: 5
    action: monitor_and_integrate
    note: "進捗監視・結果統合・品質ゲート依頼"
  - step: 6
    action: update_dashboard
    target: dashboard.md
  - step: 7
    action: report_to_leader
    method: "message で将軍に完了報告"
---
```

変更点:
- YAML タスクファイル → 共有タスクリスト（TaskCreate/TaskUpdate）
- `$NOTIFY_SH` → message コマンド
- 五つの問い・品質ゲート・IDLE 削減は **そのまま維持**
- **コード編集禁止**: spawn プロンプトで制約（delegate mode はリーダー専用のため使えない）

#### 4.4 instructions/metsuke.md（Reviewer Team Member 用）

plan approval ワークフローに対応:

```markdown
---
role: reviewer
version: "3.0"
plan_approval: required  # リーダーの承認が必要

check_items:
  - コード品質（バグ・セキュリティ）
  - 指示内容との整合性
  - 既存資産との整合性
  - 作業漏れチェック
  - 技術選定チェック
---
```

変更点:
- YAML 報告 → メッセージで直接報告
- 家老への通知 → リーダーへの message
- plan approval: レビュー結果をプランとして提出し、リーダーが approve/reject
- **コード編集禁止**: spawn プロンプトで制約（レビューのみ。修正は足軽に依頼）

#### 4.5 instructions/ashigaru.md（Worker Team Member 用）

```markdown
---
role: worker
version: "3.0"

workflow:
  - step: 1
    action: check_task_list
    note: "TaskList / TaskGet でタスクを確認"
  - step: 2
    action: claim_task
    note: "TaskUpdate で in_progress に更新"
  - step: 3
    action: execute
  - step: 4
    action: complete_task
    note: "TaskUpdate で completed に更新"
  - step: 5
    action: report
    method: "message でリーダーに報告"
  - step: 6
    action: claim_next
    note: "次の未割当タスクを自動取得"
---
```

変更点:
- YAML タスクファイル読み込み → TaskGet でタスク確認
- YAML 報告書作成 → message でリーダーに報告
- `$NOTIFY_SH` → 不要（自動配信）
- 自分の足軽番号確認 → 不要（タスクリストで自己割当）

### Phase 4: 起動スクリプトの簡素化

#### 4.6 shutsujin_departure.sh の改訂

Agent Teams が tmux ペインの作成とエージェント起動を自動で行うため、
起動スクリプトは以下のみに簡素化:

```bash
#!/bin/bash
# shutsujin_departure.sh v2.0 - Agent Teams 版

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 設定読み込み
LANGUAGE=$(grep '^language:' "$SCRIPT_DIR/config/settings.yaml" | awk '{print $2}')
ASHIGARU_COUNT=$(grep '^ashigaru_count:' "$SCRIPT_DIR/config/settings.yaml" | awk '{print $2}')

# 前回バックアップ
if [ -f "$SCRIPT_DIR/dashboard.md" ]; then
  BACKUP_DIR="$SCRIPT_DIR/logs/backup_$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$BACKUP_DIR"
  cp "$SCRIPT_DIR/dashboard.md" "$BACKUP_DIR/"
fi

# dashboard.md 初期化
cat > "$SCRIPT_DIR/dashboard.md" << 'DASHBOARD'
# 戦況報告（Dashboard）

最終更新: -

## 🚨 要対応 - 殿のご判断をお待ちしております

なし

## 🔄 進行中

なし

## ✅ 本日の戦果

なし

## 🎯 スキル化候補

なし
DASHBOARD

# Agent Teams 環境変数設定
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1

# Claude Code 起動（Agent Teams はプロンプトで構成）
echo "出陣！ Agent Teams モードで起動..."
echo "チームの構成は Claude Code 内で行われます"
echo ""
echo "起動後、以下のように指示してください:"
echo "  Create a team with $ASHIGARU_COUNT workers and 1 reviewer..."
echo ""

claude-shogun
```

### Phase 5: dashboard.md の維持

Agent Teams には人間向けダッシュボードがないため、`dashboard.md` は維持する。
更新責任者は v1.x と同じく家老:

| v1.x | v2.0 |
|------|------|
| 家老が更新 | 家老（Team Member: Task Manager）が更新 |

将軍は dashboard.md を読んで状況を把握し、人間に報告する。この分担は v1.x と同じ。

---

## 5. テスト計画

### 5.1 基本動作テスト

1. **Agent Teams 有効化確認**
   - `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` 設定後、Claude Code 起動
   - チーム作成を指示し、メンバーが spawn されることを確認

2. **通信テスト**
   - リーダー → メンバーへのメッセージ送信
   - メンバー → リーダーへの報告
   - メンバー間の直接通信

3. **タスクリストテスト**
   - タスク作成・割当・完了のフロー
   - 依存関係のあるタスクのブロック/解除

4. **delegate mode テスト**
   - リーダーがコードを書こうとした際に制限されることを確認
   - リーダーが dashboard.md を更新できることを確認

5. **plan approval テスト**
   - 目付（Reviewer）がプランを提出
   - リーダーが approve/reject

### 5.2 シナリオテスト

1. **簡単なタスク**: 「hello.md を3つ作成」
   - 将軍がタスク分解（3ファイル → 3足軽に並列割当）
   - 足軽が作成・報告
   - 将軍が統合・dashboard 更新

2. **品質ゲート付きタスク**: 「関数を作成してテストも書け」
   - 足軽が実装
   - 目付がレビュー（plan approval）
   - リーダーが approve → dashboard 更新

3. **複数依存タスク**: 「スキーマ定義 → API実装 → テスト」
   - タスク依存関係の設定
   - 順次実行の確認

### 5.3 エッジケーステスト

1. メンバーがエラーで停止した場合の復旧
2. リーダーが作業を始めてしまう場合（delegate mode の制約確認）
3. 同一ファイルへの同時書き込み（RACE-001 相当）

---

## 6. 移行時の注意点

### 6.1 Agent Teams の制約への対応

| 制約 | 対応策 |
|------|--------|
| ネストされたチーム不可 | 現行も実質 2 層（将軍 + それ以外）。家老は Team Member として維持し、spawn プロンプトでタスク管理者の役割を付与 |
| リーダー固定 | 将軍を常にリーダーとする設計 |
| in-process でのセッション再開不可 | tmux split-pane モードを推奨 |
| セッションあたり 1 チーム | 1 プロジェクト = 1 チームの運用 |
| delegate mode はリーダー専用 | 家老・目付のコード編集禁止は spawn プロンプトで制約 |

### 6.2 v1.x との共存

移行期間中は v1.x と v2.0 を切り替え可能にする:

```bash
# v1.x 起動
./shutsujin_departure.sh

# v2.0 起動（Agent Teams 版）
./shutsujin_departure_v2.sh
# または
CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 claude-shogun
```

### 6.3 ロールバック

Agent Teams が不安定な場合、v1.x に即座に戻せるようにする:
- 旧ファイル（instructions/, scripts/）は削除せず保持
- v2.0 用のファイルは別名で作成

---

## 7. ファイル変更一覧

### 新規作成

| ファイル | 内容 |
|---------|------|
| `.claude/settings.json` | Agent Teams 環境変数、teammateMode 設定 |
| `instructions/shogun_v2.md` | Team Leader 用指示書（v2.0） |
| `instructions/karo_v2.md` | Task Manager Team Member 用指示書（v2.0） |
| `instructions/metsuke_v2.md` | Reviewer Team Member 用指示書（v2.0） |
| `instructions/ashigaru_v2.md` | Worker Team Member 用指示書（v2.0） |
| `shutsujin_departure_v2.sh` | Agent Teams 版起動スクリプト |

### 改訂

| ファイル | 変更内容 |
|---------|--------|
| `CLAUDE.md` | Agent Teams 対応版に改訂（v1.x 部分はコメントアウトで残す） |
| `scripts/claude-shogun` | Agent Teams 環境変数追加 |

### 削除候補（v2.0 安定後）

| ファイル | 理由 |
|---------|------|
| `scripts/notify.sh` | 組み込みメッセージングで代替 |
| `watchdog.sh` | 組み込みアイドル通知で代替 |
| `queue/` ディレクトリ | 共有タスクリストで代替 |

---

## 8. 将軍の spawn プロンプトテンプレート

Agent Teams でチームを構成する際、将軍が使うプロンプトのテンプレート:

```
Create an agent team to work on the following project task.

Team structure:
- 1 task manager teammate named "karo".
  Spawn prompt: Read instructions/karo_v2.md and follow it as your role definition.
  You are the task manager. You decompose tasks, assign them to workers, update dashboard.md,
  and report results to the leader. IMPORTANT: You MUST NOT edit code files. You may only
  read files (Read/Glob/Grep). All code changes must be delegated to ashigaru workers.

- 1 reviewer teammate named "metsuke" with plan approval required.
  Spawn prompt: Read instructions/metsuke_v2.md and follow it as your role definition.
  You are the quality gate. Review all work before it can be marked complete.
  IMPORTANT: You MUST NOT edit code files. Reviews only. Request fixes from ashigaru workers.

- {N} worker teammates named "ashigaru1" through "ashigaru{N}".
  Spawn prompt: Read instructions/ashigaru_v2.md and follow it as your role definition.
  You are a worker. Claim tasks from the task list and execute them.

Use split pane mode with tmux.
I will operate in delegate mode - I coordinate only, I don't write code.

Language: {language setting from config/settings.yaml}
If language is "ja", all communication in 戦国風日本語.
```

### 8.1 各 spawn プロンプトの制約一覧

| エージェント | コード編集 | ファイル読み取り | タスク管理 | message 送信 | dashboard 更新 | 制約方式 |
|------------|-----------|----------------|-----------|-------------|--------------|---------|
| 将軍（Leader） | 不可 | 可 | 可 | 可 | 読み取りのみ | delegate mode |
| 家老（Karo） | **不可** | 可 | 可 | 可 | **更新責任者** | spawn プロンプト |
| 目付（Metsuke） | **不可** | 可 | 可（レビュー） | 可 | 不可 | spawn プロンプト |
| 足軽（Ashigaru） | 可 | 可 | 可（自タスク） | 可 | 不可 | 制約なし |

### 8.2 delegate mode と spawn プロンプト制約の違い

| | delegate mode | spawn プロンプト制約 |
|--|-------------|-------------------|
| 適用対象 | Team Leader のみ | Team Member |
| 強制力 | システムレベル（ツール使用自体をブロック） | プロンプトレベル（指示に従わせる） |
| 設定方法 | `Shift+Tab` で切り替え | spawn 時のプロンプトに明記 |
| 制限内容 | コード作成ツール全般 | プロンプトで指定した操作 |

> **注意**: spawn プロンプト制約はシステム強制ではないため、プロンプトインジェクションや
> コンパクション後の忘却で破られる可能性がある。重要な制約は instructions/*.md にも明記し、
> コンパクション復帰時に再読み込みされるようにすること。

---

## 9. 参考リンク

- Agent Teams ドキュメント: https://code.claude.com/docs/ja/agent-teams
- 設定リファレンス: https://code.claude.com/docs/ja/settings
- タスクリスト: https://code.claude.com/docs/ja/interactive-mode#task-list
- サブエージェントとの比較: https://code.claude.com/docs/ja/features-overview#compare-similar-features

---

## 10. 用語対応表

| 将軍システム用語 | Agent Teams 用語 | 説明 |
|----------------|-----------------|------|
| 将軍（Shogun） | Team Leader | プロジェクト統括。delegate mode |
| 家老（Karo） | Team Member (Task Manager) | タスク管理・分配・dashboard 更新 |
| 目付（Metsuke） | Team Member (Reviewer) | 品質保証 |
| 足軽（Ashigaru） | Team Member (Worker) | 実働部隊 |
| $NOTIFY_SH | message / broadcast | エージェント間通信 |
| queue/*.yaml | Shared Task List | タスク管理 |
| dashboard.md | dashboard.md（維持） | 人間用レポート |
| watchdog.sh | （廃止） | 組み込み通知で代替 |
| shutsujin（出陣） | spawn teammates | チーム起動 |
| tettai（撤退） | shut down + clean up | チーム終了 |

---

## 11. v1.x → v2.0 責務対応表

通信方式のみ変更し、各エージェントの責務は維持されることを明示する。

### 将軍（Shogun）

| 責務 | v1.x | v2.0 | 変更 |
|------|------|------|------|
| 人間との対話 | tmux pane で直接 | 同じ | なし |
| 家老への指示 | YAML + $NOTIFY_SH | message コマンド | 通信方式のみ |
| dashboard 確認 | Read dashboard.md | 同じ | なし |
| タスク分解 | 家老に委譲 | 家老に委譲 | なし |
| コード編集 | 禁止 | 禁止（delegate mode） | 強制方式が強化 |

### 家老（Karo）

| 責務 | v1.x | v2.0 | 変更 |
|------|------|------|------|
| タスク分解（五つの問い） | YAML に記載 | TaskCreate で作成 | 通信方式のみ |
| 足軽への割り振り | YAML + $NOTIFY_SH | message コマンド | 通信方式のみ |
| dashboard.md 更新 | 直接編集 | 同じ | なし |
| 将軍への報告 | YAML + $NOTIFY_SH | message コマンド | 通信方式のみ |
| 品質ゲート依頼 | 目付に YAML 指示 | 目付に message | 通信方式のみ |
| IDLE 削減 | 足軽の状態監視 | タスクリスト活用 | 方式改善 |
| コード編集 | 禁止 | 禁止（spawn プロンプト） | なし |

### 目付（Metsuke）

| 責務 | v1.x | v2.0 | 変更 |
|------|------|------|------|
| コードレビュー | Read + 報告 YAML | Read + plan approval | 報告方式のみ |
| 品質チェック | チェック項目に基づく | 同じ | なし |
| 家老への報告 | YAML + $NOTIFY_SH | message コマンド | 通信方式のみ |
| コード編集 | 禁止 | 禁止（spawn プロンプト） | なし |

### 足軽（Ashigaru）

| 責務 | v1.x | v2.0 | 変更 |
|------|------|------|------|
| タスク実行 | YAML で受領 → 実装 | TaskGet で確認 → 実装 | 受領方式のみ |
| 完了報告 | 報告 YAML 作成 + $NOTIFY_SH | TaskUpdate + message | 報告方式のみ |
| スキル化候補の報告 | YAML に記載 | message に記載 | 通信方式のみ |
| コード編集 | 許可 | 許可 | なし |
