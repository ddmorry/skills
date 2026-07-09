#!/usr/bin/env bash
#
# publish-company-skills.sh
#
# code/skills（正本）→ code/soramichi/skills（会社共有ミラー, remote=soramichi-dev/soramichi-skills）
# への一方向ミラー同期。company-skills.txt に列挙されたスキルだけを対象にする。
#
# soramichi-dev は main への直接 push を禁止している（repository rule: "Changes must be made
# through a pull request"）。そのため --push は直接 push ではなく、
# 「ブランチ push → PR 作成 → squash マージ → ローカル main 同期」の PR フローで反映する。
#
# 使い方:
#   scripts/publish-company-skills.sh            # ミラー + ローカル commit（push しない）
#   scripts/publish-company-skills.sh --push     # 上記に加えて PR フローで origin/main へ反映（マージまで）
#   scripts/publish-company-skills.sh --dry-run  # 差分だけ表示（commit も push もしない）
#
# 環境変数:
#   DEST   ミラー先ディレクトリ（既定: <SRC の親>/soramichi/skills を code/ 基準で解決）
#
# 設計方針:
#   - SRC を唯一の正本とし、DEST は手編集しない純粋な下流ミラー。
#   - マニフェストから外れたスキルは DEST 側から prune（削除）される。
#   - スキル本体に加え、afk-build-feature / design-feature が「スキル開発リポジトリの
#     CONTEXT.md・docs/adr/ を正とする」と参照するため、CONTEXT.md と docs/adr/ も同梱する。
#   - DEST を Claude Code のプラグイン marketplace として配布するため、.claude-plugin/
#     （marketplace.json + plugin.json）も同梱する。正本側で編集し、ここで運ぶ。
#   - DEST は下流ミラーなので、実行のたび冒頭で origin/main に合わせ直す。前回 --push の PR が
#     squash マージされると origin/main はローカルと別ハッシュになり分岐するが、捨てるローカル
#     コミットの内容は正本から再生成されるので毎回 origin/main へリセットして分岐を吸収する。
#
# 注意（Claude セッションから実行する場合）:
#   --push はマージまで自動で行う。自分がそのセッションで作成した PR の squash マージは
#   Claude Code の自動モード分類器が「自己承認・レビューなしマージ」として止めるため、Claude 経由
#   だとマージ段階で停止することがある。その場合はユーザーが直接シェルで実行するか、表示された
#   gh コマンドを手で打つ（`gh pr merge <branch> --repo soramichi-dev/soramichi-skills --squash --delete-branch --admin`）。
set -euo pipefail

# --- パス解決 -----------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(cd "$SCRIPT_DIR/.." && pwd)"                       # = code/skills
DEST="${DEST:-$(cd "$SRC/.." && pwd)/soramichi/skills}" # 既定: code/soramichi/skills
MANIFEST="$SRC/company-skills.txt"
REMOTE_URL="https://github.com/soramichi-dev/soramichi-skills.git"
REPO_SLUG="soramichi-dev/soramichi-skills"
GIT_USER_NAME="Daisuke"
GIT_USER_EMAIL="daisuke_mori@sora-michi.com"

# --- 引数 ---------------------------------------------------------------------
DO_PUSH=0
DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --push)    DO_PUSH=1 ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

BASE_EXCLUDES=(--exclude='.DS_Store' --exclude='.git' --exclude='.orca' --exclude='node_modules')
RSYNC_DIR=(-a --delete "${BASE_EXCLUDES[@]}")   # ディレクトリ用（余剰ファイルを削除）
RSYNC_FILE=(-a "${BASE_EXCLUDES[@]}")           # 単一ファイル用（--delete なし）
if [ "$DRY_RUN" = 1 ]; then
  RSYNC_DIR+=(-n -v)
  RSYNC_FILE+=(-n -v)
fi

# --- マニフェスト読み込み -----------------------------------------------------
[ -f "$MANIFEST" ] || { echo "manifest not found: $MANIFEST" >&2; exit 1; }
mapfile -t SKILLS < <(grep -vE '^\s*(#|$)' "$MANIFEST" | tr -d '\r' | awk '{$1=$1};1')
[ "${#SKILLS[@]}" -gt 0 ] || { echo "manifest is empty" >&2; exit 1; }

echo "SRC   : $SRC"
echo "DEST  : $DEST"
echo "skills: ${SKILLS[*]}"
echo

