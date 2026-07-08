---
status: accepted
date: 2026-07-08
---

# マージ前に受け入れゲートを挟む（Coding Agent は PR 作成まで）

旧 run-epic は `mergePolicy = full-auto`（ゲート緑で即 squash マージ、PR で止めない）をユーザー合意済みの既定としていた。委譲版 run-epic ではこれを**廃止**し、Coding Agent は PR 作成までで停止、メインセッションが受け入れ（PR diff を Acceptance criteria・Design Doc・ADR と突合し、ゲートが実際に走ったかを検証）してから squash マージする。実装主体が下位モデルに変わったため、不良実装が main に入って後続 Issue がその上に積まれるリスクを、実装よりはるかに安い受け入れレビューで遮断するのが狙い。

## Considered Options

- **full-auto 踏襲** — スループット最大だが、受け入れ段階が形骸化し、巻き戻しコストが高くつく。
- **難易度別の使い分け** — 「どちらのモードだったか」の判断基準と運用が複雑化し、事故は単純 Issue でも起きる。

## Consequences

- マージは受け入れ律速で直列化する（意図した設計。受け入れは diff 精読が中心でコスト小）。
- 受け入れの深さは設計突合が標準。コードスタイル級の再レビューはしない（Coding Agent 側の code-review に委ねる）。難所のみ実テストを追加し、UI は smoke 未リストで人間 QA へ回す。
- 差し戻しは同一 Issue につき 2 回まで。3 回目は停止して人間へエスカレーションする。
