#!/usr/bin/env bash
# update_all_repositories.sh
# 指定ディレクトリ以下の全リポジトリを一括で最新化するスクリプト

# 設定可能な変数
REPOSITORIES_DIR="${REPOSITORIES_DIR:-repositories}"  # リポジトリディレクトリ
DEFAULT_BRANCH="${DEFAULT_BRANCH:-master}"            # デフォルトブランチ
MAX_DEPTH="${MAX_DEPTH:-3}"                           # 最大探索深度
TIMEOUT_SECONDS=1800                                  # タイムアウト時間（秒、デフォルト30分）
SCRIPT_START_TIME=$(date +%s)                         # スクリプト開始時刻

# 使用方法を表示
show_usage() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  -d, --directory DIR    リポジトリディレクトリを指定 (デフォルト: $REPOSITORIES_DIR)"
  echo "  -b, --branch BRANCH    デフォルトブランチを指定 (デフォルト: $DEFAULT_BRANCH)"
  echo "  -m, --max-depth DEPTH  最大探索深度を指定 (デフォルト: $MAX_DEPTH)"
  echo "  -h, --help            この使用方法を表示"
  echo ""
  echo "Environment Variables:"
  echo "  REPOSITORIES_DIR       リポジトリディレクトリ (デフォルト: repositories)"
  echo "  DEFAULT_BRANCH         デフォルトブランチ (デフォルト: master)"
  echo "  MAX_DEPTH              最大探索深度 (デフォルト: 3)"
  echo ""
  echo "Examples:"
  echo "  $0                                    # デフォルト設定で実行"
  echo "  $0 -d my-repos                       # カスタムディレクトリで実行"
  echo "  $0 -b main                           # mainブランチを使用"
  echo "  $0 -m 2                              # 探索深度2で実行"
  echo "  REPOSITORIES_DIR=repos $0            # 環境変数で設定"
}

# 引数解析
while [[ $# -gt 0 ]]; do
  case $1 in
    -d|--directory)
      REPOSITORIES_DIR="$2"
      shift 2
      ;;
    -b|--branch)
      DEFAULT_BRANCH="$2"
      shift 2
      ;;
    -m|--max-depth)
      MAX_DEPTH="$2"
      shift 2
      ;;
    -h|--help)
      show_usage
      exit 0
      ;;
    *)
      echo "不明なオプション: $1"
      show_usage
      exit 1
      ;;
  esac
done

echo "=========================================="
echo "リポジトリ一括更新スクリプト"
echo "対象ディレクトリ: $REPOSITORIES_DIR"
echo "デフォルトブランチ: $DEFAULT_BRANCH"
echo "最大探索深度: $MAX_DEPTH"
echo "タイムアウト時間: $((TIMEOUT_SECONDS / 60))分"
echo "=========================================="
echo ""

# ディレクトリの存在確認
if [ ! -d "$REPOSITORIES_DIR" ]; then
  echo "[ERROR] ディレクトリが存在しません: $REPOSITORIES_DIR"
  echo "環境変数REPOSITORIES_DIRまたは-dオプションで正しいパスを指定してください"
  exit 1
fi

# 処理統計用の変数
declare -i TOTAL_REPOS=0
declare -i UPDATED_REPOS=0
declare -i SKIPPED_REPOS=0
declare -i ERROR_REPOS=0
declare -a SKIPPED_LIST=()
declare -a ERROR_LIST=()

# タイムアウトをチェックする関数
check_timeout() {
  local current_time=$(date +%s)
  local elapsed=$((current_time - SCRIPT_START_TIME))

  if [ $elapsed -gt $TIMEOUT_SECONDS ]; then
    echo ""
    echo "=========================================="
    echo "[警告] タイムアウト時間（$((TIMEOUT_SECONDS / 60))分）に達しました"
    echo "処理を中止します"
    echo "=========================================="
    return 1
  fi
  return 0
}

