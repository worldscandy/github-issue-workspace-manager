# GitHub Issue Workspace Manager

GitHub issueの作業用に複数リポジトリのワークスペースを自動生成・管理するBashスクリプトです。

## 🌟 主な機能

### setup_issue_workspace.sh
- **自動ワークスペース作成**: GitHub issueからワークスペースディレクトリを自動生成
- **Git worktree管理**: 各リポジトリを独立したworktreeとして管理
- **Issue情報の永続化**: `.issue-info`ファイルでissue情報を保存・継承
- **インタラクティブ操作**: 直感的なメニューで簡単操作
- **重複チェック**: 既存リポジトリの自動検出とスキップ
- **自動ブランチ作成**: issue番号とタイトルから一貫したブランチ名を生成
- **エラー復旧**: 孤立したworktreeの自動クリーンアップ
- **詳細レポート**: 成功・スキップ・失敗の処理結果サマリー

### update_all_repositories.sh
- **一括リポジトリ更新**: 指定ディレクトリ内の全リポジトリを一括更新
- **再帰的探索**: 複数階層のディレクトリ構造に対応
- **探索深度制御**: 最大探索深度を設定可能（デフォルト：3階層）
- **柔軟な設定**: ディレクトリパス、デフォルトブランチ、探索深度を設定可能
- **安全な更新**: 未コミットの変更がある場合は自動スキップ
- **詳細なログ**: 各リポジトリの処理状況を詳細表示
- **統計レポート**: 更新成功・スキップ・エラーの統計情報

## 🚀 クイックスタート

### 必要な環境

- Bash 4.0+
- Git
- GitHub CLI (`gh`) - GitHub APIアクセス用
- `jq` - JSON解析用

### 事前準備

スクリプトを使用する前に、リポジトリを適切な構造で準備してください：

```bash
# 作業用リポジトリを準備
mkdir -p repositories/your-org-name
cd repositories/your-org-name
git clone https://github.com/your-org-name/repo1.git
git clone https://github.com/your-org-name/repo2.git
cd ../../
```

### 基本的な使い方

```bash
# スクリプトに実行権限を付与
chmod +x setup_issue_workspace.sh

# 新しいワークスペースを作成
./setup_issue_workspace.sh create https://github.com/owner/repo/issues/123 repo1 repo2

# 既存のワークスペースにリポジトリを追加（インタラクティブ）
./setup_issue_workspace.sh update

# 直接指定でリポジトリを追加
./setup_issue_workspace.sh update issues/workspace_name new-repo

# 全リポジトリを一括更新
./update_all_repositories.sh
```

## 📖 詳細な使用方法

### コマンド一覧

#### 1. 新しいワークスペース作成

```bash
./setup_issue_workspace.sh create <issue_url> <repo1> [repo2 ...]
```

**例:**
```bash
# 新しいワークスペースを作成（組織/ユーザー名はIssue URLから自動抽出）
./setup_issue_workspace.sh create https://github.com/your-username/main-repo/issues/123 repo1 repo2
```

#### 2. 既存ワークスペースの更新

**完全インタラクティブモード（推奨）:**
```bash
./setup_issue_workspace.sh update
```
- ワークスペースを選択メニューから選択
- 追加するリポジトリを入力

**リポジトリ指定でワークスペース選択:**
```bash
./setup_issue_workspace.sh update <repo1> [repo2 ...]
```

**完全指定:**
```bash
./setup_issue_workspace.sh update <workspace_dir> <repo1> [repo2 ...]
```

#### 3. 全リポジトリの一括更新

```bash
./update_all_repositories.sh [OPTIONS]
```

**オプション:**
- `-d, --directory DIR`: リポジトリディレクトリを指定
- `-b, --branch BRANCH`: デフォルトブランチを指定
- `-m, --max-depth DEPTH`: 最大探索深度を指定（デフォルト：3）
- `-h, --help`: ヘルプを表示

**例:**
```bash
# デフォルト設定で実行
./update_all_repositories.sh

# カスタムディレクトリを指定
./update_all_repositories.sh -d my-repos

# mainブランチを使用
./update_all_repositories.sh -b main

# 探索深度を2階層に制限
./update_all_repositories.sh -m 2

# 複数オプションの組み合わせ
./update_all_repositories.sh -d repositories/company -b main -m 4

# 環境変数で設定
REPOSITORIES_DIR=repos DEFAULT_BRANCH=main MAX_DEPTH=2 ./update_all_repositories.sh
```

### 生成されるディレクトリ構造

```
issues/                              # ワークスペースディレクトリ（変更可能）
└── <Issue_Title>_<repo>-<issue_number>/
    ├── .issue-info                  # Issue情報保存ファイル
    ├── repo1/                       # Git worktreeディレクトリ
    ├── repo2/                       # Git worktreeディレクトリ
    └── repo3/                       # Git worktreeディレクトリ

repositories/                        # リポジトリクローン先（変更可能）
├── org-name/                        # 組織/ユーザー別ディレクトリ（2階層目）
│   ├── repo1/                       # 元リポジトリ（3階層目）
│   ├── repo2/                       # 元リポジトリ（3階層目）
│   └── repo3/                       # 元リポジトリ（3階層目）
└── another-org/                     # 別の組織（2階層目）
    └── repo4/                       # 元リポジトリ（3階層目）
```

