---
name: design-feature
description: 設計段階（grill → to-spec → to-tickets → to-design-doc → ship）を完走させる対話型コンダクター。build-feature（AFK・無人）の対。既存スキルを複製せず順番に運転し、flag 付きスキル（to-spec / to-tickets）は要所でユーザーにスラッシュコマンドを打ってもらい、モデル発動可能なスキル（grilling / to-design-doc / ship）は直接呼ぶ。成果物検出で途中からの再開にも対応。ユーザーが「機能を設計して」「設計段階を回して」「設計パイプラインを回して」「grill から Issue 分解まで進めて」「build-feature（旧 run-epic）の準備をして」「Design Doc まで完走して」など、実装前の設計チェーンを通しで進める指示をしたとき必ずこのスキルを使う。
argument-hint: "設計したい機能の説明（途中再開時は PRD/Epic の Issue 番号。省略時は会話中の機能）"
---

# Design Feature — 設計段階を完走するコンダクター

build-feature（実装段階の AFK オーケストレータ）の対になる HITL コンダクター。機能（Feature）1件の設計段階チェーン grill → to-spec → to-tickets → to-design-doc → ship を、既存スキルを複製せずに順番に運転する。持ち物は3つだけ: **順序**・**現在地の検出**・**工程間の引き継ぎ**。実体の作業と人間チェックポイントは各工程のスキル自身が持つ。

用語は CONTEXT.md、方針の背景は docs/adr/0004（このスキルの形）と 0003（Design Doc）を正とする。

## 大原則

- **flag 付きスキルは代行しない**: `setup-matt-pocock-skills` / `to-spec` / `to-tickets` は `disable-model-invocation: true` で Skill ツールから呼べない（ユーザー専用）。案内して待ち、ユーザーがスラッシュコマンドを打つ → 同一セッションなので文脈を引き継いで走る → 完了を成果物で確認したら進行を再開する。中身を Read して代行することも、方法論を複製することもしない（ADR-0004）。
- **モデル発動可能なスキルは直接呼ぶ**: `grilling` / `domain-modeling` / `grill-yourself-with-docs` / `to-design-doc` / `ship` は Skill ツールで呼ぶ（`grilling`・`domain-modeling` は matt pocock スキル＝別途セットアップ。未導入時のフォールバックは工程1参照）。
- **コンダクターが増やす質問はルート確定の1問だけ**。人間チェックポイントは各スキル固有のもの（grill の対話・to-spec のシーム確認・to-tickets のスライス承認・to-design-doc のドラフト承認）に委ね、二重に確認しない。工程の境目は「✅ spec（PRD）起票済み。次は `/to-tickets` を打ってください」式の短い進行案内に徹する。

## 起動時

1. **前提検査**: 対象リポジトリに `docs/agents/issue-tracker.md`（setup-matt-pocock-skills の出力）が無ければ、「先に `/setup-matt-pocock-skills` を打ってください」と案内して待つ（`setup-matt-pocock-skills` 自体が未導入なら、README「依存スキル」の `npx skills@latest add mattpocock/skills` で入れてから）。完了を確認したら続行。
2. **現在地の検出**: ステートファイルは持たない。成果物そのものから現在地を推定する:
   - 会話（または引数の参照先）に grill 相当の要件整理があるか
   - トラッカーに PRD Issue があるか
   - スライス Issue（Epic 配下）が起票済みか
   - `docs/design/<feature>.md` があるか、origin/main に到達済みか（`git fetch origin` して確認）
   推定した現在地と残り工程を1メッセージで提示し、ユーザーの確認を得てから運転を始める。
3. **grill モードの選択**（grill 未了の場合のみ）: AskUserQuestion で選ぶ。会話に事前コンテキストが厚ければ self-grill を、薄ければ対話 grill を推奨にする。

## 工程

### 1. grill（要件整理）

- **対話 grill**: `grilling` スキルを `domain-modeling` 併用で運転（= grill-with-docs 相当。対象リポジトリの CONTEXT.md・ADR も書きながら進める）。**`grilling` / `domain-modeling` が未導入なら**、self-grill（`grill-yourself-with-docs`・方法論を内蔵し外部依存なし）に切り替えるか、対話しながら要点を直接 CONTEXT.md・ADR に書く簡易 grill で代替する（導入は README「依存スキル」の `npx skills@latest add mattpocock/skills`）。
- **self-grill**: `grill-yourself-with-docs` スキルを呼ぶ（可逆性3層の人間確認は同スキルの流儀どおり）。

### 2. ルート確定（コンダクター唯一の質問）

grill 完了後、機能の規模からルートを推奨し、AskUserQuestion で確定する:

- **to-spec の要否**: スライス4件以上が見込まれる大きめの機能 → to-spec を推奨。小さい機能は to-tickets 直行を推奨。
- **to-design-doc の要否**: 任意（ADR-0003）。委譲先の下位モデルが迷いそうな機能（複数スライスにまたがる設計・新しいインターフェース・状態機械など）なら推奨。

確定後はこのルートで進行し、途中で聞き直さない。

### 3. to-spec（ルートで選んだ場合）

「`/to-spec` を打ってください」と案内して待つ。spec（PRD）Issue の起票を確認したら次へ。

### 4. to-tickets

「`/to-tickets` を打ってください」と案内して待つ。スライス Issue の起票を確認したら次へ。

### 5. to-design-doc（ルートで選んだ場合）

`to-design-doc` スキルを Skill ツールで呼ぶ。材料集め〜ドラフト承認〜Issue 紐づけは同スキルの手順どおり。

### 6. ship（Design Doc を作った場合）

`ship` スキルで `docs/design/` の変更を出荷し、origin/main 到達を確認する（= build-feature のプリフライトが通る状態。QA は「非該当: 設計文書のみ」）。

## 完走と締め

終点は「**スライス Issue 起票済み ＋（作った場合）Design Doc が origin/main に到達**」。締めに要約 — 確定したルート・起票した Issue 一覧・Design Doc のパス — を出し、「次は build-feature（`Epic を回して` 等）」と案内して終わる。**build-feature は発動しない**（AFK ロングランの開始は別の意思決定）。

## 留意

- ユーザーが案内と違う操作をしたら通常どおり応じ、その後に現在地を再検出して進行へ戻る。
- 途中でセッションが切れても、再発動すれば成果物検出で同じ場所から再開できる。
- 対象リポジトリで発動すること（トラッカー・docs/ は対象リポジトリのものを使う）。
