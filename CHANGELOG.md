# Changelog

[yohey-w/multi-agent-shogun](https://github.com/yohey-w/multi-agent-shogun) の `9e23e2c` からfork。
以降の変更履歴を記す。

## upstream マージ履歴

### 2026-02-08: upstream/main (95356d2) マージ

fork 元が 64 コミット先行していたため、汎用的改善を選択的に取り込み。
通信基盤が根本的に異なる（upstream: YAML+mailbox vs ours: Agent Teams）ため、全面マージではなく cherry-pick 方式。

#### 取り込んだ改善
| ファイル | 取り込み内容 |
|---------|-------------|
| `first_setup.sh` | tmux マウススクロール設定、CLI ネイティブ版対応、`memory/global_context.md` テンプレート、shell オプション |
| `shutsujin_departure.sh` | `pane-base-index 0` 明示設定 |
| `instructions/karo.md` | RACE-001 詳細化、idle 最小化ルール、Bloom 分類、FG ブロック禁止 |
| `instructions/ashigaru.md` | 目的検証、自己識別ルール |
| `docs/philosophy.md` | 新規取り込み（Agent Teams 版に書き換え） |
| `templates/integ_*.md` | 統合テンプレート 5 ファイル取り込み |
| `.claude/settings.json` | spinnerVerbs（戦国風ジョーク）取り込み |
| `LICENSE` | MIT ライセンス更新 |

#### 不要として除外
| ファイル | 理由 |
|---------|------|
| `scripts/inbox_*.sh` | Agent Teams で不要（mailbox 通信基盤） |
| `scripts/ntfy*.sh` | Agent Teams で不要（ntfy 通知基盤） |
| `saytask/streaks.yaml.sample` | Agent Teams で不要（SayTask 機能） |
| `images/screenshots/*` | ntfy スクリーンショット（不要） |

#### ours を維持
| ファイル | 理由 |
|---------|------|
| `CLAUDE.md` | Agent Teams 版の通信プロトコル |
| `README.md` / `README_ja.md` | Agent Teams 版の説明 |
| `instructions/shogun.md` | Agent Teams 版のワークフロー |
| `.gitignore` | blacklist 方式（upstream は whitelist 方式） |

## 2026-02-08

- **プロジェクト単位の独立運用**: 複数プロジェクトを並行管理できるよう全スクリプトを改修
- `scripts/project-env.sh` 新規作成: 共通変数定義（`PROJECT_NAME_SAFE`, `TMUX_SHOGUN`, `TEAM_NAME` 等を WORK_DIR から自動導出）
- tmux セッション名を `shogun-<project>` / `multiagent-<project>` に変更
- Agent Teams チーム名を `shogun-team-<project>` に変更
- `shutsujin_departure.sh`: 作業ディレクトリに `.shogun/` を自動生成（`project.env`, `bin/` ラッパー, ダッシュボード等）
- `tettai_retreat.sh`: `--project-dir` オプション追加、WORK_DIR 自動発見ロジック
- `watchdog.sh`: `--project-dir` オプション追加、PID ファイル管理
- `switch_account.sh`: `project-env.sh` 対応、再起動ロジックを `shutsujin_departure.sh` に統一
- `shogun.sh`, `multiagent.sh` を削除 → `.shogun/bin/` ラッパーに置き換え
- `first_setup.sh`: 旧キューファイル初期化を削除（Agent Teams 移行済み）
- 全スクリプトのパス参照を `SHOGUN_ROOT` 環境変数に統一

## 2026-02-06

- **Agent Teams 完全移行**: YAML + `$NOTIFY_SH` 通信基盤を Agent Teams API（SendMessage, TaskCreate 等）に全面置き換え
- Agent Teams 移行計画ドキュメント（`AGENT_TEAMS_MIGRATION.md`）を追加
- `scripts/claude-shogun`: Claude Code 起動ラッパーを追加、`$NOTIFY_SH` 環境変数によるパス統一
- 将軍を tmux セッション内で正しく起動するよう修正
- 出陣・撤退スクリプトを shogun / multiagent の2セッション構成に改善

## 2026-02-03

- `scripts/notify.sh`: tmux send-keys ラッパースクリプトを追加
- `watchdog.sh`: ダッシュボード更新検知・Limit 検知の監視システムを追加
- `tettai_retreat.sh`: 撤退（終了）スクリプトを追加
- `switch_account.sh`: Claude アカウント切り替えスクリプトを追加
- `instructions/metsuke.md`: 目付（レビュー担当）の指示書を新規作成
- `instructions/ashigaru-checker.md`: 足軽チェック用補助指示書を新規作成
- 既存の指示書（shogun, karo, ashigaru）を大幅拡充
