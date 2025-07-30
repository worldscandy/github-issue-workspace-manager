# GitHub Issue Workspace Manager

GitHub issueの作業用に複数リポジトリのワークスペースを自動生成・管理するBashスクリプトです。

## 🌟 主な機能

### setup_issue_workspace.sh
- **自動ワークスペース作成**: GitHub issueからワークスペースディレクトリを自動生成
- **組織別階層管理**: 各リポジトリの実際の所属組織に基づいた自動階層化
- **Git worktree管理**: 各リポジトリを独立したworktreeとして管理
- **Issue情報の永続化**: `.issue-info`ファイルでissue情報を保存・継承
- **重複チェック**: 既存リポジトリの自動検出とスキップ
- **自動ブランチ作成**: issue番号とタイトルから一貫したブランチ名を生成
- **カスタムブランチ名対応**: 任意のブランチ名で複数ワークスペースを作成可能
- **日本語対応**: マルチバイト文字を含むissueタイトルにも対応
- **main/masterブランチ対応**: 自動的に適切なデフォルトブランチを検出
- **エラー復旧**: 孤立したworktreeの自動クリーンアップ
- **詳細レポート**: 成功・スキップ・失敗の処理結果サマリー

### update_all_repositories.sh
- **一括リポジトリ更新**: 指定ディレクトリ内の全リポジトリを一括更新
- **再帰的探索**: 複数階層のディレクトリ構造に対応
- **探索深度制御**: 最大探索深度を設定可能（デフォルト：3階層）
- **柔軟な設定**: ディレクトリパス、デフォルトブランチ、探索深度を設定可能
- **安全な更新**: 未コミットの変更がある場合は自動スキップ
- **submodule対応**: 各リポジトリでsubmoduleの自動同期
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

# 新しいワークスペースを作成（デフォルト）
./setup_issue_workspace.sh create https://github.com/owner/repo/issues/123 repo1 repo2

# カスタムブランチ名でワークスペースを作成
./setup_issue_workspace.sh create https://github.com/owner/repo/issues/123 repo1 repo2 --branch phase1-auth

# 既存のワークスペースにリポジトリを追加
./setup_issue_workspace.sh update issues/workspace_name new-repo

# 全リポジトリを一括更新
./update_all_repositories.sh
```

## 📖 詳細な使用方法

### コマンド一覧

#### 1. 新しいワークスペース作成

```bash
./setup_issue_workspace.sh create <issue_url> <repo1> [repo2 ...] [--branch <custom_branch_name>]
```

**オプション:**
- `--branch, -b <name>`: カスタムブランチ名を指定（英数字、ハイフン、アンダースコアのみ）

**例:**
```bash
# デフォルト（issueタイトルから自動生成）
./setup_issue_workspace.sh create https://github.com/owner/main-repo/issues/123 repo1 repo2

# カスタムブランチ名を指定
./setup_issue_workspace.sh create https://github.com/owner/main-repo/issues/123 repo1 repo2 --branch phase1-auth

# 短縮オプション
./setup_issue_workspace.sh create https://github.com/owner/main-repo/issues/123 repo1 repo2 -b feature-payments
```

#### 2. 既存ワークスペースの更新

```bash
./setup_issue_workspace.sh update <workspace_dir> <repo1> [repo2 ...]
```

**例:**
```bash
# 既存ワークスペースにリポジトリを追加
./setup_issue_workspace.sh update issues/Feature_Request_main-repo-123 new-repo1 new-repo2
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
./update_all_repositories.sh -d repositories/my-org -b main -m 4

# 環境変数で設定
REPOSITORIES_DIR=repos DEFAULT_BRANCH=main MAX_DEPTH=2 ./update_all_repositories.sh
```

### 生成されるディレクトリ構造

```
issues/                              # ワークスペースディレクトリ（変更可能）
├── <Issue_Title>_<repo>-<issue_number>/    # デフォルト（英語）
├── <repo>-<issue_number>/                  # デフォルト（日本語含む）
└── <custom_branch_name>_<repo>-<issue_number>/  # カスタムブランチ名指定時
    ├── .issue-info                  # Issue情報保存ファイル
    ├── org-name-1/                  # 各リポジトリの実際の所属組織別ディレクトリ
    │   ├── repo1/                   # Git worktreeディレクトリ
    │   └── repo2/                   # Git worktreeディレクトリ
    └── org-name-2/                  # 別の組織のリポジトリ
        └── repo3/                   # Git worktreeディレクトリ

repositories/                        # リポジトリクローン先（変更可能）
├── org-name-1/                      # 組織/ユーザー別ディレクトリ（2階層目）
│   ├── repo1/                       # 元リポジトリ（3階層目）
│   └── repo2/                       # 元リポジトリ（3階層目）
└── org-name-2/                      # 別の組織（2階層目）
    ├── repo3/                       # 元リポジトリ（3階層目）
    └── repo4/                       # 元リポジトリ（3階層目）
