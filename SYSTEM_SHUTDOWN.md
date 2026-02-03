# multi-agent-shogun システム終了手順書

## 概要
multi-agent-shogun システムを正式に終了する際の手順を定める。
データの保全と次回起動時の円滑な再開を保証する。

## 終了レベル

### レベル1: 一時停止（推奨）
**用途**: 作業の一時中断、休憩、次の指示待ち
**データ**: すべて保持される
**再開**: そのまま継続可能

### レベル2: セッション終了
**用途**: 今日の作業終了、Claude Code の終了
**データ**: YAMLファイル、Memory MCPは保持
**再開**: セッション開始手順から

### レベル3: 完全終了
**用途**: プロジェクト完了、システム撤収
**データ**: バックアップ後、クリーンアップ
**再開**: 新規構築が必要

---

## レベル1: 一時停止手順

### 1. 現在状況の確認
```bash
# 進行中タスクの確認
cat dashboard.md | head -20

# 足軽の状態確認
tmux ls
```

### 2. 状態保存（自動）
- YAMLファイルは既に保存済み
- Memory MCPは自動永続化済み
- 特別な操作は不要

### 3. 停止宣言
```
殿: 「一旦停止」または「休憩」
将軍: 「承知つかまつった。いつでも再開可能でござる」
```

### 4. 再開方法
```
殿: 任意のコマンドを入力
将軍: 通常通り応答
```

---

## レベル2: セッション終了手順

### 1. 作業完了確認

#### 将軍が実行
```bash
# 未完了タスクの確認
grep -l "status: pending" queue/shogun_to_karo.yaml

# 進行中タスクの確認
grep -l "status: in_progress" queue/tasks/*.yaml

# 足軽の報告確認
ls -la queue/reports/
```

### 2. 最終状態の記録

#### dashboard.md の最終更新
```bash
# 現在時刻で更新
date "+%Y-%m-%d %H:%M"
```

#### セッション終了記録を作成
```yaml
# status/session_end.yaml
session_end:
  timestamp: "YYYY-MM-DDTHH:MM:SS"
  ended_by: shogun
  pending_tasks:
    - cmd_xxx（もしあれば）
  next_action: "次回起動時にやること"
  notes: "引き継ぎ事項"
```

### 3. Memory MCPへの最終記録
```python
mcp__memory__add_observations(
  entityName="セッション履歴",
  contents=["YYYY-MM-DD セッション終了。次回は〇〇から再開"]
)
```

### 4. tmuxセッション保存（オプション）
```bash
# tmuxセッションを保持したまま終了
tmux detach-client

# または、tmuxセッション自体を終了
tmux kill-session -t shogun
tmux kill-session -t multiagent
```

### 5. 再開方法
1. Claude Code 起動
2. instructions/shogun.md を読む
3. Memory MCP 読み込み
4. dashboard.md 確認
5. queue/shogun_to_karo.yaml 確認
6. 作業再開

---

## レベル3: 完全終了手順

### 1. 全タスク完了確認

```bash
# すべてのタスクが done であることを確認
grep "status:" queue/shogun_to_karo.yaml | grep -v "done"

# 報告書アーカイブ
tar czf reports_$(date +%Y%m%d).tar.gz queue/reports/
```

### 2. プロジェクトアーカイブ

```bash
# プロジェクトファイルのバックアップ
tar czf project_backup_$(date +%Y%m%d).tar.gz \
  config/ \
  projects/ \
  queue/ \
  status/ \
  dashboard.md \
  memory/
```

### 3. Memory MCPエクスポート

```bash
# 知識グラフをエクスポート
mcp__memory__read_graph() > memory_export_$(date +%Y%m%d).json
```

### 4. クリーンアップ

```bash
# キューファイルをクリア
echo "queue: []" > queue/shogun_to_karo.yaml
rm -f queue/tasks/*.yaml
rm -f queue/reports/*.yaml

# ステータスをリセット
echo "status: idle" > status/master_status.yaml

# ダッシュボードを初期化
cp dashboard.md dashboard_$(date +%Y%m%d).md.backup
cat > dashboard.md << EOF
# 📊 戦況報告
最終更新: $(date "+%Y-%m-%d %H:%M")

## 🚨 要対応
なし

## 🔄 進行中
なし

## ✅ 本日の戦果
なし
EOF
```

### 5. tmuxセッション終了

```bash
# すべてのtmuxセッションを終了
tmux kill-session -t shogun
tmux kill-session -t multiagent
```

### 6. 完了報告

```
将軍: 「システム完全終了の儀、完了いたしました。
       全データはアーカイブ済みでござる。
       次回は新規構築からとなります。」
```

---

## 緊急終了（異常時）

### 強制終了が必要な場合

```bash
# tmuxセッション強制終了
tmux kill-server

# プロセス確認と終了
ps aux | grep claude
pkill -f claude
```

### データ復旧

```bash
# YAMLファイルは自動保存されているため復旧可能
ls -la queue/
ls -la status/

# Memory MCPも永続化済み
ls -la memory/
```

---

## 推奨終了方法

### 日常作業の終了
→ **レベル1: 一時停止**を使用
- 最も簡単で安全
- データ損失なし
- 即座に再開可能

### 1日の終わり
→ **レベル2: セッション終了**を使用
- 適切な記録を残す
- Memory MCPで引き継ぎ

### プロジェクト完了時
→ **レベル3: 完全終了**を使用
- 完全なアーカイブ
- クリーンな状態にリセット

---

## 注意事項

1. **Ctrl+C での強制終了は避ける**
   - データ不整合の原因
   - 必ず正式手順を使用

2. **Memory MCPは必ず更新**
   - 重要な決定事項
   - 次回への引き継ぎ事項

3. **YAMLファイルの整合性**
   - status は必ず更新
   - pending のまま残さない

4. **tmux detach を活用**
   - セッションを生かしたまま離脱
   - 後で tmux attach で復帰可能

---

以上が multi-agent-shogun システムの正式終了手順である。
状況に応じて適切なレベルを選択せよ。