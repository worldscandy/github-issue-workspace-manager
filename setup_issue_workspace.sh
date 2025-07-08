#!/usr/bin/env bash
# setup_issue_workspace.sh
# 指定したGitHub issueの情報とリポジトリ名リストをもとに、issues/以下にワークスペースを自動生成し、
# 各リポジトリのworktreeをセットアップします
#
# 使い方:
#   bash setup_issue_workspace.sh create <issue_url> <repo1> [<repo2> ...]
#   bash setup_issue_workspace.sh update <workspace_dir> <repo1> [<repo2> ...]
#
# 例:
#   # 新しいワークスペースを作成
#   bash setup_issue_workspace.sh create https://github.com/owner/repo/issues/123 frontend backend
#   
#   # 既存のワークスペースにリポジトリを追加
#   bash setup_issue_workspace.sh update $WORKSPACES_DIR/Feature_request_repo-123 api database

set -e

# 設定可能な変数
REPOSITORIES_DIR="${REPOSITORIES_DIR:-repositories}"  # リポジトリクローン先ディレクトリ
WORKSPACES_DIR="${WORKSPACES_DIR:-issues}"            # ワークスペース作成先ディレクトリ

# リポジトリの実際の所属組織名を検出する関数
detect_repo_org() {
  local repo_name="$1"
  
  # repositories/<org>/<repo> の構造から組織名を検索
  if [ -d "$REPOSITORIES_DIR" ]; then
    local found_org=""
    for org_dir in "$REPOSITORIES_DIR"/*; do
      if [ -d "$org_dir" ] && [ -d "$org_dir/$repo_name/.git" ]; then
        found_org=$(basename "$org_dir")
        echo "$found_org"
        return 0
      fi
    done
  fi
  
  # 見つからない場合は空文字列を返す
  echo ""
  return 1
}

# 使用方法を表示する関数
show_usage() {
  echo "Usage:"
  echo "  $0 create <issue_url> <repo1> [<repo2> ...]"
  echo "  $0 update <workspace_dir> <repo1> [<repo2> ...]"
  echo "  $0 update <repo1> [<repo2> ...]  # インタラクティブにワークスペースを選択"
  echo "  $0 update                        # 完全インタラクティブモード"
  echo ""
  echo "Examples:"
  echo "  # 新しいワークスペースを作成"
  echo "  $0 create https://github.com/owner/repo/issues/123 frontend backend"
  echo ""
  echo "  # 既存のワークスペースにリポジトリを追加（ディレクトリ指定）"
  echo "  $0 update \$WORKSPACES_DIR/Feature_request_repo-123 api database"
  echo ""
  echo "  # 既存のワークスペースにリポジトリを追加（リポジトリ指定でワークスペース選択）"
  echo "  $0 update api database"
  echo ""
  echo "  # 完全インタラクティブモード（ワークスペースとリポジトリを両方選択）"
  echo "  $0 update"
  echo ""
  echo "  # 既存のワークスペース一覧を表示"
  echo "  ls -la \$WORKSPACES_DIR/"
}

# 引数チェック
if [ $# -lt 1 ]; then
  show_usage
  exit 1
fi

COMMAND="$1"
shift

case "$COMMAND" in
  "create")
    if [ $# -lt 2 ]; then
      echo "[ERROR] createモードには少なくとも issue_url と repo1 が必要です"
      show_usage
      exit 1
    fi
    MODE="create"
    ISSUE_URL="$1"
    shift
    REPO_LIST=("$@")
    ;;
  "update")
    MODE="update"
    
    # 引数を保存（ワークスペース選択後もリポジトリリストを維持するため）
    ARGS=("$@")
    
    # 引数が全くない場合は、完全インタラクティブモード
    if [ $# -eq 0 ]; then
      echo "[INFO] インタラクティブモードでワークスペースとリポジトリを選択します"
      
      # ワークスペース選択
      echo "[INFO] 既存のワークスペース一覧:"
      if [ ! -d "$WORKSPACES_DIR" ]; then
        echo "  $WORKSPACES_DIR/ディレクトリが存在しません"
        exit 1
      fi
      
      mapfile -t workspaces < <(find "$WORKSPACES_DIR" -maxdepth 1 -type d -not -path "$WORKSPACES_DIR" | sort)
      
      if [ ${#workspaces[@]} -eq 0 ]; then
        echo "  既存のワークスペースが見つかりません"
        exit 1
      fi
      
      echo "  既存のワークスペース:"
      for i in "${!workspaces[@]}"; do
        echo "    $((i+1))) ${workspaces[i]}"
      done
      
      echo -n "  ワークスペースを選択してください (1-${#workspaces[@]}): "
      read -r selection
      
      if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#workspaces[@]} ]; then
        echo "[ERROR] 無効な選択です: $selection"
        exit 1
      fi
      
      WORKSPACE_DIR="${workspaces[$((selection-1))]}"
      echo "[INFO] 選択されたワークスペース: $WORKSPACE_DIR"
      
      # リポジトリ選択
      echo ""
      echo "[INFO] 追加するリポジトリを選択してください"
      
      # 既存リポジトリをチェック
      existing_repos_in_workspace=""
      if [ -d "$WORKSPACE_DIR" ]; then
        mapfile -t existing_repos_array < <(find "$WORKSPACE_DIR" -maxdepth 1 -type d -not -path "$WORKSPACE_DIR" | sort | xargs -I {} basename {})
        if [ ${#existing_repos_array[@]} -gt 0 ]; then
          existing_repos_in_workspace=" (既存: $(IFS=', '; echo "${existing_repos_array[*]}"))"
        fi
      fi
      
      echo "  現在のワークスペース${existing_repos_in_workspace}"
      echo -n "  追加するリポジトリをスペース区切りで入力: "
      read -r repo_input
      
      if [ -z "$repo_input" ]; then
        echo "[ERROR] リポジトリが指定されていません"
        exit 1
      fi
      
      # 入力されたリポジトリを配列に変換
      read -ra REPO_LIST <<< "$repo_input"
      
      # 重複チェック
      echo "[INFO] 重複チェックを実行中..."
      filtered_repos=()
      for repo in "${REPO_LIST[@]}"; do
        if [ -d "$WORKSPACE_DIR/$repo" ]; then
          echo "[WARN] $repo は既にワークスペースに存在します。スキップします。"
        else
          filtered_repos+=("$repo")
        fi
      done
      
      if [ ${#filtered_repos[@]} -eq 0 ]; then
        echo "[INFO] 追加する新しいリポジトリがありません。処理を終了します。"
        exit 0
      fi
      
      REPO_LIST=("${filtered_repos[@]}")
      echo "[INFO] 追加対象: ${REPO_LIST[*]}"
      
    # updateモードでワークスペースディレクトリが指定されていない場合、または存在しない場合
    elif [ ! -d "$1" ]; then
      
      echo "[INFO] 既存のワークスペース一覧:"
      if [ ! -d "$WORKSPACES_DIR" ]; then
        echo "  $WORKSPACES_DIR/ディレクトリが存在しません"
        exit 1
      fi
      
      # $WORKSPACES_DIR/ディレクトリ内のディレクトリ一覧を配列に格納
      mapfile -t workspaces < <(find "$WORKSPACES_DIR" -maxdepth 1 -type d -not -path "$WORKSPACES_DIR" | sort)
      
      if [ ${#workspaces[@]} -eq 0 ]; then
        echo "  既存のワークスペースが見つかりません"
        exit 1
      fi
      
      # ワークスペース選択メニュー（既存リポジトリ情報付き）
      echo "  既存のワークスペース:"
      for i in "${!workspaces[@]}"; do
        workspace="${workspaces[i]}"
        # ワークスペース内の既存リポジトリを取得
        existing_repos=""
        if [ -d "$workspace" ]; then
          mapfile -t repos < <(find "$workspace" -maxdepth 1 -type d -not -path "$workspace" | sort | xargs -I {} basename {})
          if [ ${#repos[@]} -gt 0 ]; then
            existing_repos=" [既存: $(IFS=', '; echo "${repos[*]}")]"
          fi
        fi
        echo "    $((i+1))) ${workspace}${existing_repos}"
      done
      
      echo -n "  ワークスペースを選択してください (1-${#workspaces[@]}): "
      read -r selection
      
      # 選択の検証
      if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#workspaces[@]} ]; then
        echo "[ERROR] 無効な選択です: $selection"
        exit 1
      fi
      
      WORKSPACE_DIR="${workspaces[$((selection-1))]}"
      echo "[INFO] 選択されたワークスペース: $WORKSPACE_DIR"
      
      # 全ての引数をリポジトリリストとして扱う
      REPO_LIST=("${ARGS[@]}")
    else
      # ワークスペースディレクトリが指定されている場合
      WORKSPACE_DIR="$1"
      shift
      if [ $# -eq 0 ]; then
        echo "[ERROR] 追加するリポジトリを指定してください"
        echo "使用方法: $0 update $WORKSPACE_DIR <repo1> [<repo2> ...]"
        echo "例: $0 update $WORKSPACE_DIR frontend api"
        exit 1
      fi
      REPO_LIST=("$@")
    fi
    ;;
  *)
    echo "[ERROR] 不明なコマンド: $COMMAND"
    show_usage
    exit 1
    ;;
esac

# createモードとupdateモードの処理を分岐
if [ "$MODE" = "create" ]; then
  # URLから org, repo, issue番号 を抽出
  if [[ "$ISSUE_URL" =~ github.com/([^/]+)/([^/]+)/issues/([0-9]+) ]]; then
    ORG_NAME="${BASH_REMATCH[1]}"
    REPO_NAME="${BASH_REMATCH[2]}"
    ISSUE_NUMBER="${BASH_REMATCH[3]}"
    echo "[INFO] 抽出された情報: 組織/ユーザー=$ORG_NAME, リポジトリ=$REPO_NAME, Issue番号=$ISSUE_NUMBER"
  else
    echo "[ERROR] issue URLの形式が不正です: $ISSUE_URL"
    exit 1
  fi

  echo "[INFO] ghコマンドでissueタイトルを取得中..."
  ISSUE_TITLE=$(gh issue view "$ISSUE_URL" --json title | jq -r .title)
  if [ -z "$ISSUE_TITLE" ] || [ "$ISSUE_TITLE" = "null" ]; then
    echo "[ERROR] ghコマンドでissueタイトル取得に失敗しました。gh認証やURLをご確認ください。"
    exit 1
  fi

  # ディレクトリ名生成（マルチバイト文字チェック）
  # 改行文字を除去してからチェック
  CLEAN_TITLE=$(echo "$ISSUE_TITLE" | tr -d '\n\r')
  if printf '%s' "$CLEAN_TITLE" | LC_ALL=C grep -q '[^ -~]'; then
    # マルチバイト文字が含まれている場合はissue番号のみ使用
    ISSUE_DIR="${REPO_NAME}-${ISSUE_NUMBER}"
  else
    # 英数字のみの場合は従来通り
    SAFE_TITLE=$(echo "$CLEAN_TITLE" | tr ' ' '_' | tr -cd '[:alnum:]_-')
    ISSUE_DIR="${SAFE_TITLE}_${REPO_NAME}-${ISSUE_NUMBER}"
  fi
  ISSUE_PATH="$WORKSPACES_DIR/$ISSUE_DIR"

  # ワークスペースディレクトリの状態をチェック
  if [ -d "$ISSUE_PATH" ]; then
    echo "[INFO] 既存のワークスペースディレクトリが見つかりました: $ISSUE_PATH"
    echo "[INFO] 新しいリポジトリを追加します..."
  else
    mkdir -p "$ISSUE_PATH"
    echo "[INFO] 新しいワークスペースディレクトリを作成しました: $ISSUE_PATH"
    
    # .issue-info ファイルを作成
    cat > "$ISSUE_PATH/.issue-info" <<EOF
ISSUE_URL="$ISSUE_URL"
ORG_NAME="$ORG_NAME"
REPO_NAME="$REPO_NAME"
ISSUE_NUMBER="$ISSUE_NUMBER"
ISSUE_TITLE="$ISSUE_TITLE"
SAFE_BRANCH_TITLE="$(echo "$ISSUE_TITLE" | tr ' ' '_' | tr -cd '[:alnum:]_-')"
EOF
    echo "[INFO] Issue情報を保存しました: $ISSUE_PATH/.issue-info"
  fi

elif [ "$MODE" = "update" ]; then
  # updateモード: 既存のワークスペースディレクトリを指定
  ISSUE_PATH="$WORKSPACE_DIR"
  
  # ワークスペースディレクトリの存在確認
  if [ ! -d "$ISSUE_PATH" ]; then
    echo "[ERROR] 指定されたワークスペースディレクトリが存在しません: $ISSUE_PATH"
    echo "[INFO] 既存のワークスペース一覧:"
    if [ -d "$WORKSPACES_DIR" ]; then
      ls -la "$WORKSPACES_DIR/"
    else
      echo "  $WORKSPACES_DIR/ディレクトリが存在しません"
    fi
    exit 1
  fi
  
  echo "[INFO] 既存のワークスペースを更新します: $ISSUE_PATH"
  
  # .issue-info ファイルからissue情報を読み取り
  ISSUE_INFO_FILE="$ISSUE_PATH/.issue-info"
  if [ -f "$ISSUE_INFO_FILE" ]; then
    echo "[INFO] Issue情報ファイルを読み込み中: $ISSUE_INFO_FILE"
    # shellcheck source=/dev/null
    source "$ISSUE_INFO_FILE"
    echo "[INFO] 読み込まれたissue情報: 組織=$ORG_NAME, リポジトリ=$REPO_NAME, Issue番号=$ISSUE_NUMBER"
    echo "[INFO] Issueタイトル: $ISSUE_TITLE"
  else
    echo "[WARN] Issue情報ファイルが見つかりません: $ISSUE_INFO_FILE"
    echo "[INFO] ワークスペース名から情報を推定します..."
    
    # ワークスペースディレクトリ名からissue情報を推定（フォールバック）
    BASENAME=$(basename "$ISSUE_PATH")
    if [[ "$BASENAME" =~ _([^-]+)-([0-9]+)$ ]]; then
      REPO_NAME="${BASH_REMATCH[1]}"
      ISSUE_NUMBER="${BASH_REMATCH[2]}"
      echo "[INFO] 推定されたissue情報: リポジトリ=$REPO_NAME, Issue番号=$ISSUE_NUMBER"
      
      # ワークスペース名から元のissueタイトルを推定
      if [[ "$BASENAME" =~ ^(.+)_[^-]+-[0-9]+$ ]]; then
        ORIGINAL_TITLE="${BASH_REMATCH[1]}"
        ISSUE_TITLE=$(echo "$ORIGINAL_TITLE" | tr '_' ' ')
        SAFE_BRANCH_TITLE=$(echo "$ISSUE_TITLE" | tr ' ' '_' | tr -cd '[:alnum:]_-')
        echo "[INFO] 推定されたissueタイトル: $ISSUE_TITLE"
      else
        ISSUE_TITLE="UpdateMode"
        SAFE_BRANCH_TITLE="UpdateMode"
        echo "[WARN] issueタイトルを推定できませんでした。UpdateModeを使用します"
      fi
    else
      REPO_NAME="unknown"
      ISSUE_NUMBER="0"
      ISSUE_TITLE="UpdateMode"
      SAFE_BRANCH_TITLE="UpdateMode"
      echo "[WARN] ワークスペース名からissue情報を推定できませんでした"
    fi
  fi
fi

# 処理サマリーを表示
echo ""
echo "=========================================="
echo "[INFO] ワークスペース更新処理を開始します"
echo "[INFO] ワークスペース: $ISSUE_PATH"
echo "[INFO] 追加対象リポジトリ: ${REPO_LIST[*]}"
echo "=========================================="
echo ""

# 処理結果を記録するための配列
declare -a SUCCESSFUL_REPOS
declare -a FAILED_REPOS
declare -a SKIPPED_REPOS

for repo in "${REPO_LIST[@]}"; do
  echo "------------------------------"
  echo "[INFO] リポジトリ: $repo を処理中..."
  
  # 各リポジトリの実際の所属組織名を検出
  REPO_ORG=$(detect_repo_org "$repo")
  
  if [ -z "$REPO_ORG" ]; then
    echo "[ERROR] リポジトリ '$repo' の所属組織を検出できませんでした"
    echo "以下のいずれかの構造でリポジトリが存在することを確認してください:"
    echo "  $REPOSITORIES_DIR/<org-name>/$repo/"
    echo "例: $REPOSITORIES_DIR/org-name/$repo/"
    echo "    $REPOSITORIES_DIR/company-name/$repo/"
    FAILED_REPOS+=("$repo")
    continue
  fi
  
  echo "[INFO] 検出された組織名: $REPO_ORG"
  
  SOURCE_REPO_PATH="$REPOSITORIES_DIR/$REPO_ORG/$repo"
  
  # リポジトリの存在確認
  if [ ! -d "$SOURCE_REPO_PATH/.git" ]; then
    echo "[ERROR] リポジトリが存在しません: $SOURCE_REPO_PATH"
    echo "事前に以下のようにリポジトリを準備してください:"
    echo "  git clone https://github.com/$REPO_ORG/$repo.git $SOURCE_REPO_PATH"
    FAILED_REPOS+=("$repo")
    continue
  fi
  cd "$SOURCE_REPO_PATH"
  git fetch
  # ブランチ名生成（マルチバイト文字チェック）
  if [ -z "$SAFE_BRANCH_TITLE" ]; then
    # 改行文字を除去してからチェック
    CLEAN_TITLE=$(echo "$ISSUE_TITLE" | tr -d '\n\r')
    if printf '%s' "$CLEAN_TITLE" | LC_ALL=C grep -q '[^ -~]'; then
      # マルチバイト文字が含まれている場合はissue番号のみ使用
      BRANCH_NAME="${REPO_NAME}-${ISSUE_NUMBER}"
    else
      # 英数字のみの場合は従来通り
      SAFE_BRANCH_TITLE=$(echo "$CLEAN_TITLE" | tr ' ' '_' | tr -cd '[:alnum:]_-')
      BRANCH_NAME="${REPO_NAME}-${ISSUE_NUMBER}/$SAFE_BRANCH_TITLE"
    fi
  else
    BRANCH_NAME="${REPO_NAME}-${ISSUE_NUMBER}/$SAFE_BRANCH_TITLE"
  fi
  # main または master ブランチをチェック
  DEFAULT_BRANCH=""
  if git rev-parse --verify main >/dev/null 2>&1; then
    DEFAULT_BRANCH="main"
  elif git rev-parse --verify master >/dev/null 2>&1; then
    DEFAULT_BRANCH="master"
  else
    echo "[ERROR] main または master ブランチが存在しません: $repo"
    FAILED_REPOS+=("$repo")
    cd - > /dev/null
    continue
  fi
  # worktree先ディレクトリ（絶対パス）：組織名を挟んだ新構造
  WORKTREE_PATH="$(pwd | sed 's|/repositories/.*||')/$ISSUE_PATH/$REPO_ORG/$repo"
  # 既存なら確認メッセージ
  if [ -d "$WORKTREE_PATH" ]; then
    echo "[WARN] $repo は既にワークスペースに存在します ($WORKTREE_PATH)。"
    echo "[INFO] スキップして次のリポジトリに進みます。"
    SKIPPED_REPOS+=("$repo")
    cd - > /dev/null
    continue
  fi
  # ブランチが存在しなければデフォルトブランチから作成
  if ! git show-ref --verify --quiet refs/heads/"$BRANCH_NAME"; then
    git branch "$BRANCH_NAME" "$DEFAULT_BRANCH"
  fi
  
  # 組織ディレクトリを作成（存在しない場合）
  ORG_DIR="$(pwd | sed 's|/repositories/.*||')/$ISSUE_PATH/$REPO_ORG"
  mkdir -p "$ORG_DIR"
  
  # worktree追加
  if git worktree add "$WORKTREE_PATH" "$BRANCH_NAME"; then
    echo "[INFO] $WORKTREE_PATH にworktree追加完了 (ブランチ: $BRANCH_NAME)"
    SUCCESSFUL_REPOS+=("$repo")
  else
    # 失敗した場合、孤立したworktreeがないかチェックして修復を試行
    echo "[WARN] $repo のworktree追加に失敗しました。孤立したworktreeをクリーンアップして再試行します..."
    git worktree prune 2>/dev/null || true
    if git worktree add "$WORKTREE_PATH" "$BRANCH_NAME"; then
      echo "[INFO] $WORKTREE_PATH にworktree追加完了 (ブランチ: $BRANCH_NAME) [復旧成功]"
      SUCCESSFUL_REPOS+=("$repo")
    else
      echo "[ERROR] $repo のworktree追加に失敗しました [復旧も失敗]"
      FAILED_REPOS+=("$repo")
    fi
  fi
  cd - > /dev/null
done

# 最終結果サマリーを表示
echo ""
echo "=========================================="
echo "[INFO] ワークスペース更新処理が完了しました"
echo "=========================================="

if [ ${#SUCCESSFUL_REPOS[@]} -gt 0 ]; then
  echo "[SUCCESS] 追加されたリポジトリ (${#SUCCESSFUL_REPOS[@]}個): ${SUCCESSFUL_REPOS[*]}"
fi

if [ ${#SKIPPED_REPOS[@]} -gt 0 ]; then
  echo "[SKIPPED] スキップされたリポジトリ (${#SKIPPED_REPOS[@]}個): ${SKIPPED_REPOS[*]}"
fi

if [ ${#FAILED_REPOS[@]} -gt 0 ]; then
  echo "[FAILED] 失敗したリポジトリ (${#FAILED_REPOS[@]}個): ${FAILED_REPOS[*]}"
fi

echo ""
echo "[INFO] ワークスペースの場所: $ISSUE_PATH"
if [ -d "$ISSUE_PATH" ]; then
  echo "[INFO] 現在のワークスペース内容:"
  for dir in "$ISSUE_PATH"/*/ ; do
    if [ -d "$dir" ]; then
      basename="$(basename "$dir")"
      echo "  - $basename"
    fi
  done
fi

echo "=========================================="
