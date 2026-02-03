# Teams Transcript Downloader

Microsoft Teams会議のトランスクリプト（議事録）を自動でダウンロードするPythonツールです。

## 📋 概要

このツールは、Microsoft Graph APIを使用して、Teams会議のトランスクリプトを取得し、ローカルに保存します。複数の会議のトランスクリプトを一括でダウンロードできるため、議事録管理や記録保存の作業を効率化できます。

## 🎯 前提条件

### 必要な環境
- **Python**: 3.8以上
- **Microsoft 365アカウント**: Teams会議のトランスクリプトにアクセスできるアカウント
- **Azure AD管理者権限**: アプリケーションを登録するために必要（初回セットアップ時のみ）

### 必要な権限
このツールを使用するには、以下のMicrosoft Graph API権限が必要です：
- `OnlineMeetings.Read.All` - 会議情報を読み取る
- `CallRecords.Read.All` - 通話記録を読み取る
- または `Transcript.Read.All` - トランスクリプトを読み取る（利用可能な場合）

## 🚀 セットアップ手順

### ステップ1: Azure ADアプリケーションの登録

1. **Azure Portalにログイン**
   - [Azure Portal](https://portal.azure.com)にアクセス
   - Microsoft 365管理者アカウントでログイン

2. **Azure Active Directoryを開く**
   - 左側メニューから「Azure Active Directory」を選択
   - または、検索バーで「Azure Active Directory」を検索

3. **アプリの登録**
   - 左側メニューから「アプリの登録」を選択
   - 上部の「+ 新規登録」をクリック

4. **アプリケーション情報を入力**
   - **名前**: `Teams Transcript Downloader`（任意の名前）
   - **サポートされているアカウントの種類**:
     - 「この組織ディレクトリのみのアカウント」を選択（通常はこれ）
   - **リダイレクトURI**:
     - プラットフォーム: 「パブリック クライアント/ネイティブ (モバイルとデスクトップ)」
     - URI: `http://localhost:8080/callback`
   - 「登録」をクリック

5. **アプリケーションIDをメモ**
   - 登録が完了すると、「概要」ページが表示される
   - **アプリケーション (クライアント) ID**をコピーして保存（後で使用）
   - **ディレクトリ (テナント) ID**もコピーして保存

6. **クライアントシークレットを作成**
   - 左側メニューから「証明書とシークレット」を選択
   - 「+ 新しいクライアント シークレット」をクリック
   - 説明: `Transcript Tool Secret`（任意）
   - 有効期限: 推奨は「24か月」
   - 「追加」をクリック
   - **値**（シークレット）をコピーして安全に保存（⚠️ 一度しか表示されません）

### ステップ2: API権限の設定

1. **API権限を追加**
   - 左側メニューから「APIのアクセス許可」を選択
   - 「+ アクセス許可の追加」をクリック

2. **Microsoft Graphを選択**
   - 「Microsoft Graph」をクリック

3. **アプリケーション権限を選択**
   - 「アプリケーションの許可」を選択（デリゲートではない）

4. **必要な権限を追加**
   - 検索ボックスに「OnlineMeetings」と入力
   - `OnlineMeetings.Read.All`にチェック
   - 検索ボックスに「CallRecords」と入力
   - `CallRecords.Read.All`にチェック
   - 「アクセス許可の追加」をクリック

5. **管理者の同意を付与**
   - 「<組織名> に管理者の同意を与えます」をクリック
   - 「はい」をクリックして確認
   - 状態が緑のチェックマーク「<組織名> に付与されました」になることを確認

### ステップ3: Pythonライブラリのインストール

プロジェクトディレクトリで以下のコマンドを実行：

```bash
pip install msal requests
```

または、requirements.txtがある場合：

```bash
pip install -r requirements.txt
```

**インストールされるライブラリ**:
- `msal`: Microsoft認証ライブラリ（OAuth 2.0フロー）
- `requests`: HTTP通信（Microsoft Graph API呼び出し）

### ステップ4: 設定ファイルの作成

プロジェクトルートに `config.yaml` を作成（`config.yaml.example` をコピーして編集）：

```bash
cp config.yaml.example config.yaml
```

**config.yaml の内容**:
```yaml
# Azure AD Authentication Settings
azure:
  tenant_id: "YOUR_TENANT_ID_HERE"
  client_id: "YOUR_CLIENT_ID_HERE"
  client_secret: "YOUR_CLIENT_SECRET_HERE"
  scopes:
    - "https://graph.microsoft.com/.default"

# Microsoft Graph API Settings
graph_api:
  base_url: "https://graph.microsoft.com/v1.0"
  beta_url: "https://graph.microsoft.com/beta"

# Output Settings
output:
  directory: "./transcripts"

# Logging Settings
logging:
  level: "INFO"
  file: "./teams_transcript_downloader.log"
```

**設定項目の説明**:

| 項目 | 説明 | 取得場所 |
|------|------|----------|
| `azure.client_id` | アプリケーション（クライアント）ID | Azure AD > アプリの登録 > 概要 |
| `azure.client_secret` | クライアントシークレット | Azure AD > 証明書とシークレット（作成時にコピーした値） |
| `azure.tenant_id` | ディレクトリ（テナント）ID | Azure AD > アプリの登録 > 概要 |
| `azure.scopes` | API権限スコープ | 固定値: `["https://graph.microsoft.com/.default"]` |
| `graph_api.base_url` | Graph API v1.0 エンドポイント | 固定値: `https://graph.microsoft.com/v1.0` |
| `graph_api.beta_url` | Graph API Beta エンドポイント | 固定値: `https://graph.microsoft.com/beta` |
| `output.directory` | トランスクリプト保存先ディレクトリ | 任意のパス（例: `./transcripts`） |
| `logging.level` | ログレベル | `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL` |
| `logging.file` | ログファイルパス | 任意のパス（例: `./teams_transcript_downloader.log`） |

**⚠️ セキュリティ注意**:
- `config.yaml`は機密情報を含むため、必ず`.gitignore`に追加してGit管理から除外してください
- クライアントシークレットは定期的に更新することを推奨します

**.gitignoreへの追加例**:
```
# Configuration files with sensitive data
config.yaml
*.log

# Output directory
transcripts/
```

## 💻 使用方法

### 基本的な実行

```bash
python teams_transcript_downloader.py
```

### 実行の流れ

1. **認証**
   - スクリプトがMicrosoft Graph APIに接続
   - `config.yaml`の認証情報を使用して自動ログイン

2. **会議一覧の取得**
   - 指定した期間のTeams会議を検索
   - トランスクリプトが存在する会議のみ表示

3. **トランスクリプトのダウンロード**
   - 各会議のトランスクリプトをダウンロード
   - デフォルトでは`./transcripts/`フォルダに保存

### コマンドライン引数（実装によって異なる場合があります）

```bash
# 特定の期間を指定
python teams_transcript_downloader.py --start-date 2024-01-01 --end-date 2024-01-31

# 出力ディレクトリを指定
python teams_transcript_downloader.py --output ./my_transcripts

# 特定の会議IDを指定
python teams_transcript_downloader.py --meeting-id <MEETING_ID>
```

### 期待される出力

```
[INFO] Authenticating with Microsoft Graph API...
[SUCCESS] Authentication successful!
[INFO] Fetching meetings from 2024-01-01 to 2024-01-31...
[INFO] Found 5 meetings with transcripts
[INFO] Downloading transcript for meeting: "Weekly Sync" (2024-01-15)
[SUCCESS] Saved: ./transcripts/weekly_sync_2024-01-15.vtt
[INFO] Downloading transcript for meeting: "Project Review" (2024-01-22)
[SUCCESS] Saved: ./transcripts/project_review_2024-01-22.vtt
[SUCCESS] All transcripts downloaded successfully!
```

## ⚠️ 重要: Beta API の使用について

このツールは、Microsoft Graph API の **Beta エンドポイント** を使用しています。

**Beta API の特徴**:
- トランスクリプト関連の機能は、現時点（2026-02-03）では Beta エンドポイントでのみ提供されています
- Beta API は予告なく変更される可能性があります
- プロダクション環境での使用は推奨されません（Microsoftの公式ガイドラインによる）

**推奨事項**:
- 本番環境で使用する前に、十分なテストを行ってください
- Microsoft Graph API のアップデート情報を定期的に確認してください
- 将来的に v1.0 エンドポイントでトランスクリプト機能が利用可能になった場合は、移行を検討してください

**参考リンク**:
- [Microsoft Graph versioning and support](https://docs.microsoft.com/en-us/graph/versioning-and-support)
- [Microsoft Graph API changelog](https://docs.microsoft.com/en-us/graph/changelog)

## 🔧 トラブルシューティング

### エラー: "Authentication failed"

**原因**:
- `config.yaml`の認証情報が間違っている
- クライアントシークレットの有効期限切れ

**対処法**:
1. `config.yaml`の`azure.client_id`、`azure.client_secret`、`azure.tenant_id`を確認
2. Azure Portalで新しいクライアントシークレットを作成し、`config.yaml`を更新
3. `azure.tenant_id`が正しいか確認（Azure AD > 概要ページ）

---

### エラー: "Insufficient privileges"

**原因**:
- API権限が不足している
- 管理者の同意が付与されていない

**対処法**:
1. Azure Portalで「APIのアクセス許可」を確認
2. `OnlineMeetings.Read.All`と`CallRecords.Read.All`が追加されているか確認
3. 緑のチェックマーク「<組織名> に付与されました」が表示されているか確認
4. 表示されていない場合、「管理者の同意を与えます」をクリック

---

### エラー: "Meeting not found" / "No transcripts available"

**原因**:
- 会議にトランスクリプトが生成されていない
- 会議の録画・文字起こし機能がオフになっている
- 検索期間に該当する会議がない

**対処法**:
1. Teamsで会議の録画と文字起こしが有効になっているか確認
2. 会議終了後、トランスクリプトの生成には時間がかかる場合があります（数分〜数時間）
3. 検索期間を広げてみる

---

### エラー: "ModuleNotFoundError: No module named 'msal'"

**原因**:
- 必要なPythonライブラリがインストールされていない

**対処法**:
```bash
pip install msal requests
```

または、仮想環境を使用している場合は、正しい環境でインストールしてください：
```bash
# 仮想環境を有効化
source venv/bin/activate  # Linux/Mac
# または
venv\Scripts\activate  # Windows

# ライブラリをインストール
pip install msal requests
```

---

### エラー: "Connection timeout" / "Network error"

**原因**:
- インターネット接続の問題
- ファイアウォールやプロキシがMicrosoft Graph APIへのアクセスをブロック

**対処法**:
1. インターネット接続を確認
2. 企業ネットワークの場合、IT部門にMicrosoft Graph API (`https://graph.microsoft.com`)へのアクセス許可を確認
3. プロキシ設定が必要な場合、環境変数を設定：
   ```bash
   export HTTPS_PROXY=http://proxy.example.com:8080
   ```

---

### エラー: "Invalid redirect URI"

**原因**:
- Azure ADアプリの登録時に設定したリダイレクトURIが間違っている

**対処法**:
1. Azure Portal > アプリの登録 > 認証を開く
2. リダイレクトURIが`http://localhost:8080/callback`になっているか確認
3. プラットフォームが「パブリック クライアント/ネイティブ」になっているか確認

## 📚 参考情報

- [Microsoft Graph API ドキュメント](https://docs.microsoft.com/en-us/graph/)
- [Azure AD アプリ登録ガイド](https://docs.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app)
- [MSAL Python ドキュメント](https://github.com/AzureAD/microsoft-authentication-library-for-python)

## 📝 ライセンス

（プロジェクトのライセンスをここに記載）

## 🤝 サポート

問題が発生した場合や質問がある場合は、以下の方法でお問い合わせください：
- Issue tracker: （GitHubリポジトリのURL）
- Email: （サポートメールアドレス）

---

**更新履歴**:
- 2026-02-03: 初版作成
