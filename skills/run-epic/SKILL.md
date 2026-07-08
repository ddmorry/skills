---
name: run-epic
description: Epic 配下（または指定した Issue 群）の AFK Issue を依存順に連続実装する無人ロングランのオーケストレータ。実装はメインセッションでは行わず、Issue 1件ごとに Coding Agent（Opus subagent・worktree 分離）へ委譲し、メインセッションは委譲・質疑の裁定・受け入れ（PR diff と設計成果物の突合）・squash マージに徹する。HITL Issue は人間キューに積んで AFK レーンは続行する。ユーザーが「Epic を回して」「連続実装して」「Issue を次々マージして」「AFK で全部やって」「Epic #N を実装して」「この Issue 群を委譲して」「ロングランで走らせて」など、Issue 群を無人で進める指示をしたとき必ずこのスキルを使う。
argument-hint: "Epic の Issue 番号 or URL、または Issue 番号列（例: #250 / #12 #13 #15）"
---

# Run Epic — Issue 群を Coding Agent に委譲して連続実装する

Epic（または指定 Issue 群）の AFK Issue を依存順に、人の介在なしにマージまで運ぶ。`issue-dep-graph` と同梱の `coding-agent`（[agents/coding-agent.md](./agents/coding-agent.md)）を**合成するオーケストレータ**であり、メインセッション自身はコードを書かない。役割は3つ: **委譲**・**質疑の裁定**・**受け入れとマージ**。

用語（委譲・差し戻し・ゲート・AFK/HITL・人間キュー・smoke 未リスト）はスキル開発リポジトリの CONTEXT.md、方針の背景は同 docs/adr/0001〜0003 を正とする。

## 既定ポリシー（ユーザー合意済み・起動時の指示で上書き可）

- **maxParallel = 3**: 同時に走らせる Coding Agent の上限。
- **selfFixBudget = 3**: Coding Agent 内でのゲート失敗の自己修正上限（委譲プロンプトで渡す）。
- **reworkBudget = 2**: 受け入れ不合格の差し戻しは同一 Issue につき2回まで。3回目は停止して人間へ。
- **redelegateBudget = 1**: Coding Agent がエラー死・迷走したら新規 worktree で再委譲1回まで。
- **受け入れ = 設計突合中心**: コードスタイル級の再レビューはしない（agent 側の code-review に委ねる）。難所のみ実テストを追加。
- **マージは受け入れ後**: Coding Agent は PR 作成まで。full-auto merge はしない（ADR-0002）。
- 終点は**マージ**。デプロイ等の本番操作はこのスキルでは行わない。

## 起動時（1回だけ）

1. **Issue 集合の解決**: 入力が Epic なら、各 Issue 本文の `## Parent` が当該 Epic を指すものを `gh` で列挙（Epic 本文のスライス一覧とも突き合わせる）。Issue 番号列ならそれをそのまま使う。
2. **依存解決**: `issue-dep-graph` を呼び、`## Blocked by` から着手順と「いま着手可能」集合を出す。
3. **Design Doc プリフライト**: Issue 本文が `## Design doc` を参照している場合、`git fetch origin` 後に参照先が origin/main に存在するか確認。無ければ**開始前に停止**し、先に出荷（ship）するよう促す。
4. **ゲートコマンドの解決**: 対象リポジトリの CLAUDE.md → `docs/agents/` → package.json の scripts の順で test / lint / build 相当を特定。見つからなければ `npm test` / `npm run lint` / `npm run build` を既定とする。解決結果は委譲プロンプトに明示して渡す（agent に推測させない）。
5. **coding-agent の可用性確認**: agent 一覧に `coding-agent` が無ければ、このスキルの base dir から `agents/coding-agent.md` を `~/.claude/agents/coding-agent.md` へ symlink する（file watching で反映される）。それでも使えない場合のみ `subagent_type: "general-purpose"` + `model: "opus"` に agent 定義本文を委譲プロンプト冒頭へ貼り込む。SendMessage が deferred なら ToolSearch でロードしておく。
6. 解決した Issue 一覧・着手順・上記ポリシーを**1メッセージで提示してから即開始**（承認は待たない＝AFK。ユーザーはインタラプトで止められる）。

## 委譲（着手可能な AFK Issue ごと）

- 着手可能集合から AFK Issue を選ぶ。**同じ領域（モジュール・ファイル群）を触りそうな slice は依存が無くても直列化**し、maxParallel の範囲で委譲する。
- Agent ツールで起動: `subagent_type: "coding-agent"`（model 指定不要 — frontmatter の `model: opus` が効く）、`isolation: "worktree"`、`run_in_background: true`。
- 委譲プロンプトはこのテンプレートを埋める（agent は会話履歴を見られない — 必要な材料を全部入れる）:

