# Agent Skills 開発

ユーザーオリジナルの Claude Code スキルを開発するリポジトリ。この語彙は、設計を上位モデル（メインセッション）が行い、実装を下位モデルの subagent へ委譲する開発パイプラインを記述する。

## Language

### パイプラインの段階

**設計段階（Design Stage）**:
要件整理（grill）から PRD・Issue 分解・Design Doc 作成までを、メインセッションが人間と対話して行う段階。
_Avoid_: 企画フェーズ

**実装段階（Implementation Stage）**:
Coding Agent が委譲された Issue を実装し、ゲートを緑にして PR を作成するまでの段階。
_Avoid_: 開発フェーズ

**受け入れ段階（Acceptance Stage）**:
メインセッションが PR を設計成果物と突合し、マージ可否を判断する段階。人間の最終確認（HITL）はこの段階の末尾に位置する。
_Avoid_: 検収, レビューフェーズ

### 登場者と成果物

**Coding Agent**:
実装段階を担う実装専任の subagent。設計判断はせず、設計上の矛盾や曖昧さに当たったらメインセッションへ問いを返す。
_Avoid_: 実装エージェント, coder, worker

**Design Doc**:
機能単位で1本書かれる「どう作るか」の詳細設計文書。slice 別の設計セクションを含む。PRD（何を・なぜ）とも ADR（不可逆な決定の記録）とも役割が異なる。
_Avoid_: 設計書, 詳細設計書, スペック

**機能（Feature）**:
grill → PRD → Issues → Design Doc の一連のチェーンで扱う開発の単位。Issue トラッカー上の親 Issue を指すときは Epic と呼ぶ。
_Avoid_: プロジェクト

### 委譲の運用

**委譲（Delegation）**:
メインセッションが Issue 1件の実装を Coding Agent に引き渡すこと。委譲の単位は常に Issue 1件。
_Avoid_: アサイン, ディスパッチ

**差し戻し（Rework）**:
受け入れ不合格の PR を、修正指示付きで元の Coding Agent に返すこと。
_Avoid_: リジェクト

**ゲート（Gate）**:
実装完了を機械的に判定する自動チェック一式（テスト・lint・ビルド）。緑であることは委譲完了の必要条件であって十分条件ではない（受け入れが残る）。
_Avoid_: CI チェック

**AFK Issue / HITL Issue**:
triage ラベルによる Issue の二分類。AFK（`ready-for-agent`）は人間の介在なしにエージェントが完遂できる Issue、HITL（`ready-for-human`）は人間の実装・判断が必要な Issue。

**人間キュー（Human Queue）**:
ロングラン中に発生した、人間の対応待ち項目（HITL Issue・エスカレーション・smoke 未）の一覧。ここに積まれても AFK レーンは止まらない。

**smoke 未リスト**:
自動ゲートでは確認できない、人間のブラウザ確認待ちの UI 変更一覧。人間キューの一種。
