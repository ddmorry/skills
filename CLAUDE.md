# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## リポジトリの目的

ユーザーオリジナルの agent skills（Claude Code スキル）を開発・管理するリポジトリ。ビルド・テスト・lint の仕組みはない。成果物は Markdown で書かれたスキル定義そのもの。

## 構成

各スキルは `skills/<skill-name>/` に 1 ディレクトリずつ置く:

```
skills/
├── grill-with-docs/
│   ├── SKILL.md            ← スキル本体（必須）
│   ├── CONTEXT-FORMAT.md   ← SKILL.md から参照される補助ファイル
│   └── ADR-FORMAT.md
└── grill-yourself-with-docs/
    ├── SKILL.md
    └── agents/
        └── grilling-agent.md  ← スキルが使う sub-agent 定義（同梱パターン）
```

sub-agent を使うスキルは、agent 定義（`.claude/agents/*.md` 形式: frontmatter に `name` / `description` / `model` / `tools`）を `agents/` サブディレクトリに同梱し、SKILL.md の前提チェックで `~/.claude/agents/` へのインストールを自動補修する。

## SKILL.md の書式

- 先頭に YAML frontmatter で `name`（ディレクトリ名と一致させる）と `description` を書く。`description` はスキルの発動条件を決める最重要フィールドで、「何をするか」に加えて「いつ使うか（Use when ...）」を含める。
- 本文は progressive disclosure を意識する: SKILL.md には手順の核だけを書き、長い書式定義や参考資料は同ディレクトリの補助ファイルに切り出して相対リンク（例: `[CONTEXT-FORMAT.md](./CONTEXT-FORMAT.md)`）で参照する。

## 動作確認

このリポジトリに置いただけではスキルは発動しない。実際に使うには `~/.claude/skills/<skill-name>/` にコピー（またはシンボリックリンク）して、新しい Claude Code セッションで発動条件に合う指示を出して確認する。agent 定義を同梱するスキルは、加えて `agents/*.md` を `~/.claude/agents/` にコピーする。`~/.claude/skills/` 側と二重管理になるため、編集後はどちらが最新かを意識して同期すること。
