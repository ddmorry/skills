---
status: accepted
date: 2026-07-08
---

# 設計段階のコンダクターは薄い進行役に徹し、flag 付きスキルはユーザーのスラッシュコマンドで発動する

設計段階のチェーン grill → to-prd → to-issues → to-design-doc → ship を完走させる `design-feature` スキルを導入する。前提となる制約は、mattpocock 群の `to-prd` / `to-issues`（と `setup-matt-pocock-skills`）が frontmatter の `disable-model-invocation: true` によりモデル（Skill ツール）から呼べないこと — ユーザーのスラッシュコマンド専用という上流の意図がある。かつて「設計チェーンはラップしない（スキル合成で足りる・発動条件が曖昧になる）」と決めたが、run-epic（AFK）の対になる進行役の需要から部分的に見直した。整合の条件として、コンダクターは**順序・現在地の検出（成果物ベース）・工程間の引き継ぎだけ**を持ち、各スキルの中身を複製しない。flag 付きスキルは要所でユーザーに `/to-prd` 等を打ってもらい（同一セッションなので文脈は繋がり、完了後にコンダクターが進行を再開する）、モデル発動可能なスキル（`grilling` / `domain-modeling` / `grill-yourself-with-docs` / `to-design-doc` / `ship`）だけを Skill ツールで直接呼ぶハイブリッドをとる。

## Considered Options

- **SKILL.md を Read して手順に従う（Read 運転）** — 上流更新が自動反映されフォークもしないが、「ユーザー専用」という flag の意図を迂回する。
- **方法論の埋め込み（grilling-agent 方式）** — 正本の二重化（CLAUDE.md の禁止事項）にあたり、上流更新に追従できない。
- **ラップしない（前回決定の維持）** — 合成で工程は踏めるが、工程間の引き継ぎ・現在地管理・完走の責任者が不在で、ユーザーがチェーンを暗記して毎回手で運転することになる。

## Consequences

- 完走には要所でユーザーのキー入力（`/setup-matt-pocock-skills`・`/to-prd`・`/to-issues`）が必要 — 設計段階はもともと HITL 前提（CONTEXT.md）なので許容する。
- 上流が flag を外せば、該当工程を Skill 呼び出しに置き換えるだけでよい（コンダクターの形は変わらない）。
- 人間チェックポイントは各スキル固有のものに委ね、コンダクターが追加する質問はルート確定（to-prd / to-design-doc の要否）の1問だけ。
- 状態はステートファイルではなく成果物（PRD Issue・スライス Issue・docs/design/）から検出するため、セッションをまたいだ再開が自然に成立する。

## Update (2026-07-09)

上流 mattpocock/skills が planning スキルを改名した: `to-prd` → `to-spec`（"spec"＝従来 PRD と呼んでいた文書。意味は不変）、`to-issues` → `to-tickets`（tracer-bullet スライスと blocking edges を明示する書き換えだが、成果物は依然 issue tracker の Issue で役割は同じ）。この ADR の判断（コンダクターは薄い進行役／flag 付きは user-invoked）は不変で、`design-feature` と `to-design-doc` の参照コマンド名だけを新名に追随させた（本文の旧名は当時の記録として残す）。ドリフトは `vendor-deps.json` ＋ `check-vendored-skills` で検知する（CLAUDE.md「上流 mattpocock/skills への依存追随」）。
