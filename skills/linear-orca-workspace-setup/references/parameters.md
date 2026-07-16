# パラメータと legal-dock 実例

セットアップの最初に、この業務ワークスペースの**パラメータ**を確定させる。以降の手順（Linear チーム作成・repo 雛形・doc テンプレートのプレースホルダ埋め・dispatcher 実行）は、すべてここで決めた値で駆動する。

## 対応モデル（worktree 階層）

worktree の階層を Linear の階層に合わせる。**永続の作業単位は Project**（Issue ではない）:

| worktree 階層 | Linear | Orca worktree / git branch | 寿命 |
| --- | --- | --- | --- |
| root | `{{PARENT_TEAM}}`（親チーム） | `{{REPO}}` main / `main` | 永続（repo baseline・横断/基盤） |
| 1階層目 | `{{CHILD_TEAM}}`（子チーム = lane） | `{{CHILD_TEAM}}` lane worktree / `{{CHILD_TEAM}}` | 永続（main のポインタ） |
| 2階層目 | **Linear Project** | `proj-<slug>` worktree / `proj-<slug>` | **Project と同じ期間・存続** |
| 3階層目（任意） | 大きめの **Issue** | `{{CHILD_KEY_LC}}-n` worktree / `{{CHILD_KEY_LC}}-n` | 短命（大きめ issue のときだけオンデマンド） |

- 通常の issue は **Project worktree の中**で作業する（issue ごとに worktree を切らない）。Project は一定期間継続するので Project worktree も存続し、issue が閉じても文脈が残る。
- 「一定期間の大きめ作業」が要る issue のときだけ、その Project worktree の下に Issue worktree をオンデマンドで切る。

## パラメータ一覧

| プレースホルダ | 意味 | 制約・決め方 | legal-dock の値 |
| --- | --- | --- | --- |
| `{{DOMAIN}}` | 業務ドメイン名（日本語） | 表示用。README/doc の説明文に使う | 法務 |
| `{{REPO}}` | リポジトリ名 | Orca に登録される正典 repo 名。`soramichi-<domain>-dock` 慣例 | `soramichi-legal-dock` |
| `{{WORKSPACE}}` | Linear workspace slug | issue URL `https://linear.app/<slug>/...` の slug | `soramichi` |
| `{{PARENT_TEAM}}` | 親チーム名 | repo 全体＝横断・基盤・非案件業務。慣例 `<domain>-dept` | `legal-dept` |
| `{{PARENT_KEY}}` | 親チーム identifier | Linear が採る issue 接頭辞（`LEG-1` 等） | `LEG` |
| `{{CHILD_TEAM}}` | 子チーム名（= lane 名） | **git ブランチ名として妥当な形**（小文字・ハイフン）。個別依頼レーン。慣例 `biz-<domain>` | `biz-legal` |
| `{{CHILD_KEY}}` | 子チーム identifier | issue 接頭辞（`BIZ-5` 等・大文字） | `BIZ` |
| `{{CHILD_KEY_LC}}` | 子 identifier の小文字 | 大きめ issue のオンデマンド worktree/ブランチ名（`biz-5`）に使う。`{{CHILD_KEY}}` の小文字化 | `biz` |
| `{{WORK_DIR}}` | 作業単位ディレクトリ | 子チームに対応する repo 内ディレクトリ（**1 Project = 1 サブディレクトリ**） | `matters` |
| `{{DIR_NAMING}}` | サブディレクトリ命名規則 | **Project 1件ごと**のディレクトリ名の規則。業務に合わせて決める | `YYYYMMDD_相手方_案件種別` |
| `{{LABEL_TYPE_VALUES}}` | 種別ラベルの値 | 依頼を分類する軸。業務で意味のある値に | 契約 / 規程 / スキーム / 知財 / 労務 / トラブル |
| `{{LABEL_CATEGORY_VALUES}}` | 区分ラベルの値 | 対応の種類を分ける軸（任意） | 当社フォーマット / 先方フォーマット / 継続案件 / 新規先方フォーマット |

> **Project ⇄ Project worktree の対応（プレースホルダではなく固定規約）**: Project worktree/ブランチ名は `proj-<slug>` で、`<slug>` は Linear の Project 名から dispatcher が決定的に導出する（小文字・英数・ハイフン化。日本語のみで slug が短すぎるときは project id 先頭8桁にフォールバック）。dispatcher は worktree を Linear Project に**ネイティブ紐付けできない**（Orca に `--linear-project` は無い）ため、この決定的な名前で同一性・冪等性を担保する。

## 命名の不変条件（外すと dispatcher が動かない）

