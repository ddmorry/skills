#!/usr/bin/env bash
# check-vendored-skills.sh
#
# vendor-deps.json に pin した mattpocock/skills 依存の「上流ドリフト」を検知する。
# ローカルでも CI（.github/workflows/check-vendored-skills.yml）でも同じロジックで動く。
#
#   check-vendored-skills.sh                     検知してレポートを stdout に出す
#                                                （exit 0 = 全て一致 / exit 3 = ドリフトあり）
#   check-vendored-skills.sh --bump              vendored の pin を上流 HEAD に更新する
#                                                （2ファイルへの port が完了した後に叩く）
#   check-vendored-skills.sh --upstream-dir DIR  既存の上流 clone を再利用（省略時は都度 clone）
#
# 検知するもの:
#   - vendored : upstreamPath のサブツリーハッシュが pinnedTreeHash と変わったら
#                「内蔵コピーの port が要る」。上流 diff（pin→現在）を添えて報告する。
#   - referenced: upstreamPath/SKILL.md が上流から消えたら「リネーム/削除で参照が壊れる」。
#                （内容の変化は実行時呼び出しで自己修復するので、存在だけを監視する。）
#
# 照合の基準は「上流の最新リリースタグ（vX.Y.Z）」であって main HEAD ではない。
# `npx skills@latest add mattpocock/skills` が入れるのは最新リリースなので（インストール
# 実体の skillFolderHash が v タグのサブツリーハッシュと一致することを確認済み）、release
# 前の main の変更で誰も入れていない差分を誤検知しないよう、最新 v タグに揃える
# （v タグが無いリポジトリでは HEAD にフォールバック）。
#
# 依存: git, jq
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PIN="$REPO_ROOT/vendor-deps.json"

BUMP=0
UPSTREAM_DIR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --bump) BUMP=1 ;;
    --upstream-dir) UPSTREAM_DIR="${2:-}"; shift ;;
    -h|--help) sed -n '2,/^set /{/^set /d;s/^# \{0,1\}//;p;}' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done

command -v jq  >/dev/null 2>&1 || { echo "jq が必要です"  >&2; exit 2; }
command -v git >/dev/null 2>&1 || { echo "git が必要です" >&2; exit 2; }
[ -f "$PIN" ] || { echo "$PIN が見つかりません" >&2; exit 2; }

URL="$(jq -r '.upstream.url'  "$PIN")"
REPO="$(jq -r '.upstream.repo' "$PIN")"

# --- 上流を用意（--upstream-dir 未指定なら full clone。古い pin tree を diff するため shallow にしない） ---
CLEANUP=""
if [ -z "$UPSTREAM_DIR" ]; then
  UPSTREAM_DIR="$(mktemp -d)"
  CLEANUP="$UPSTREAM_DIR"
  git clone --quiet "$URL" "$UPSTREAM_DIR" || { echo "上流の clone に失敗: $URL" >&2; exit 2; }
fi
trap '[ -n "$CLEANUP" ] && rm -rf "$CLEANUP"' EXIT
up() { git -C "$UPSTREAM_DIR" "$@"; }

# --- 照合の基準 ref を決める（HEAD ではなく最新リリースタグ。理由は冒頭コメント参照） ---
REF="$(up tag -l 'v*' --sort=-v:refname | head -1)"
if [ -n "$REF" ]; then
  # 注釈付きタグはタグオブジェクト sha を返すので ^{commit} でコミット sha を表示する
  REF_LABEL="$REF ($(up rev-parse --short "$REF^{commit}"))"
else
  REF="HEAD"
  REF_LABEL="HEAD (リリースタグ無し)"
fi

# --- bump モード: vendored の pin を上流の最新リリースタグに更新して終了 ---
if [ "$BUMP" = 1 ]; then
  tmp="$(mktemp)"; cp "$PIN" "$tmp"
  n="$(jq '.vendored | length' "$PIN")"
  for i in $(seq 0 $((n - 1))); do
    path="$(jq -r ".vendored[$i].upstreamPath" "$PIN")"
    newtree="$(up rev-parse "$REF:$path" 2>/dev/null || echo "")"
    newcommit="$(up log -1 --format=%H "$REF" -- "$path" 2>/dev/null || echo "")"
    [ -z "$newtree" ] && { echo "上流に $path が無い（bump 中止）" >&2; rm -f "$tmp"; exit 2; }
    jq --argjson i "$i" --arg t "$newtree" --arg c "$newcommit" \
       '.vendored[$i].pinnedTreeHash=$t | .vendored[$i].pinnedCommit=$c' "$tmp" > "$tmp.2" && mv "$tmp.2" "$tmp"
  done
  mv "$tmp" "$PIN"
  echo "vendored の pin を上流リリース $REF_LABEL に更新しました。" >&2
  echo "referenced のリネーム/削除は自動では直せません（参照側スキルの手当てが要ります）。" >&2
  exit 0
