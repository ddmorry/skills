---
name: to-design-doc
description: 機能（Epic 相当）単位の Design Doc を1本合成し、対象リポジトリの docs/design/ に置いて各 Issue 本文から参照させる。to-tickets で Issue 分解が終わった後に使う。インタビューはせず、会話・PRD・Issue・コード探索から合成する（to-spec と同じ思想）。ユーザーが「design doc を作って」「デザインドックを書いて」「詳細設計を書いて/固めて」「Issue に設計を紐づけて」と言ったとき、または afk-build-feature（旧 build-feature / run-epic）への委譲前に下位モデルへ渡す詳細設計を用意したいときに使う。
argument-hint: "対象の Epic 番号 or Issue 番号列（省略時は会話中の機能）"
---

# To Design Doc — 委譲に耐える詳細設計を1本にまとめる

設計段階の最後のピース。PRD が「何を・なぜ」、ADR が「不可逆な決定」を持つのに対し、Design Doc は「**どう作るか**」を機能単位で1本にまとめ、実装を委譲される Coding Agent（下位モデル）が迷わない解像度まで落とす（ADR-0003）。

**インタビューはしない。** 要件の疑問は grill 段階で消化済みという前提で、既にある材料から合成する。合成中に本物の未確定設計判断が浮かんだら、推測で埋めずにユーザーへ指摘する（必要なら grill に戻る）。

## 前提

- Issue 分解が済んでいて Issue 番号が実在すること（slice 別セクションを実番号に対応付けるため）。未分解なら先に `to-tickets`。
- 会話に grill / PRD の文脈があること。無ければ Issue トラッカーから PRD・Epic を読む。

## Process

### 1. 材料を集める

- 対象の Issue 群を `gh` で読む（本文・Blocked by・Acceptance criteria）。
- PRD（あれば）・対象リポジトリの CONTEXT.md・関連 ADR を読む。用語は CONTEXT.md の語彙に従う。
- 触る領域のコードを探索し、既存のシーム・パターン・prefactoring の余地を把握する。

### 2. 合成する

[DESIGN-DOC-FORMAT.md](./DESIGN-DOC-FORMAT.md) の構成で書く。住み分けの規律:

- **PRD の再掲をしない**（What/Why は参照で済ませる）。
- **不可逆な決定を埋め込まない** — 書いていて ADR の3条件（不可逆・文脈なしでは不可解・実在したトレードオフ）を満たす決定が出てきたら、Design Doc に埋めず ADR を提案する。
- インターフェースの形・型・状態機械・スキーマなど **decision-rich な断片は歓迎**。網羅的なファイルパス列挙は避ける（すぐ古くなる）。

### 3. ユーザー確認

ドラフトを提示し、編集・承認を受ける。ここが設計段階最後の人間チェックポイント。

### 4. 書き込みと紐づけ

1. `docs/design/<feature-slug>.md` として対象リポジトリに書く（ディレクトリは無ければ作る）。
2. 各 Issue 本文に `gh issue edit` で参照セクションを追記する:

```
## Design doc

docs/design/<feature-slug>.md の「#<issue番号> <sliceタイトル>」セクション
```

### 5. 出荷の案内

Design Doc は**委譲開始前に origin/main に到達している必要がある**（afk-build-feature がプリフライトで確認する）。コミット・マージは通常の出荷フロー（afk-ship）に従う — このスキルでは push しない。ユーザーに「afk-ship してから afk-build-feature」と一言案内して終える。
