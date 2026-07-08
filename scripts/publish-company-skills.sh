#!/usr/bin/env bash
#
# publish-company-skills.sh
#
# code/skills（正本）→ code/soramichi/skills（会社共有ミラー, remote=soramichi-dev/soramichi-skills）
# への一方向ミラー同期。company-skills.txt に列挙されたスキルだけを対象にする。
#
# 使い方:
#   scripts/publish-company-skills.sh            # ミラー + ローカル commit（push しない）
#   scripts/publish-company-skills.sh --push     # 上記に加えて origin へ push
#   scripts/publish-company-skills.sh --dry-run  # 差分だけ表示（commit も push もしない）
#
# 環境変数:
#   DEST   ミラー先ディレクトリ（既定: <SRC の親>/soramichi/skills を code/ 基準で解決）
#
# 設計方針:
#   - SRC を唯一の正本とし、DEST は手編集しない純粋な下流ミラー。
#   - マニフェストから外れたスキルは DEST 側から prune（削除）される。
#   - スキル本体に加え、build-feature / design-feature が「スキル開発リポジトリの
#     CONTEXT.md・docs/adr/ を正とする」と参照するため、CONTEXT.md と docs/adr/ も同梱する。
#   - DEST を Claude Code のプラグイン marketplace として配布するため、.claude-plugin/
#     （marketplace.json + plugin.json）も同梱する。正本側で編集し、ここで運ぶ。
set -euo pipefail

# --- パス解決 -----------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$(cd "$SCRIPT_DIR/.." && pwd)"                       # = code/skills
DEST="${DEST:-$(cd "$SRC/.." && pwd)/soramichi/skills}" # 既定: code/soramichi/skills
MANIFEST="$SRC/company-skills.txt"
REMOTE_URL="https://github.com/soramichi-dev/soramichi-skills.git"
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

# --- ミラー本体 ---------------------------------------------------------------
for s in "${SKILLS[@]}"; do
  [ -d "$SRC/skills/$s" ] || { echo "WARNING: manifest skill missing in SRC: $s" >&2; continue; }
  mkdir -p "$DEST/skills/$s"
  echo "sync skill: $s"
  rsync "${RSYNC_DIR[@]}" "$SRC/skills/$s/" "$DEST/skills/$s/"
done

# 共有支援ファイル: CONTEXT.md, docs/adr/
if [ -f "$SRC/CONTEXT.md" ]; then
  echo "sync: CONTEXT.md"
  rsync "${RSYNC_FILE[@]}" "$SRC/CONTEXT.md" "$DEST/CONTEXT.md"
fi
if [ -d "$SRC/docs/adr" ]; then
  mkdir -p "$DEST/docs/adr"
  echo "sync: docs/adr/"
  rsync "${RSYNC_DIR[@]}" "$SRC/docs/adr/" "$DEST/docs/adr/"
fi

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
    echo "marketplace を登録し、プラグインを install するだけで 5 スキルと同梱 subagent が一括で入ります。"
    echo
    echo '```sh'
    echo '# marketplace を登録（GitHub owner/repo 形式）'
    echo '/plugin marketplace add soramichi-dev/soramichi-skills'
    echo '# プラグインを install'
    echo '/plugin install soramichi-skills@soramichi-skills'
    echo '```'
    echo
    echo "install 後、スキルはプラグイン名で名前空間化される（例: \`/soramichi-skills:build-feature\`）。"
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
    echo "プラグインの名前空間を避けて短いスキル名（\`/build-feature\` など）で使いたい場合は、"
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
    echo "スキルの語彙は \`CONTEXT.md\`、設計判断の背景は \`docs/adr/\` を参照。"
  } > "$DEST/README.md"
fi

# --- commit / push -----------------------------------------------------------
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
  COUNT="$(printf '%s\n' "${SKILLS[@]}" | wc -l | tr -d ' ')"
  git commit -q -m "sync: publish ${COUNT} skills from upstream@${SRC_SHA}

skills: ${SKILLS[*]}"
  echo; echo "committed: $(git rev-parse --short HEAD)"
fi

if [ "$DO_PUSH" = 1 ]; then
  echo "pushing to origin/main ..."
  git push -u origin HEAD:main   # 未 push のコミットがあれば送る（無ければ up-to-date）
  echo "pushed."
else
  echo "(push していません。確認後に --push で実行するか、code/soramichi 配下で git push してください)"
fi
