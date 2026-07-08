---
status: accepted
date: 2026-07-08
---

# 実装委譲は同一セッションの Opus subagent で行う

メインセッションの上位モデル（Fable 5）は使用枠の消費が激しく、実装作業まで担うとすぐに枯渇する。そこで実装段階を実行コストの低いモデル（Opus 4.8）に委譲するが、その実行形態として **同一 Claude Code セッション内の subagent**（同梱 agent 定義 `model: opus`、`isolation: worktree`、background 起動、SendMessage で質疑往復）を採用する。ship-executor / grilling-agent で確立済みのパターンであり、完了通知が自動でメインに戻り、実装中の質問・設計変更依頼を SendMessage の往復で扱える。

## Considered Options

- **Orca で独立セッションを spawn** — コンテキストが完全に独立し人間が UI から直接覗けるが、メインセッションからの制御が terminal 経由のポーリングになり脆く、監視自体が Fable 5 のトークンを消費する。
- **Workflow ツールのパイプライン** — 並列制御は強力だが `agent()` が一発実行で、実装途中の質疑応答・設計変更の往復ができず、停止条件の判断がスクリプトに固定化される。

## Consequences

- Coding Agent は 1 Issue = 1 起動でスコープを最小化し、並列時は worktree 分離で作業衝突を防ぐ。
- subagent は `disable-model-invocation: true` のスキル（`implement` 等）を Skill ツールで呼べない（公式ドキュメントで確認済み）。よって薄いループは agent 定義に埋め込み、モデル発動可能な `tdd` / `code-review` のみ実行時に Skill 呼び出しするハイブリッド結合をとる。