```

**重要な特徴**:
- ワークスペース内の組織ディレクトリは、各リポジトリの**実際の所属組織**に基づいて自動的に作成されます
- 複数の組織のリポジトリを同じワークスペースで管理できます
- 例：異なる組織のリポジトリが混在する場合、それぞれ適切な組織ディレクトリに配置されます

**注意**: `update_all_repositories.sh`は指定ディレクトリから再帰的に探索し、デフォルトで最大3階層まで検索します。上記の例では`repositories/`が1階層目となるため、最大3階層まで探索されます。

### Issue情報の永続化

各ワークスペースには `.issue-info` ファイルが作成され、以下の情報が保存されます：

```bash
ISSUE_URL="https://github.com/owner/repo/issues/123"
ORG_NAME="owner"
REPO_NAME="repo"
ISSUE_NUMBER="123"
ISSUE_TITLE="Feature Request"
SAFE_BRANCH_TITLE="Feature_Request"    # デフォルト時
CUSTOM_BRANCH_NAME=""                   # カスタムブランチ名（空文字列または指定値）
```

**カスタムブランチ名指定時の例:**
```bash
ISSUE_URL="https://github.com/owner/repo/issues/123"
ORG_NAME="owner"
REPO_NAME="repo"
ISSUE_NUMBER="123"
ISSUE_TITLE="Feature Request"
SAFE_BRANCH_TITLE="phase1-auth"
CUSTOM_BRANCH_NAME="phase1-auth"
```

これにより、updateモードでも一貫したブランチ名とリポジトリ設定が継承されます。

### ブランチ命名規則

各リポジトリには以下の形式でブランチが作成されます：

#### デフォルト（英語のissueタイトル）
```
<issue_origin_repo>-<issue_number>/<sanitized_issue_title>
```
**例:** Issue URLが `https://github.com/owner/main-repo/issues/123` でタイトルが "Feature Request" の場合：
- `main-repo-123/Feature_Request` (全リポジトリで共通)

#### デフォルト（日本語を含むissueタイトル）
```
<issue_origin_repo>-<issue_number>
```
**例:** Issue URLが `https://github.com/owner/main-repo/issues/456` でタイトルが "新機能の実装" の場合：
- `main-repo-456` (全リポジトリで共通)

#### カスタムブランチ名指定時
```
<issue_origin_repo>-<issue_number>/<custom_branch_name>
```
**例:** Issue URLが `https://github.com/owner/main-repo/issues/123` でカスタムブランチ名が "phase1-auth" の場合：
- `main-repo-123/phase1-auth` (全リポジトリで共通)

**注意**: 
- デフォルトでマルチバイト文字（日本語、中国語など）が含まれている場合は、Git ブランチ名の制約を考慮してissue番号のみを使用します
- カスタムブランチ名は英数字、ハイフン、アンダースコアのみ使用可能です

## 🎯 特徴

### 組織別階層管理

- **自動組織検出**: 各リポジトリの実際の所属組織を自動検出
- **階層化配置**: 組織別ディレクトリに自動配置
- **複数組織対応**: 異なる組織のリポジトリを同一ワークスペースで管理
- **重複防止**: 追加済みリポジトリの自動検出とスキップ

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

#### 組織名の自動検出

各リポジトリの所属組織は以下の方法で自動検出されます：

1. **リポジトリ構造からの検出**: `repositories/<org-name>/<repo-name>` 構造をスキャン
2. **自動階層化**: 検出された組織名でワークスペース内にディレクトリを自動作成
3. **複数組織対応**: 異なる組織のリポジトリを同一ワークスペースで管理可能

**注意**: 環境変数 `GITHUB_ORG` は通常不要です。各リポジトリの実際の所属組織が自動検出されるため、手動設定は基本的に不要です。

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
# 1. Issue URLから新しいワークスペースを作成（デフォルト）
./setup_issue_workspace.sh create https://github.com/owner/main-repo/issues/456 repo1 repo2 repo3

# 例：以下のような構造が自動作成されます
# issues/New_Feature_main-repo-456/
# ├── company-org/
# │   ├── repo1/     # company-org組織のリポジトリ
# │   └── repo2/     # company-org組織のリポジトリ  
# └── personal-org/
#     └── repo3/     # personal-org組織のリポジトリ

# 2. 同じissueで段階的な作業（カスタムブランチ名）
./setup_issue_workspace.sh create https://github.com/owner/main-repo/issues/456 repo1 repo2 --branch phase1-auth
./setup_issue_workspace.sh create https://github.com/owner/main-repo/issues/456 repo1 repo3 --branch phase2-database

# 結果：独立した2つのワークスペースで並行作業可能
# - issues/phase1-auth_main-repo-456/
# - issues/phase2-database_main-repo-456/

# 3. 既存ワークスペースに追加のリポジトリが必要になった場合
./setup_issue_workspace.sh update issues/phase1-auth_main-repo-456 additional-repo
```

### 2. 複数リポジトリの一括更新

```bash
# 毎朝の作業開始前に全リポジトリを最新化（再帰的探索）
./update_all_repositories.sh

# 特定ディレクトリのリポジトリのみ更新
./update_all_repositories.sh -d repositories/org-name

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

**Q: 日本語のissueタイトルでエラーが発生する**
A: 最新版のスクリプトではマルチバイト文字に対応しています。issue番号のみでブランチ名とディレクトリ名が生成されます。

**Q: "masterブランチが存在しません" エラー**
A: 最新版のスクリプトではmain/masterブランチを自動検出します。どちらも存在しない場合はリポジトリの状態を確認してください。

**Q: カスタムブランチ名でエラーが発生する**
A: カスタムブランチ名は英数字、ハイフン、アンダースコアのみ使用可能です：
```bash
# ❌ 不正な例
./setup_issue_workspace.sh create URL repo --branch "機能追加"
./setup_issue_workspace.sh create URL repo --branch ""
./setup_issue_workspace.sh create URL repo --branch "feature/auth@system"

# ✅ 正しい例
./setup_issue_workspace.sh create URL repo --branch "feature-auth"
./setup_issue_workspace.sh create URL repo --branch "phase1_testing"
./setup_issue_workspace.sh create URL repo --branch "bug-fix-123"
```

**Q: 同名のワークスペースが既に存在する**
A: 以下の解決方法から選択してください：
1. 既存ワークスペースに追加: `./setup_issue_workspace.sh update "ワークスペース名" リポジトリ名`
2. 別のカスタムブランチ名で作成: `--branch 別の名前`
3. 既存ワークスペースを削除してから再作成: `rm -rf "ワークスペース名"`