```
Issue: #{{N}}（gh で本文とコメントを読むこと）
Design Doc: {{docs/design/….md の「…」セクション | なし}}
ゲート: {{解決済みコマンド列}}
selfFixBudget: {{3}}
リポジトリ規約: {{対象リポジトリ CLAUDE.md の要点（テストの流儀・コミット言語など）}}
補足: {{領域の注意・関連 ADR/CONTEXT.md の所在など。無ければ省略}}
```

- 各委譲の agent ID を Issue 番号に紐づけて控える（差し戻し・rebase 指示・質問回答はすべて SendMessage で同じ agent に送る）。

## 進行ループ（通知が来るたびに）

**HITL Issue に当たったら**: 着手せず人間キューに積み、**proactive 通知**する。それに依存しない AFK レーンは続行。HITL にブロックされたチェーンだけ待機。節目（受け入れ・マージのたび）に `gh` でラベル/クローズ状態を再確認し、処理済みなら着手可能集合を再計算する。ユーザーの申告でも即再計算。

**Coding Agent から QUESTION が来たら**（可逆性で層別化 — grill-yourself-with-docs と同じ思想）:

- **可逆（詳細化・Design Doc の補完・Issue 解釈の明確化）**: 既存 ADR・PRD の意図と矛盾しない範囲でメインセッションが即断し、SendMessage で回答。正本への反映は (a) Issue 本文への追記（`gh issue edit`・即時）と (b) Design Doc への反映（run 終了時にまとめて出荷）の二段構え。裁定内容は進捗報告に含めて事後報告する。
- **不可逆・ADR の変更・PRD の意図変更**: AskUserQuestion で人間に確認してから回答・反映する。

**REPORT（PR 作成完了）が来たら受け入れへ**。

## 受け入れ（Issue 1件ごと）

- [ ] `gh pr diff` で PR 全文を読む。
- [ ] Issue の Acceptance criteria を1項目ずつ突合。
- [ ] Design Doc の該当セクション・関連 ADR・CONTEXT.md の語彙と矛盾しないか確認。
- [ ] テストが Issue の要求どおり追加されているか。**実装を写しただけのテスト・通すためのテスト改変がないか**を diff で確認。
- [ ] 報告されたゲート結果に不審があるとき、難所・コア機能のとき、自らテストしたいときは、PR ブランチでゲートを再実行して検証。
- [ ] UI を含む変更は「smoke 未リスト」に記録（自動ゲートでは確認できないため人間 QA へ回す）。

**合格** → `gh pr merge --squash --delete-branch`（PR 本文の `Closes #N` で Issue 自動クローズ）→ ready 集合を再計算して次を委譲。マージで PR がコンフリクトしたら該当 agent に SendMessage で rebase を指示し、force-push 後にマージし直す。

**不合格** → SendMessage で**具体的な修正指示**を添えて差し戻す（reworkBudget まで）。

## 停止して人間の承認を求める条件（HITL ゲート）

下記に当たったら**そのレーンを止め**（他レーンは可能な限り続行）、Orca 管理下の worktree なら `orca worktree set --worktree current --workspace-status in-review` でレビュー待ちに切り替えてから（コマンド失敗しても停止と通知は続行）、**proactive に通知**して理由と選択肢を提示する:

- reworkBudget / redelegateBudget を超過した。
- Coding Agent の QUESTION が不可逆・ADR 級で、人間の判断が要る。
- rebase 指示でも解消しない設計衝突レベルのコンフリクト。
- 本番・不可逆操作（デプロイ・マイグレーション・secret・データ削除）が要求される。
- 着手可能な AFK が尽きたが、HITL・停止にブロックされた未完 Issue が残る。

## 報告

- Issue 境界ごと（委譲・受け入れ・マージ）に短い進捗。停止時と全体完了時は **proactive 通知**。
- run 末尾に要約: 完了 Issue（PR/マージ）・残り Issue・**人間キュー**（HITL・エスカレーション）・**smoke 未リスト**・裁定した質疑の一覧・Design Doc への反映待ち差分（あれば出荷まで面倒を見る）。

## 留意

- 言語は日本語（コミット/PR/コメント）。コミット/PR フッターはハーネス指示どおり（agent 定義にも同旨を記載済み）。
- lockfile は Linux 生成のプロジェクト（bi-studio）で macOS 差分を混入させない。
- worktree では `gh pr merge --delete-branch` のローカル後処理が失敗してもマージは成立する（既知）。
