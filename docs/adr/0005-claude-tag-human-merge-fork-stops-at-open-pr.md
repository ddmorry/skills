---
status: accepted
date: 2026-07-09
---

# Claude Tag 版の機能開発は open PR で停止し人間がマージする（build-feature を既定に）

`afk-build-feature` は「Issue 群を無人で連続実装し main へ squash マージまで」進めるローカル前提の AFK スキル。これを Claude Tag（Claude in Slack）向けに、**1 Issue を実装して open PR で停止し、マージは人間が行う** `build-feature` スキルへ fork する。かつ `build-feature` を機能開発の**既定**、`afk-build-feature` を「AFK・複数 Issue・マージまで」と明示したときだけ発動する変種に位置づける。

理由: Claude Tag は使い捨て ephemeral sandbox で動き、GitHub App identity が **PR を開く**のが基本挙動。配布先の `soramichi-dev` は main 直 push 禁止・レビュー必須なので、無人マージはそもそも成立せず、チャネルに PR を出して teammate がレビュー＆マージする Claude Tag のモデルと整合させる。AFK ロングラン／worktree 並列は 1 スレッド使い捨て sandbox（idle で解放）と相性が悪く、Issue 単位で PR を出す形に寄せる。実装の内側ループ（1 Issue を委譲 → ゲート → open PR → 受け入れ）は afk-build-feature と共通で、既存の `coding-agent`（PR 作成で停止・マージしない）を**改変せず再利用**する。背景は [docs/claude-tag-distribution.md](../claude-tag-distribution.md)。

## Considered Options

- **1 スキル＋`afk` オプションでモード分岐** — 入口は 1 つになるが、(1) 最も危険な自動マージ権能を既定スキルが常時抱え、リスクゲートが skill 境界から runtime 分岐（軟）に後退する、(2) AFK は default の上に orchestration 層（Epic 解決・dep graph・並列・レーン・人間キュー・merge→ready 再計算）を載せた superset で終点も違い、フラグで畳むと既定パスが長大な分岐に埋もれる、(3) 内側ループは既に coding-agent に factor out 済みで DRY の利得は薄い。`afk-` 接頭辞を「無人・マージまで・運用限定」の警告シグナルとして使う既存方針（afk-ship）とも合わない。
- **単一エージェント（メインが自分で実装）** — coding-agent を使わず SKILL.md に実装ループを再掲することになり、`coding-agent` が内蔵する上流 `implement` の vendored コピーが二重化する（CLAUDE.md が禁ずる正本の二重化・ドリフト検知の対象が増える）。

## Consequences

- 発動は description で分岐する: 「この Issue を実装して」「機能を実装して」「PR を出して」など単一 Issue の通常フローは `build-feature`、「AFK で」「Epic を回して」「連続でマージして」など複数 Issue を無人でマージまで進める明示指示のときだけ `afk-build-feature`。両 description に相互の振り分けを明記して衝突を防ぐ。
- `build-feature` は `coding-agent` の複製を持たず、`afk-build-feature` 同梱の共有 agent を参照する。会社共有では両スキルの同時配布が前提（publish 時にルート `agents/` へ集約されるのは `company-skills.txt` 記載スキルの `agents/` 配下なので、`afk-build-feature` が一覧にある限り coding-agent が供給される）。
- 委譲時に worktree 分離（`isolation`）は使わない（1 Issue・sandbox が隔離）。並列・人間キュー・自動マージは持たない。
- QUESTION は可逆性で層別化し、不可逆・ADR 級だけ Slack スレッドで人間に確認する（ADR-0001 の質疑往復・grill-yourself-with-docs の層別化と同じ思想）。受け入れゲート（ADR-0002）は維持し、メインが open PR を Acceptance criteria・Design Doc と突合してから「ready to merge」で停止する。