# --- DEST ブートストラップ（初回のみ） ---------------------------------------
if [ ! -d "$DEST/.git" ]; then
  if [ "$DRY_RUN" = 1 ]; then
    echo "[dry-run] would git init + set remote at: $DEST"
  else
    echo "bootstrapping git repo at: $DEST"
    mkdir -p "$DEST"
    git -C "$DEST" init -q
    git -C "$DEST" remote add origin "$REMOTE_URL" 2>/dev/null \
      || git -C "$DEST" remote set-url origin "$REMOTE_URL"
    git -C "$DEST" config user.name  "$GIT_USER_NAME"
    git -C "$DEST" config user.email "$GIT_USER_EMAIL"
    # main ブランチ名を明示
    git -C "$DEST" symbolic-ref HEAD refs/heads/main 2>/dev/null || true
  fi
fi

# --- DEST を origin/main に合わせ直す（下流ミラーの分岐吸収） -----------------
# 前回 --push の PR が squash マージされると origin/main はローカル main と別ハッシュになる。
# DEST は正本から再生成される下流なので、毎回 origin/main へリセットしてから作業する。
if [ "$DRY_RUN" = 1 ]; then
  if git -C "$DEST" ls-remote --exit-code --heads origin main >/dev/null 2>&1; then
    echo "[dry-run] would fetch origin and reset local main to origin/main"
  fi
else
  git -C "$DEST" fetch origin --prune 2>/dev/null || true
  if git -C "$DEST" rev-parse --verify --quiet origin/main >/dev/null; then
    echo "sync local main to origin/main"
    # -B は working tree ごと origin/main に合わせる。この後 rsync で上書きされるので破壊的でよい。
    git -C "$DEST" checkout -q -B main origin/main
  fi
fi

# --- ミラー本体 ---------------------------------------------------------------
for s in "${SKILLS[@]}"; do
  [ -d "$SRC/skills/$s" ] || { echo "WARNING: manifest skill missing in SRC: $s" >&2; continue; }
  mkdir -p "$DEST/skills/$s"
  echo "sync skill: $s"
  rsync "${RSYNC_DIR[@]}" "$SRC/skills/$s/" "$DEST/skills/$s/"
done

# 注: CONTEXT.md / docs/adr は開発リポジトリ専用（スキルの語彙・設計の正本）であり、
# プラグイン配布物には含めない。スキルは本文の記述で自己完結して動作する。
# 過去に同梱していた残骸（CONTEXT.md / docs/）は後段の top-level prune で除去する。

# プラグイン marketplace 設定: .claude-plugin/（marketplace.json + plugin.json）
if [ -d "$SRC/.claude-plugin" ]; then
  mkdir -p "$DEST/.claude-plugin"
  echo "sync: .claude-plugin/"
  rsync "${RSYNC_DIR[@]}" "$SRC/.claude-plugin/" "$DEST/.claude-plugin/"
fi

# プラグイン用に subagent を top-level agents/ へ集約する。
# marketplace-root プラグイン（source: "./"）は skills/<name>/agents/ 配下を agent として
# 読み込まない（Agents:0 になる）。プラグイン install 経路では、既定スキャン先である
# リポジトリ直下の agents/ に置く必要がある。symlink install 経路（README 方法 B）は
# 従来どおり skills/<name>/agents/*.md を直接 symlink するので、ネストされた元ファイルも残す。
# stale 排除のため毎回作り直す。
shopt -s nullglob
AGENT_FILES=()
for s in "${SKILLS[@]}"; do
  for a in "$SRC/skills/$s/agents/"*.md; do AGENT_FILES+=("$a"); done
done
shopt -u nullglob
if [ "$DRY_RUN" = 1 ]; then
  [ "${#AGENT_FILES[@]}" -gt 0 ] && echo "[dry-run] would rebuild top-level agents/ from ${#AGENT_FILES[@]} subagent file(s)"
else
  rm -rf "$DEST/agents"
  if [ "${#AGENT_FILES[@]}" -gt 0 ]; then
    mkdir -p "$DEST/agents"
    echo "sync: agents/ (${#AGENT_FILES[@]} subagent を集約)"
    rsync "${RSYNC_FILE[@]}" "${AGENT_FILES[@]}" "$DEST/agents/"
  fi
fi

