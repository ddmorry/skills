# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## リポジトリの目的

ユーザーオリジナルの agent skills（Claude Code スキル）を開発・管理するリポジトリ。ビルド・テスト・lint の仕組みはない。成果物は Markdown で書かれたスキル定義そのもの。

## 構成

各スキルは `skills/<skill-name>/` に 1 ディレクトリずつ置く:

```
skills/
├── design-feature/
│   └── SKILL.md               ← 補助ファイルなしの最小構成の例
├── ship/
│   ├── SKILL.md               ← スキル本体（必須）
│   └── agents/
│       └── ship-executor.md   ← スキルが使う sub-agent 定義（同梱パターン）
├── grill-yourself-with-docs/
│   ├── SKILL.md
│   └── agents/
│       └── grilling-agent.md  ← 同上
├── run-epic/
│   ├── SKILL.md
│   └── agents/
│       └── coding-agent.md    ← 同上（model: opus の実装委譲先）
└── to-design-doc/
    ├── SKILL.md
    └── DESIGN-DOC-FORMAT.md   ← 補助ファイル（書式定義）の例
```

リポジトリ直下には、スキル群が共有する語彙の正本 `CONTEXT.md` と、スキル設計上の決定を記録した `docs/adr/` がある。スキルを書く・直すときはこの2つに従う（用語は CONTEXT.md、委譲アーキテクチャ・受け入れゲート・Design Doc の形・設計段階コンダクターの形は ADR-0001〜0004）。

補助ファイル（書式定義や参考資料）を持つスキルは、それらも同じ `skills/<skill-name>/` 配下に置いて SKILL.md から相対リンクで参照する。

sub-agent を使うスキルは、agent 定義（`.claude/agents/*.md` 形式: frontmatter に `name` / `description` / `model` / `tools`）を `agents/` サブディレクトリに同梱する（そこが定義の唯一のソース。`~/.claude/agents/` へはシンボリックリンクを貼る — 次節参照）。

## SKILL.md の書式

- 先頭に YAML frontmatter で `name`（ディレクトリ名と一致させる）と `description` を書く。`description` はスキルの発動条件を決める最重要フィールドで、「何をするか」に加えて「いつ使うか（Use when ...）」を含める。
- 本文は progressive disclosure を意識する: SKILL.md には手順の核だけを書き、長い書式定義や参考資料は同ディレクトリの補助ファイルに切り出して相対リンク（例: `[CONTEXT-FORMAT.md](./CONTEXT-FORMAT.md)`）で参照する。

## インストールとリンク構造（オペレーションの前提・重要）

**このリポジトリが管理するスキルは、ここが唯一のソース**（何を管理しているかは次節「スキルの出所と管理範囲」）。Claude Code が実際に読むのは `~/.claude/` 配下だが、そこはこのリポジトリへの**シンボリックリンク**であり、コピーではない。したがって編集はリポジトリ側だけで完結し、リンク先に即反映される（**二重管理は発生しない** — かつてコピー運用だった名残の記述があれば、それは古い）。

現在のリンク構造（`ls -la` で確認できる）:

- **スキル本体**: `~/.claude/skills/<skill-name>` → `skills/<skill-name>/` への**ディレクトリごとのシンボリックリンク**。SKILL.md も補助ファイルもリンク先の実体を指すので、リポジトリを編集すればそのまま反映される。
  - 例: `~/.claude/skills/ship -> /Users/daisukemori/code/skills/skills/ship`
- **sub-agent 定義**: `~/.claude/agents/<agent-name>.md` → `skills/<skill-name>/agents/<agent-name>.md` への**ファイル単位のシンボリックリンク**。Agent ツールが解決する実体もこれ。
  - 例: `~/.claude/agents/ship-executor.md -> /Users/daisukemori/code/skills/skills/ship/agents/ship-executor.md`

（`~/.claude/skills/` には、このリポジトリ管理外の実ディレクトリのスキルや `../../.agents/skills/` 配下への別ソースのリンクも混在する。このリポジトリが管理するのは上記2種のシンボリックリンクだけ。）

### 新しいスキルを追加するときの手順

1. `skills/<skill-name>/SKILL.md`（agent 同梱なら `skills/<skill-name>/agents/*.md` も）を作る。
2. スキル本体をリンク: `ln -s /Users/daisukemori/code/skills/skills/<skill-name> ~/.claude/skills/<skill-name>`
3. agent 定義があれば各ファイルもリンク: `ln -s /Users/daisukemori/code/skills/skills/<skill-name>/agents/<agent>.md ~/.claude/agents/<agent>.md`
4. 新しい Claude Code セッションで発動条件に合う指示を出し、発動と動作を確認する（このリポジトリに置いただけでは発動しない）。

**コピーは作らないこと。** リンクさえ貼れば以降の編集はリポジトリ側だけで反映される。コピーを作るとどちらが最新か分からなくなる。既存スキルを直したときも、リンクが正しく張られていれば追加の同期作業は不要。

## スキルの出所と管理範囲（正本の所在）

`~/.claude/skills/` には複数の出所のスキルが同居している。**このリポジトリが正本（編集すべき本物）なのは以下の5つだけ**。それ以外は別ソースが正本なので、ここでは編集しない（`~/.claude/skills/` 側で直接いじっても上流に反映されず、再インストールで上書きされる）。どのスキルを触るときも「正本はどこか」を最初に確かめる。

| スキル | 正本（編集する場所） | `~/.claude` への現れ方・更新方法 |
|---|---|---|
| `ship` | **このリポジトリ** (`skills/ship/`) | `~/.claude/skills/ship` はここへの symlink。編集は即反映 |
| `grill-yourself-with-docs` | **このリポジトリ** (`skills/grill-yourself-with-docs/`) | 同上 |
| `run-epic` | **このリポジトリ** (`skills/run-epic/`) | 同上。旧版（メインセッション自身が実装する実ディレクトリ）は 2026-07 に委譲版へ刷新した際 symlink に置換済み |
| `to-design-doc` | **このリポジトリ** (`skills/to-design-doc/`) | 同上 |
| `design-feature` | **このリポジトリ** (`skills/design-feature/`) | 同上 |
| `caveman` / `diagnose` / `tdd` など一群 | **mattpocock/skills（上流・GitHub）** | `npx skills@latest add mattpocock/skills` でインストールした実ディレクトリ。更新も同コマンドの再実行で行う。ここで手編集しない |
| `orca-cli` / `computer-use` / `orchestration` | **Orca**（`~/.agents/skills/` 配下） | `~/.claude/skills/` から `../../.agents/skills/` への symlink。Orca 側が正本 |

- **CODEX**（`~/.codex/` に独自の `skills/` を持つ別システム）へのスキル同期は、現時点では本リポジトリの管理対象外（`skill-sync` スキルで扱うが、運用整理は別途）。
- 新しい**オリジナル**スキルを増やすときは、必ずこのリポジトリに置いて symlink する（前節の手順）。サードパーティ製スキルをこのリポジトリに取り込まない（正本が二重化するため）。
