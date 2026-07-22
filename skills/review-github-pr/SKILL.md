---
name: review-github-pr
description: GitHubのPRをレビューし、GitHub上にインラインコメントを投稿する。再レビュー時は既存の指摘の解消状況も確認する。
argument-hint: [PR URL]
allowed-tools: mcp__github__pull_request_read, mcp__github__pull_request_review_write
disable-model-invocation: true
---

以下のGitHub PRをレビューしてください。

対象PR: $ARGUMENTS

## 手順

### 0. 既存のレビュー状況を確認する

`pull_request_read`(method: get_review_comments)で、このPRに既に付いている
レビューコメント・スレッドを取得する。

- 各スレッドについて、resolved / unresolved の状態を確認する
- unresolved のスレッドは「まだ解消されていない指摘」として一旦記憶しておく
- (初回レビューでコメントが1件もない場合は、このステップは実質スキップでよい)

### 1. 現在のdiffを取得する

`pull_request_read`(method: get_diff / get_files)で、現在のPRの差分を取得する。

### 2. コードレビューを行う

以下の観点でレビューする:

- バグ・ロジックの誤り
- パフォーマンス上の懸念
- 命名・可読性
- セキュリティ上の懸念
- 既存のコーディング規約との整合性

### 3. 既存の unresolved スレッドの解消状況をチェックする

ステップ0で取得した unresolved スレッドについて、それぞれ:

- スレッドの指摘内容と、現在のコード(ステップ1のdiff)を突き合わせる
- 意味的に修正が確認できる場合:
  - **「Critical」「Security」に関する指摘は自動でresolveしない**
    → 「修正されているように見える」旨をチャット上の報告に残すだけにする
  - それ以外の指摘は `pull_request_review_write`(method: resolve_thread)で
    スレッドを解決済みにする
- 修正が確認できない場合は、そのスレッドには何もしない(重複コメントは追加しない)

resolveする場合は、必ず次の3点を後でチャットに報告できるよう記録しておく:
1. 元の指摘内容
2. 該当コードの現在の状態
3. resolveと判断した理由

### 4. 新規の指摘をコメントとして追加する

ステップ2で見つかった指摘のうち、まだ既存スレッドで扱われていない新規のものだけを対象に:

1. `pull_request_review_write`(method: create)で pending review を作成する
2. 指摘ごとに `pull_request_review_write`(method: add_comment_to_pending_review)を呼び、
   該当ファイル・行(diffに含まれる変更行であること)にコメントを追加する
3. すべて追加し終えたら `pull_request_review_write`(method: submit_pending)で
   `COMMENT` イベントとしてレビューを送信する
   - `REQUEST_CHANGES` や `APPROVE` にはしない(最終判断は人間が行うため)

### 5. 結果をチャット上に要約する

以下を報告する:

- 新規に追加した指摘コメントの件数と概要
- resolveしたスレッドの一覧(元の指摘 / 現在のコード / resolve理由)
- Critical・Securityに関する指摘で「修正されているように見えるがresolveしなかったもの」の一覧
- 未解決のまま残っているスレッドの一覧