- **`{{CHILD_TEAM}}` = lane worktree のブランチ名 = dispatcher の第1引数**。この 3 つが文字通り一致していることが lane 解決の要。だから子チーム名は git ブランチ名として妥当（小文字・ハイフンのみ・スペース無し）でなければならない。
- **Project ⇄ `proj-<slug>` ⇄ dispatcher の `--project "<Linear project 名>"`**。Project worktree は Linear Project 名で解決し、`proj-<slug>` に落ちる。dispatcher の `--project` には Linear 上の Project 名（の一部）を渡す。
- 親子: `{{CHILD_TEAM}}` は Linear 上で `{{PARENT_TEAM}}` の子チーム（sub-team）にする。親でロールアップして横断で滞留を見られる。Project はこの子チームに属させる。
- identifier（`{{CHILD_KEY}}`）は Linear が team ごとに管理する issue 接頭辞。大きめ issue のオンデマンド worktree 名はこれを小文字化した `{{CHILD_KEY_LC}}-<番号>`。

## legal-dock 実例（この業務がどう instantiate したか）

legal-dock は本パターンの最初の実装（＝リファレンス実装）:

| worktree 階層 | Linear | Orca worktree / git branch | 作業場 |
| --- | --- | --- | --- |
| root | `legal-dept`（LEG） | `soramichi-legal-dock` main / `main` | 横断・基盤・非案件法務 |
| 1階層目（lane） | `biz-legal`（BIZ） | `biz-legal` lane worktree / `biz-legal` | `matters/` |
| 2階層目（Project） | Project = 案件（継続する相談/契約の束） | `proj-<slug>` worktree / `proj-<slug>` | `matters/YYYYMMDD_相手方_案件種別/`（存続） |
| 3階層目（任意） | 大きめの `BIZ-n` | `biz-n` worktree（Claude Code）/ `biz-n` | Project ディレクトリ配下（大きめ作業のみ） |

- Project ＝「一定期間継続する案件」（相手方との契約交渉一式・継続顧問案件など複数の issue を束ねる単位）。個々の相談・レビューは issue で、Project worktree の中で対応する。
- 種別ラベル: 契約 / 規程 / スキーム / 知財 / 労務 / トラブル
- 区分ラベル: 当社フォーマット / 先方フォーマット / 継続案件 / 新規先方フォーマット（さらに「AI Review 要/不要」「機密度 一般/部署内/CFOのみ」も持つ）
- 外部公式ソース: CorpStack（会社の official 文書）。worktree からは `.orca/worktrees/soramichi-legal-dock/soramichi-corp-stack` symlink で兄弟 repo を解決している。
- 責任モデル: コパイロット型。AI は調査・レビュー・ドラフトまで、承認は法務課長。

> legal-dock は本スキルより先に、かつ「1 issue = 1 worktree」の旧モデルで手作業で組んだため、doc に legal 固有の記述（CorpStack・CONTEXT.md の申請分類・wayfinder 等）や旧モデルの名残が残っている。新しい業務では、それらは各業務固有の「外部ソース」「分類軸」に置き換え、worktree 階層は本 doc の Project 中心モデルで組む。骨格（チーム階層・正の所在分担・lane 一致規約・dispatcher・統合クローズ）はそのまま再利用する。

## 財務・経理での置き換え例（イメージ）

| プレースホルダ | 財務の例 | 経理の例 |
| --- | --- | --- |
| `{{DOMAIN}}` | 財務 | 経理 |
| `{{REPO}}` | `soramichi-finance-dock` | `soramichi-accounting-dock` |
| `{{PARENT_TEAM}}` / `{{PARENT_KEY}}` | `finance-dept` / `FIN` | `accounting-dept` / `ACC` |
| `{{CHILD_TEAM}}` / `{{CHILD_KEY}}` | `biz-finance` / `BFIN` | `biz-accounting` / `BACC` |
| `{{WORK_DIR}}` | `requests`（依頼） | `requests` |
| Project の例 | 「FY26 予算策定」「資金調達ラウンドB」 | 「FY25 決算」「新会計システム移行」 |
| 外部ソース | BigQuery 財務基盤（数値）／CorpStack（規程） | freee / ZAC ／ CorpStack |

- **Project = 一定期間続く大きめの取り組み**（予算策定・資金調達・決算・移行など）。その中の個別タスクが issue で、Project worktree の中で対応する。
- 数値そのものは BigQuery が正（`soramichi-finance-plugin:bigquery-finance`）、規程・確定文書は CorpStack が正、というソース分担は業務をまたいで共通。作業ディレクトリ（git）には成果物・作業メモを置き、原本データはコピーしない、という正の所在の考え方も共通。