# --- prune: マニフェストに無いスキルを DEST から除去 --------------------------
if [ -d "$DEST/skills" ]; then
  for d in "$DEST/skills"/*/; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    keep=0
    for s in "${SKILLS[@]}"; do [ "$s" = "$name" ] && keep=1 && break; done
    if [ "$keep" = 0 ]; then
      if [ "$DRY_RUN" = 1 ]; then
        echo "[dry-run] would prune: skills/$name"
      else
        echo "prune (not in manifest): skills/$name"
        rm -rf "$d"
      fi
    fi
  done
fi

# --- top-level prune: プラグイン配布に不要なトップレベル項目を除去 -----------
# 残すのはプラグインに必要なものだけ。CONTEXT.md / docs / .orca などの残骸を削除する。
KEEP_TOP=(.git .gitignore .claude-plugin agents skills README.md)
shopt -s dotglob nullglob
for p in "$DEST"/*; do
  base="$(basename "$p")"
  keep=0
  for k in "${KEEP_TOP[@]}"; do [ "$base" = "$k" ] && keep=1 && break; done
  [ "$keep" = 1 ] && continue
  if [ "$DRY_RUN" = 1 ]; then
    echo "[dry-run] would prune top-level: $base"
  else
    echo "prune top-level (not for plugin): $base"
    rm -rf "$p"
  fi
done
shopt -u dotglob nullglob

# --- .gitignore 生成（毎回上書き） -------------------------------------------
if [ "$DRY_RUN" = 0 ]; then
  printf '%s\n' '.DS_Store' '.orca' 'node_modules' > "$DEST/.gitignore"
fi

# --- README 生成（teammate 向け・毎回上書き） --------------------------------
if [ "$DRY_RUN" = 0 ]; then
  {
    echo "# soramichi-skills"
    echo
    echo "SORAMICHI 社内で共有する Claude Code スキル集。"
    echo
    echo "> **このリポジトリは自動生成ミラーです。** 正本は個人リポジトリ側で管理され、"
    echo "> \`publish-company-skills\` により一方向で同期されます。**ここを直接編集しないでください**"
    echo "> （次回同期で上書きされます）。修正は正本リポジトリに入れてから再同期します。"
    echo
    echo "## 含まれるスキル"
    echo
    for s in "${SKILLS[@]}"; do
      desc="$(awk '/^description:/{sub(/^description:[[:space:]]*/,"");print;exit}' "$DEST/skills/$s/SKILL.md" 2>/dev/null | cut -c1-100)"
      echo "- \`$s\` — ${desc:-（説明なし）}…"
    done
    echo
    echo "## インストール"
    echo
    echo "### 方法 A: Claude Code プラグインとして入れる（推奨）"
    echo
    echo "このリポジトリは Claude Code のプラグイン marketplace です。"
    echo "marketplace を登録し、プラグインを install するだけで ${#SKILLS[@]} スキルと同梱 subagent が一括で入ります。"
    echo
    echo '```sh'
    echo '# marketplace を登録（GitHub owner/repo 形式）'
    echo '/plugin marketplace add soramichi-dev/soramichi-skills'
    echo '# プラグインを install'
    echo '/plugin install soramichi-skills@soramichi-skills'
    echo '```'
    echo
    echo "install 後、スキルはプラグイン名で名前空間化される（例: \`/soramichi-skills:afk-build-feature\`）。"
    echo "モデルによる自動発動は description に従って従来どおり効く。更新は \`/plugin marketplace update\` で取得する。"
    echo
    echo "チーム全体へ自動で配布したい場合は、対象リポジトリの \`.claude/settings.json\` に次を置く:"
    echo
    echo '```json'
    echo '{'
    echo '  "extraKnownMarketplaces": {'
    echo '    "soramichi-skills": {'
    echo '      "source": { "source": "github", "repo": "soramichi-dev/soramichi-skills" }'
    echo '    }'
    echo '  },'
    echo '  "enabledPlugins": {'
    echo '    "soramichi-skills@soramichi-skills": true'
    echo '  }'
    echo '}'
    echo '```'
    echo
    echo "### 方法 B: symlink で入れる"
    echo
    echo "プラグインの名前空間を避けて短いスキル名（\`/afk-build-feature\` など）で使いたい場合は、"
    echo "スキル本体と（同梱の）sub-agent 定義をそれぞれ symlink する。"
    echo "\`<CLAUDE_CONFIG_DIR>\` は個人グローバルなら \`~/.claude\`、リポジトリ分離環境なら各リポの config dir。"
    echo
    echo '```sh'
    echo 'REPO="$(pwd)"   # このリポジトリを clone した場所'
    echo 'CFG="$HOME/.claude"   # 必要に応じて各リポの CLAUDE_CONFIG_DIR に変える'
    echo '# スキル本体（ディレクトリごと symlink）'
    echo 'for s in "$REPO"/skills/*/; do'
    echo '  ln -sfn "$s" "$CFG/skills/$(basename "$s")"'
    echo 'done'
    echo '# sub-agent 定義（agents/ を持つスキルのみ・ファイル単位で symlink）'
    echo 'for a in "$REPO"/skills/*/agents/*.md; do'
    echo '  [ -e "$a" ] && ln -sfn "$a" "$CFG/agents/$(basename "$a")"'
    echo 'done'
    echo '```'
    echo
    echo "## 依存スキル（別途セットアップ推奨）"
    echo
    echo "一部のスキルは matt pocock 氏のスキルを Skill として呼び出す（未導入でもフォールバックで動くが、入れると最良）:"
    echo
    echo "- \`design-feature\` → \`grilling\` / \`domain-modeling\` / \`setup-matt-pocock-skills\`（issue トラッカー初期化）"
    echo "- \`afk-build-feature\` の coding-agent → \`tdd\` / \`code-review\`"
    echo
    echo "これらは GitHub のプラグインとしては配布されていないため、次で導入する:"
    echo
    echo '```sh'
    echo 'npx skills@latest add mattpocock/skills'
    echo '```'
    echo
    echo "未導入でも各スキルは簡易インライン処理／内蔵版（\`grill-yourself-with-docs\`）にフォールバックする。"
    echo
    echo "スキルの用語・設計判断の背景（CONTEXT.md / ADR）は開発元リポジトリで管理している（配布物には含めない）。"
  } > "$DEST/README.md"
