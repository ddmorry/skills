# soramichi-skills

SORAMICHI 社内で共有する Claude Code スキル集。

## 含まれるスキル

<!-- SKILLS -->

## インストール

### 方法 A: Claude Code プラグインとして入れる（推奨）

このリポジトリは Claude Code のプラグイン marketplace です。
marketplace を登録し、プラグインを install するだけで、含まれるスキルと同梱 subagent が一括で入ります。

```sh
# marketplace を登録（GitHub owner/repo 形式）
/plugin marketplace add soramichi-dev/soramichi-skills
# プラグインを install
/plugin install soramichi-skills@soramichi-skills
```

install 後、スキルはプラグイン名で名前空間化される（例: `/soramichi-skills:afk-build-feature`）。
モデルによる自動発動は description に従って従来どおり効く。更新は `/plugin marketplace update` で取得する。

チーム全体へ自動で配布したい場合は、対象リポジトリの `.claude/settings.json` に次を置く:

```json
{
  "extraKnownMarketplaces": {
    "soramichi-skills": {
      "source": { "source": "github", "repo": "soramichi-dev/soramichi-skills" }
    }
  },
  "enabledPlugins": {
    "soramichi-skills@soramichi-skills": true,
    "mattpocock-skills@soramichi-skills": true
  }
}
```

### 方法 B: symlink で入れる

プラグインの名前空間を避けて短いスキル名（`/afk-build-feature` など）で使いたい場合は、
スキル本体と（同梱の）sub-agent 定義をそれぞれ symlink する。
`<CLAUDE_CONFIG_DIR>` は個人グローバルなら `~/.claude`、リポジトリ分離環境なら各リポの config dir。

```sh
REPO="$(pwd)"   # このリポジトリを clone した場所
CFG="$HOME/.claude"   # 必要に応じて各リポの CLAUDE_CONFIG_DIR に変える
# スキル本体（ディレクトリごと symlink）
for s in "$REPO"/skills/*/; do
  ln -sfn "$s" "$CFG/skills/$(basename "$s")"
done
# sub-agent 定義（agents/ を持つスキルのみ・ファイル単位で symlink）
for a in "$REPO"/skills/*/agents/*.md; do
  [ -e "$a" ] && ln -sfn "$a" "$CFG/agents/$(basename "$a")"
done
```

## 依存スキル（別途セットアップ推奨）

一部のスキルは matt pocock 氏のスキルを Skill として呼び出す（未導入でもフォールバックで動くが、入れると最良）:

- `design-feature` → `grilling` / `domain-modeling` / `setup-matt-pocock-skills`（issue トラッカー初期化）
- `afk-build-feature` の coding-agent → `tdd` / `code-review`

これらは**同じ marketplace の 2 つ目のプラグイン `mattpocock-skills`** として同梱している。
`soramichi-skills` を install しても自動では入らない別プラグインなので、明示的に入れる:

```sh
/plugin install mattpocock-skills@soramichi-skills
```

settings.json で配布する場合は、方法 A の `enabledPlugins` に `"mattpocock-skills@soramichi-skills": true` を併記する。
プラグインを使わず素の CLI で入れたい場合は `npx skills@latest add mattpocock/skills` でも可。

未導入でも各スキルは簡易インライン処理／内蔵版（`grill-yourself-with-docs`）にフォールバックする。

スキルの用語・設計判断の背景（CONTEXT.md / ADR）は開発元リポジトリで管理している（配布物には含めない）。