**注意**: `update_all_repositories.sh`は指定ディレクトリから再帰的に探索し、デフォルトで最大3階層まで検索します。上記の例では`repositories/`が1階層目となるため、最大3階層まで探索されます。

### Issue情報の永続化

各ワークスペースには `.issue-info` ファイルが作成され、以下の情報が保存されます：

```bash
ISSUE_URL="https://github.com/owner/repo/issues/123"
ORG_NAME="owner"
REPO_NAME="repo"
ISSUE_NUMBER="123"
ISSUE_TITLE="Feature Request"
SAFE_BRANCH_TITLE="Feature_Request"
```

これにより、updateモードでも一貫したブランチ名とリポジトリ設定が継承されます。

### ブランチ命名規則

各リポジトリには以下の形式でブランチが作成されます：

```
<repository_name>-<issue_number>/<sanitized_issue_title>
```

**例:**
- `repo1-123/Feature_Request`
- `repo2-123/Feature_Request`

## 🎯 特徴

### インタラクティブ機能

- **ワークスペース選択**: 既存ワークスペースの一覧から選択
- **既存リポジトリ表示**: 各ワークスペースの現在の内容を表示
- **重複防止**: 追加済みリポジトリの自動検出

### エラーハンドリング

- **自動復旧**: 孤立したworktreeの検出と修復
- **詳細ログ**: 各処理の成功・失敗状況を詳細レポート
- **安全な処理**: 既存データを破壊しない設計

### 処理結果レポート

```
==========================================
[INFO] ワークスペース更新処理が完了しました
==========================================
[SUCCESS] 追加されたリポジトリ (2個): repo1 repo2
[SKIPPED] スキップされたリポジトリ (1個): common
[INFO] 現在のワークスペース内容:
  - repo1
  - repo2
  - repo3
  - repo4
==========================================
```

## 🛠 設定

### GitHub認証

GitHub CLIの認証が必要です：

```bash
gh auth login
```

### リポジトリ構造の準備

#### createモード
Issue URLから組織/ユーザー名を自動抽出します（設定不要）

#### updateモード
`.issue-info`ファイルから情報を自動継承します（設定不要）

環境変数 `GITHUB_ORG` を設定することで、手動入力を省略できます：
```bash
export GITHUB_ORG=your-organization-name
```

#### ディレクトリのカスタマイズ

```bash
# ワークスペース作成先ディレクトリ（デフォルト: issues）
export WORKSPACES_DIR=my-workspaces

# リポジトリクローン先ディレクトリ（デフォルト: repositories）
export REPOSITORIES_DIR=my-repos
```

## 📝 使用例

### 1. 新機能開発のワークフロー

```bash
# 1. Issue URLから新しいワークスペースを作成
./setup_issue_workspace.sh create https://github.com/company/main-repo/issues/456 repo1 repo2 repo3

# 2. 開発中に追加のリポジトリが必要になった場合
./setup_issue_workspace.sh update

# 3. ワークスペース選択（インタラクティブ）
#    → "1) issues/New_Feature_main-repo-456"を選択
#    → 追加するリポジトリ名を入力
```

### 2. 複数リポジトリの一括更新

```bash
# 毎朝の作業開始前に全リポジトリを最新化（再帰的探索）
./update_all_repositories.sh

# 特定ディレクトリのリポジトリのみ更新
./update_all_repositories.sh -d repositories/company-name

# 深い階層構造での探索（最大5階層まで）
./update_all_repositories.sh -m 5

# 浅い探索で高速実行（2階層まで）
./update_all_repositories.sh -m 2
```

### 3. 複雑なディレクトリ構造での使用例

```bash
# 以下のような複雑な構造でも自動検出
# project-root/
#   ├── teams/
#   │   ├── frontend/
#   │   │   ├── web-app/        ← リポジトリ（3階層目）
#   │   │   └── mobile-app/     ← リポジトリ（3階層目）
#   │   └── backend/
#   │       ├── api-server/     ← リポジトリ（3階層目）
#   │       └── worker/         ← リポジトリ（3階層目）
#   └── shared/
#       └── common-lib/         ← リポジトリ（2階層目）

./update_all_repositories.sh -d project-root -m 4
```

## 📝 ライセンス

MIT License

## 🤝 コントリビューション

Issues・Pull Requestsを歓迎します！

## 🆘 トラブルシューティング

### よくある問題

**Q: "gh: command not found"**
A: GitHub CLIをインストールしてください：
```bash
# Ubuntu/Debian
sudo apt install gh

# macOS
brew install gh
```

**Q: "jq: command not found"**
A: jqをインストールしてください：
```bash
# Ubuntu/Debian
sudo apt install jq

# macOS
brew install jq
```

**Q: worktree追加に失敗する**
A: 孤立したworktreeをクリーンアップしてください：
```bash
cd path/to/repo
git worktree prune
```

**Q: リポジトリが見つからない**
A: 適切な構造でリポジトリが準備されているか確認してください：
```bash
# 正しい構造
repositories/org-name/repo-name/.git

# 間違った構造
repositories/repo-name/.git
```