# リポジトリ処理を行う関数
process_repository() {
  local repo_path="$1"
  local repo_name
  repo_name=$(basename "$repo_path")

  # タイムアウト確認
  if ! check_timeout; then
    return
  fi

  TOTAL_REPOS=$((TOTAL_REPOS + 1))
  echo "=============================="
  echo "リポジトリ: $repo_name ($repo_path)"
  
  cd "$repo_path" || {
    echo "[ERROR] ディレクトリに移動できませんでした: $repo_path"
    ERROR_REPOS=$((ERROR_REPOS + 1))
    ERROR_LIST+=("$repo_name")
    return
  }
  
  # 現在のブランチを確認
  current_branch=$(git branch --show-current 2>/dev/null || echo "不明")
  echo "現在のブランチ: $current_branch"
  
  echo "fetch中..."
  if ! timeout 30 git fetch; then
    echo "[ERROR] fetchに失敗しました（タイムアウト含む）"
    ERROR_REPOS=$((ERROR_REPOS + 1))
    ERROR_LIST+=("$repo_name")
    cd - > /dev/null || true
    return
  fi
  
  # デフォルトブランチの存在確認
  if git rev-parse --verify "$DEFAULT_BRANCH" >/dev/null 2>&1; then
    # ローカル変更がある場合は警告
    if ! git diff-index --quiet HEAD --; then
      echo "[警告] ローカルに未コミットの変更があります。"
      echo "変更内容:"
      git status --porcelain
      echo "$DEFAULT_BRANCH への切り替えをスキップします。"
      SKIPPED_REPOS=$((SKIPPED_REPOS + 1))
      SKIPPED_LIST+=("$repo_name (未コミットの変更)")
    else
      echo "$DEFAULT_BRANCH ブランチにcheckout中..."
      if git checkout "$DEFAULT_BRANCH"; then
        # メインのpullを実行（submoduleは含めない）
        echo "$DEFAULT_BRANCH でpull実行"
        if timeout 60 git pull --no-recurse-submodules; then
          echo "[SUCCESS] メインリポジトリの更新完了"
          UPDATED_REPOS=$((UPDATED_REPOS + 1))

          # submoduleが存在する場合は状態を同期（非ブロッキング）
          if [ -f ".gitmodules" ] && [ -s ".gitmodules" ]; then
            echo "submodule状態同期中..."
            if git submodule update --init 2>/dev/null; then
              echo "[OK] submodule同期完了"
            else
              echo "[WARNING] submodule同期に失敗しました（メインリポジトリは更新済み）"
            fi
          fi
        else
          echo "[ERROR] pullに失敗しました"
          ERROR_REPOS=$((ERROR_REPOS + 1))
          ERROR_LIST+=("$repo_name")
        fi
      else
        echo "[ERROR] チェックアウトに失敗しました"
        ERROR_REPOS=$((ERROR_REPOS + 1))
        ERROR_LIST+=("$repo_name")
      fi
    fi
  else
    echo "[警告] $DEFAULT_BRANCH ブランチが存在しません。このリポジトリはスキップします。"
    echo "利用可能なブランチ:"
    git branch -a | head -5
    SKIPPED_REPOS=$((SKIPPED_REPOS + 1))
    SKIPPED_LIST+=("$repo_name ($DEFAULT_BRANCH ブランチなし)")
  fi
  echo ""
  cd - > /dev/null || true
}

# 再帰的にディレクトリを探索する関数
find_repositories() {
  local search_dir="$1"
  local current_depth="$2"

  # タイムアウト確認
  if ! check_timeout; then
    return
  fi

  if [ "$current_depth" -gt "$MAX_DEPTH" ]; then
    return
  fi

  for item in "$search_dir"/*; do
    if [ -d "$item" ]; then
      if [ -d "$item/.git" ]; then
        # Gitリポジトリが見つかった場合
        process_repository "$item"
      else
        # 通常のディレクトリの場合、再帰的に探索
        find_repositories "$item" $((current_depth + 1))
      fi
    fi
  done
}

# 探索開始
find_repositories "$REPOSITORIES_DIR" 1


# 処理結果サマリー
echo ""
echo "=========================================="
echo "処理結果サマリー"
echo "=========================================="
echo "総リポジトリ数: $TOTAL_REPOS"
echo "更新成功: $UPDATED_REPOS"
echo "スキップ: $SKIPPED_REPOS"
echo "エラー: $ERROR_REPOS"

if [ ${#SKIPPED_LIST[@]} -gt 0 ]; then
  echo ""
  echo "スキップされたリポジトリ:"
  for item in "${SKIPPED_LIST[@]}"; do
    echo "  - $item"
  done
fi

if [ ${#ERROR_LIST[@]} -gt 0 ]; then
  echo ""
  echo "エラーが発生したリポジトリ:"
  for item in "${ERROR_LIST[@]}"; do
    echo "  - $item"
  done
fi

echo ""
echo "処理完了！"

# 終了コード
if [ $ERROR_REPOS -gt 0 ]; then
  exit 1
else
  exit 0
fi