fi

# --- 検知モード ---
DRIFT=0
REPORT="$(mktemp)"
{
  echo "## 上流 \`$REPO\` のドリフト検知"
  echo
  echo "- 照合基準: \`$REF_LABEL\`（\`npx skills@latest\` が入れる最新リリース）"
  echo "- 生成: \`scripts/check-vendored-skills.sh\`"
  echo
} > "$REPORT"

# vendored: サブツリーハッシュの一致を見る
vhit=0
n="$(jq '.vendored | length' "$PIN")"
for i in $(seq 0 $((n - 1))); do
  name="$(jq -r ".vendored[$i].name" "$PIN")"
  path="$(jq -r ".vendored[$i].upstreamPath" "$PIN")"
  local="$(jq -r ".vendored[$i].localFile" "$PIN")"
  pinned="$(jq -r ".vendored[$i].pinnedTreeHash" "$PIN")"
  cur="$(up rev-parse "$REF:$path" 2>/dev/null || echo MISSING)"
  [ "$cur" = "$pinned" ] && continue
  DRIFT=1; vhit=1
  {
    echo "### 🔁 内蔵コピー要 port: \`$name\`"
    echo
    echo "- port 先: \`$local\`"
    if [ "$cur" = MISSING ]; then
      echo "- ⚠️ 上流から \`$path\` が消えた（リネーム/削除）。内蔵元の所在を確認すること。"
    else
      echo "- pin \`${pinned:0:12}\` → 上流 \`${cur:0:12}\`"
      echo
      echo "<details><summary>上流 diff（pin → 現在）</summary>"
      echo
      echo '```diff'
      if up cat-file -e "$pinned" 2>/dev/null; then
        up diff "$pinned" "$cur" | head -400
      else
        echo "(pin tree $pinned が clone に無いため diff 省略。上流を直接確認)"
      fi
      echo '```'
      echo "</details>"
    fi
    echo
  } >> "$REPORT"
done
[ "$vhit" = 0 ] && { echo "_内蔵コピー（vendored）: すべて pin と一致_"; echo; } >> "$REPORT"

# referenced: SKILL.md の存在だけを見る（リネーム/削除の検知）
rmiss=0
n="$(jq '.referenced | length' "$PIN")"
for i in $(seq 0 $((n - 1))); do
  name="$(jq -r ".referenced[$i].name" "$PIN")"
  path="$(jq -r ".referenced[$i].upstreamPath" "$PIN")"
  usedby="$(jq -r ".referenced[$i].usedBy | join(\", \")" "$PIN")"
  up cat-file -e "$REF:$path/SKILL.md" 2>/dev/null && continue
  if [ "$rmiss" = 0 ]; then
    { echo "### 🔗 参照先が上流から消えた（リネーム/削除の疑い）"; echo; } >> "$REPORT"
    rmiss=1; DRIFT=1
  fi
  echo "- \`$name\`（\`$path\`）— 参照元: $usedby" >> "$REPORT"
done
if [ "$rmiss" = 1 ]; then
  {
    echo
    echo "<details><summary>現在の上流スキル一覧（新名を探す手掛かり）</summary>"
    echo
    echo '```'
    for d in $(up ls-tree --name-only "$REF" skills/); do
      base="$(basename "$d")"
      echo "$base:"
      up ls-tree --name-only "$REF:$d" 2>/dev/null | sed 's/^/  /'
    done
    echo '```'
    echo "</details>"
    echo
  } >> "$REPORT"
else
  { echo "_参照先（referenced）: すべて上流に存在_"; echo; } >> "$REPORT"
fi

if [ "$DRIFT" = 1 ]; then
  {
    echo "---"
    echo "### 対応手順"
    echo "1. 上記 diff を該当ファイルへ手で port（vendored）／参照名を新名に直す（referenced）。"
    echo "2. \`vendor-deps.json\` の referenced パスを更新（リネーム時）。"
    echo "3. \`scripts/check-vendored-skills.sh --bump\` で vendored の pin を上流 HEAD に更新。"
    echo "4. \`publish-company-skills\` スキルで会社ミラーへ反映（PR フロー）。"
  } >> "$REPORT"
fi

cat "$REPORT"
rm -f "$REPORT"

if [ "$DRIFT" = 1 ]; then
  echo "ドリフト検知: 対応が要ります（上のレポート参照）" >&2
  exit 3
fi
echo "上流と一致: 対応不要" >&2
exit 0
