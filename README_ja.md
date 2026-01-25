# 🏯 claude-shogun

Claude Code + tmux を使ったマルチエージェント並列開発基盤。
戦国時代の軍制をモチーフにした階層構造で、複数プロジェクトを並行管理できる。

## 概要

claude-shogunは、以下の階層構造で複数のClaude Codeエージェントを統率する：

```
会長（人間）
    │
    ▼
┌─────────┐
│ SHOGUN  │ ← 将軍（プロジェクト統括）
│ (将軍)   │
└────┬────┘
     │
     ▼
┌─────────┐
│  KARO   │ ← 家老（タスク管理・分配）
│ (家老)   │
└────┬────┘
     │
     ▼
┌─┬─┬─┬─┬─┬─┬─┬─┐
│1│2│3│4│5│6│7│8│ ← 足軽（実働部隊）
└─┴─┴─┴─┴─┴─┴─┴─┘
  ASHIGARU (足軽)
```

## 特徴

- **YAMLベース通信**: ファイルベースの確実なエージェント間通信
- **人間用ダッシュボード**: 全プロジェクト・タスクの進捗を一目で把握
- **複数プロジェクト対応**: 複数のプロジェクトを並行して管理
- **戦国テーマ**: 和英併記の楽しいコミュニケーションスタイル

## クイックスタート

### 必要環境
- WSL2（Ubuntu推奨）
- tmux
- Claude Code CLI

### セットアップ（WSL）

```bash
# Windowsディレクトリにクローン（VSCodeアクセス用に推奨）
git clone https://github.com/YOUR_USERNAME/claude-shogun.git /mnt/c/tools/claude-shogun

# WSLホームからシンボリックリンク作成（簡単アクセス用）
ln -s /mnt/c/tools/claude-shogun ~/claude-shogun

# 移動してセットアップ実行
cd ~/claude-shogun
./setup.sh
```

### 出陣手順

```bash
# 【壱】将軍の本陣に参上
tmux attach-session -t shogun

# 【弐】Claude Codeを召喚
claude --dangerously-skip-permissions

# 【参】出陣を命ず
# 「汝は将軍なり。instructions/shogun.mdを読み、指示に従え」
```

## 言葉遣い

エージェントは戦国風 + 和英併記のスタイルでコミュニケーションする：

- `はっ！(Ha!)` - 了解
- `承知つかまつった(Acknowledged!)` - 理解した
- `任務完了でござる(Task completed!)` - タスク完了
- `出陣いたす(Deploying!)` - 作業開始
- `申し上げます(Reporting!)` - 報告

## ファイル構成

```
claude-shogun/
├── instructions/          # エージェント指示書
│   ├── shogun.md
│   ├── karo.md
│   └── ashigaru.md
├── config/
│   └── projects.yaml      # プロジェクト設定
├── status/
│   └── master_status.yaml # 全体ステータス
├── queue/                 # メッセージキュー
│   ├── shogun_to_karo.yaml
│   ├── karo_to_ashigaru.yaml
│   └── reports/
├── dashboard.md           # 人間用ダッシュボード
└── setup.sh               # セットアップスクリプト
```

## クレジット

[Claude-Code-Communication](https://github.com/Akira-Papa/Claude-Code-Communication) by Akira-Papa をベースに開発。

## ロードマップ

### MVP（現在）
- [x] YAMLベース通信
- [x] 人間用ダッシュボード
- [x] ペルソナシステムによる品質担保
- [x] コンテキスト読み込みルール
- [x] スキル自動生成（汎用パターンを再利用可能なスキルとして蓄積）

### 今後の予定
- [ ] MCP対応（Notion, Slack, Google Drive, GitHub 等）
- [ ] 複数プロジェクト並列実行
- [ ] エージェント障害時の自動復旧

## ライセンス

MIT License