fi

# --- commit -------------------------------------------------------------------
if [ "$DRY_RUN" = 1 ]; then
  echo; echo "[dry-run] 完了（変更は書き込んでいません）"
  exit 0
fi

cd "$DEST"
git add -A
if git diff --cached --quiet; then
  echo; echo "同期対象に新しい変更はありません。"
else
  SRC_SHA="$(git -C "$SRC" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  COUNT="${#SKILLS[@]}"
  git commit -q -m "sync: publish ${COUNT} skills from upstream@${SRC_SHA}

skills: ${SKILLS[*]}"
  echo; echo "committed: $(git rev-parse --short HEAD)"
fi

if [ "$DO_PUSH" = 0 ]; then
  echo "(push していません。確認後に --push で PR フロー反映するか、code/soramichi 配下で手動 PR を作成してください)"
  exit 0
fi

# --- PR フローで origin/main へ反映 -------------------------------------------
# soramichi-dev は main 直接 push 禁止のため、ブランチ push → PR 作成 → squash マージ → 同期。
SRC_SHA="$(git -C "$SRC" rev-parse --short HEAD 2>/dev/null || echo unknown)"

# 反映すべきコミットが origin/main に対してあるか
if git rev-parse --verify --quiet origin/main >/dev/null; then
  AHEAD="$(git rev-list --count origin/main..HEAD)"
else
  # origin にまだ main が無い（初回セットアップ）。PR の base が作れないので直接 push で初期化する。
  echo "origin に main がまだありません。初回セットアップとして main を直接 push します。"
  git push -u origin HEAD:main
  echo "pushed (initial main)."
  exit 0
fi

if [ "$AHEAD" = 0 ]; then
  echo; echo "origin/main と同一です。反映すべき差分がないため PR は作成しません。"
  exit 0
fi

MIRROR_SHA="$(git rev-parse --short HEAD)"
BRANCH="sync/mirror-${MIRROR_SHA}"
echo; echo "PR フローで反映します: branch=${BRANCH}（${AHEAD} commit）"

# ブランチを作って push（main 宛の直接 push ではないのでルールに触れない）
git checkout -q -B "$BRANCH"
git push -u origin "$BRANCH"

PR_URL="$(gh pr create --repo "$REPO_SLUG" --base main --head "$BRANCH" \
  --title "sync: publish ${#SKILLS[@]} skills from upstream@${SRC_SHA}" \
  --body "$(cat <<EOF
company-skills.txt に列挙されたスキルを正本（ddmorry/skills）からミラー同期します。

- upstream: ${SRC_SHA}
- skills: ${SKILLS[*]}

\`scripts/publish-company-skills.sh\` により自動生成されたミラーコミットです。

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)")"
echo "PR: $PR_URL"

# squash マージ（--admin: 1 人 admin 運用のため PR 必須ルールを bypass してマージ）。
# ※ Claude セッションから実行するとここで自己マージ分類器に止められることがある。
#   その場合は手動で: gh pr merge "$BRANCH" --repo "$REPO_SLUG" --squash --delete-branch --admin
echo "squash マージします ..."
gh pr merge "$BRANCH" --repo "$REPO_SLUG" --squash --delete-branch --admin

# ローカル main を origin/main（squash 後の新ハッシュ）に同期し、作業ブランチを掃除
git fetch origin --prune
git checkout -q -B main origin/main
git branch -D "$BRANCH" 2>/dev/null || true
echo "merged & synced: main = $(git rev-parse --short HEAD)"
