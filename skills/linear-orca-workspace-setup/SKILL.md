---
name: linear-orca-workspace-setup
description: 新しい業務部門（財務・経理・人事・法務など）のエージェントワークスペース repo を立ち上げ、Linear チーム階層 ⇄ リポジトリ ⇄ Orca の worktree（Team→Project→Issue の3階層）を対応づける「初回セットアップ」を業務非依存の汎用手順で行うスキル。親チーム=repo全体（横断・基盤・非案件業務）、子チーム(lane)=個別依頼レーン（1階層目 worktree）、Linear Project=永続の作業単位（2階層目 worktree・Project と同じ期間存続し文脈を蓄積）、大きめ Issue=オンデマンドの3階層目 worktree（通常 issue は Project worktree 内で作業）。「team名 = laneブランチ名 = dispatcher引数」の一致規約と「Linear Project名 → proj-<slug> worktree」の対応、正の所在分担（Linear=状態/受け渡し、git=原本/成果物）、進行中 Project を冪等に worktree 化する dispatcher、コパイロット型責任モデルを一式そろえる。使用タイミング: ユーザーが「新しい業務ワークスペースをセットアップ」「財務/経理でも法務(legal-dock)と同じ Linear+worktree の仕組みを立ち上げたい」「別部門用に Project→worktree 連携を初期構築して」「この業務にも Orca dispatcher を入れて」「Linear チームとリポジトリを対応づけて worktree で回す仕組みを作って」と言ったとき。個別 issue の実作業や日々の dispatch そのものではなく、その土台を新規に敷く初回セットアップを担い、日々の運用は生成した dispatcher / docs に引き継ぐ。
---

# linear-orca-workspace-setup — 業務ワークスペースの初回セットアップ

新しい業務部門のエージェントワークスペース repo に、**Linear（台帳）⇄ repo（成果物）⇄ Orca の Project 単位 worktree（実行）** の連携を一式敷く。legal-dock で手作業で組み上げたパターンを、業務非依存の再利用可能な形にしたもの。

worktree 階層を Linear の階層に合わせる: **Team（lane）→ Project → Issue（大きめだけ）**。永続の作業単位は **Linear Project** で、Project が続く間 Project worktree も存続するので、配下の issue が短命でも文脈が消えない（旧「1 issue = 1 worktree」で issue が閉じると worktree ごと消えていた問題への対処）。通常の issue は Project worktree の中で対応し、一定期間の大きめ作業が要る issue のときだけ、その下に Issue worktree をオンデマンドで切る。

## このスキルがやること / やらないこと

- **やる（初回セットアップ）**: Linear チーム階層（＋ Project 運用）の設計と確認、正の所在・binding 規約の repo への落とし込み、dispatcher スクリプトと運用 doc の配置、Orca lane worktree の用意、smoke test。**1 業務 repo につき原則 1 回**。
- **やらない（日々の運用）**: 個別 issue の実作業、日々の dispatch、Project / issue のクローズ・統合。これらはセットアップで**生成した `scripts/orca-linear-dispatch.mjs` と `docs/` が担う**。本スキルは最後にそこへ引き渡して終わる。

## 前提

- **Orca (Local)** が稼働（`orca status` で reachable）。対象 repo が Orca に登録済み、または登録できること。
- **Linear MCP** が使える（`list_teams` / `save_issue` / `create_issue_label` 等）。**ただし Linear チームの新規作成は MCP / orca では不可**で、Web UI の管理操作が要る（§Step 2）。
- 対象 repo が git 初期化済みで、`main` ブランチがある。
- `node` が使える（dispatcher は Node.js スクリプト）。

## 全体像（敷こうとしている対応関係）

同じ「階層」を、Linear（台帳）・Orca/git（実行）・作業場（成果物）が横並びで対応する。**永続の作業単位は Project**:

| worktree 階層 | Linear（台帳） | Orca worktree / git branch | 作業場（git） | 寿命 |
| --- | --- | --- | --- | --- |
| root | `{{PARENT_TEAM}}` | `{{REPO}}` main worktree / `main` | 横断・基盤・非案件業務 | 永続 |
| 1階層目（lane） | `{{CHILD_TEAM}}` | `{{CHILD_TEAM}}` lane worktree / `{{CHILD_TEAM}}` | `{{WORK_DIR}}/`（個別依頼） | 永続 |
| 2階層目（Project） | **Linear Project** | `proj-<slug>` worktree（Claude）/ `proj-<slug>` | `{{WORK_DIR}}/<Project>/` | **Project と同じ期間・存続** |
| 3階層目（任意） | 大きめの `{{CHILD_KEY}}-n` | `{{CHILD_KEY_LC}}-n` worktree（Claude）/ `{{CHILD_KEY_LC}}-n` | 同上（大きめ作業のみ） | 短命（オンデマンド） |

通常の issue は Project worktree の中で対応する（issue ごとに worktree を切らない）。`{{...}}` は業務ごとに埋めるパラメータ。埋め方・`proj-<slug>` の導出規約・legal-dock の実例は **`references/parameters.md`** を参照。

## 不変条件（なぜそうするか — 外すと壊れる）

このパターンが成り立つ理由を理解した上で組むこと。丸暗記ではなく、以下の「なぜ」を保つ:

1. **lane 名の三点一致**: `Linear team 名 = Orca lane worktree のブランチ名 = dispatcher の第1引数`。この一致があるから、lane 名ひとつで team・作業場・base branch がすべて決まり、dispatcher が設定ファイル無しで動く。だから子チーム名は **git ブランチ名として妥当**（小文字・ハイフン）でなければならない。
2. **Project は永続の作業単位・worktree はその寿命で存続**: 永続の単位は Issue ではなく **Linear Project**。`Linear Project 名 → proj-<slug> worktree/ブランチ → dispatcher の --project`。Project が続く間 Project worktree を存続させ、配下 issue をまたいで文脈を蓄積する。**worktree の片付けは Project のクローズが契機**であって、個々の issue のクローズではない。Orca は worktree を Linear Project にネイティブ紐付けできない（`--linear-project` 無し）ので、`proj-<slug>` の決定的な名前で同一性・冪等性を担保する。
3. **通常 issue は Project worktree 内・大きめだけ子 worktree**: 通常の issue は Project worktree の中で対応し、issue ごとに worktree を切らない。一定期間の大きめ作業が要る issue のときだけ、その Project worktree の下に Issue worktree をオンデマンドで切る（`--project ... --issue ...`）。これで「issue が短命で worktree がすぐ消える」問題を避ける。
4. **正の所在を一つに**: 状態・受け渡し・会話・監査証跡は Linear が正、原本・作業・成果物は git（`{{WORK_DIR}}`）が正。同じ内容を両方で編集し続けると、どちらが正か分からなくなる。だから**相互リンクだけして内容は複製しない**。
5. **コパイロット型**: AI は調査・レビュー・ドラフトまで。確定・承認の名義は常に人間。`In Review` state が人間レビュー段。外向きの操作（Linear への write、worktree 起動）は後戻りしにくいので、人間の承認・指示のもとで行う。
6. **進行中 Project 限定・冪等 dispatch**: dispatcher は既定で state ∈ {started, planned} の Project だけを worktree 化し、既に存在する worktree はスキップする。だから何度実行しても増殖せず、完了 Project に worktree を作らない。
7. **lane は main のポインタ・統合は Project 経由**: Project worktree は lane を base に切るが、lane 自体は固有コミットを溜めず常に main と一致させる。Issue worktree（大きめ）は Project ブランチを base に切る。統合は（Issue →）Project → main（正典）→ lane を main に ff。

---

## Step 0 — パラメータ確定

`references/parameters.md` の表に沿って、この業務の値を全部埋める。ユーザーに確認しながら決める（特に `{{CHILD_TEAM}}` はブランチ名になるので命名に注意）。以降の全 Step がこの値で駆動する。

**完了基準**: パラメータ表の全項目が具体値で埋まり、`{{CHILD_TEAM}}` が git ブランチ名として妥当。

## Step 1 — Linear チーム設計（外向き・人間の承認段）

1. **既存チームの確認**: `list_teams`（MCP）または `orca linear team list` で `{{PARENT_TEAM}}` / `{{CHILD_TEAM}}` が既にあるか確認。
2. **チーム作成（Web UI 必須）**: 無ければ **Linear Web UI で作成する**。MCP / orca にチーム作成 API は無い。`{{CHILD_TEAM}}` は `{{PARENT_TEAM}}` の**子チーム（sub-team）**にして、親でロールアップできるようにする。identifier（`{{PARENT_KEY}}` / `{{CHILD_KEY}}`）も UI で設定。ブラウザ操作が要るなら `claude-in-chrome` を使ってよいが、team 作成のような後戻りしにくい管理操作は**内容を提示して承認を得てから**行う。
3. **ラベル設計**: `{{CHILD_TEAM}}` に分類ラベルを用意する。値は `references/parameters.md` の `{{LABEL_*}}` で決めた業務固有の軸。MCP `create_issue_label` で新設。**先に作り込みすぎず**、最初は種別＋機密度など要る分だけ。
4. **state 運用**: issue は Backlog / Todo / In Progress / In Review / Done / Canceled を、生成する doc の表どおりの意味で使う。`In Review` = 人間レビュー段。**Project** は Planned / Started / Paused / Completed / Canceled を取り組みのライフサイクルに使う（dispatcher は既定で Started / Planned を worktree 化）。
5. **Project 運用**: 永続の作業単位は `{{CHILD_TEAM}}` の **Linear Project**。「一定期間続く取り組み」を Project にし、その中の個別タスクを issue にする（1 Project = `{{WORK_DIR}}` ディレクトリ 1 件）。Project は Linear（Web UI / MCP `save_project` 等）で作る（team 同様、`orca linear` には project 作成 API は無い）。setup 時点で作る必要はなく、smoke test で 1 件だけ用意すれば足りる。

**完了基準**: `{{PARENT_TEAM}}` 配下に `{{CHILD_TEAM}}` が存在し、`list_teams` で key が取れる。必要なラベルがある。Project 運用の方針（何を Project にするか）が決まっている。

## Step 2 — repo 雛形の配置

対象 repo（`{{REPO}}`）に以下を作る。**このスキルの `scripts/` と `references/` から実ファイルをコピーし、プレースホルダを埋める**。

1. **dispatcher**: このスキルの `scripts/orca-linear-dispatch.mjs` を repo の `scripts/orca-linear-dispatch.mjs` に**そのままコピー**（業務非依存・編集不要。repo 名は git から自動判定）。業務固有の参照先を初期プロンプトに足したい場合のみ `buildPrompt` を編集する。
2. **運用 doc 2 本**: このスキルの `references/*.template.md` を repo の `docs/` にコピーし、`.template` を外し、`{{...}}` を Step 0 の値で全置換:
   - `references/linear-integration.template.md` → `docs/linear-integration.md`
   - `references/orca-worktree-workflow.template.md` → `docs/orca-linear-worktree-workflow.md`
   - 先頭の HTML コメント（テンプレ注記）は削除する。埋め残しの `{{` が無いか grep で確認。
3. **作業ディレクトリ**: `{{WORK_DIR}}/README.md` を作る（命名規則 `{{DIR_NAMING}}`・サブディレクトリ received/context/work/output・binding ブロック・正の所在ルール）。`docs/linear-integration.md` §5 と同じ規約を要約して書く。
4. **CLAUDE.md への追記**: repo の `CLAUDE.md` に「Linear 連携」節を足し、チーム対応・正の所在・`docs/` へのポインタ・コパイロット型責任モデルを記す（無ければ簡潔に新設）。業務ドメインの中身（何を扱う repo か・外部ソースは何か）は業務側の記述で、本スキルは連携の骨格だけ足す。

**完了基準**: `scripts/orca-linear-dispatch.mjs`・`docs/linear-integration.md`・`docs/orca-linear-worktree-workflow.md`・`{{WORK_DIR}}/README.md` が置かれ、doc に `{{` の埋め残しが無い。

## Step 3 — Orca lane worktree を用意

1. **repo 登録の確認**: `orca worktree list --repo name:{{REPO}}` で main worktree が取れるか確認。取れなければ Orca アプリ / `orca` で repo を開いて登録する。
2. **lane worktree 作成**: 子チーム名と同名のブランチで lane worktree を切る（三点一致の要）:
   ```bash
   orca worktree create --repo name:{{REPO}} --name {{CHILD_TEAM}} --base-branch main
   ```
   これで `.orca/worktrees/{{REPO}}/{{CHILD_TEAM}}/`（branch: `{{CHILD_TEAM}}`）ができる。Project worktree はこの lane を base/親に切られる（さらにその下に大きめ issue の worktree）。Project worktree 自体は Step 4 で dispatcher が作る（ここでは lane まで）。
3. **外部ソースの symlink（該当時のみ）**: dispatcher が渡すスクリプトが兄弟 repo（`../<sibling>`）に依存するなら、worktree ベース直下に symlink を張る:
   ```bash
   ln -s /abs/path/to/<sibling> .orca/worktrees/{{REPO}}/<sibling>
   ```
   （legal-dock の CorpStack 解決がこれ。不要な業務では飛ばす）
4. **コミット & lane 追従**: Step 2 で足したファイルを main にコミットし、lane を main に ff:
   ```bash
   git add scripts/ docs/ {{WORK_DIR}}/ CLAUDE.md
   git commit -m "setup: Linear × Orca worktree 連携の初期構築"
   git -C .orca/worktrees/{{REPO}}/{{CHILD_TEAM}} merge --ff-only main
   ```
   lane が main を指していないと、Project worktree に初期ファイルが入らない。

**完了基準**: `orca worktree ps` に `{{CHILD_TEAM}}` lane worktree があり、その内容が main と一致している。

## Step 4 — 動作確認（smoke test）

1. Linear の `{{CHILD_TEAM}}` にテスト **Project** を 1 件作り、state を **Started** にする（配下にテスト issue を 1〜2 件足すと尚良い）。
2. dry-run で対象に出ること・**project JSON の形状が正しく読めていること**を確認（重要）:
   ```bash
   node scripts/orca-linear-dispatch.mjs {{CHILD_TEAM}} --dry-run
   # 出力の「●対象」行で state=... team=... → proj-<slug> が期待どおりか確認
   ```
   state / team 紐付けが `?` になっていたら、この repo の Linear が返す project JSON 形状に合わせて dispatcher の `projectState` / `projectTeamKeys` を調整する（`docs/orca-linear-worktree-workflow.md` §4・§9）。
3. 本実行 → Project worktree 作成と Claude Code 起動を確認:
   ```bash
   node scripts/orca-linear-dispatch.mjs {{CHILD_TEAM}}
   orca worktree ps    # {{CHILD_TEAM}} の子として proj-<slug> が見える
   ```
4. 冪等性の確認（再実行でスキップされる）:
   ```bash
   node scripts/orca-linear-dispatch.mjs {{CHILD_TEAM}}    # 「スキップ（worktree 既存）」になる
   ```
5. （任意）大きめ issue のオンデマンド worktree を確認:
   ```bash
   node scripts/orca-linear-dispatch.mjs {{CHILD_TEAM}} --project "<テスト Project 名>" --issue {{CHILD_KEY}}-n
   orca worktree ps    # proj-<slug> の子として {{CHILD_KEY_LC}}-n が見える
   ```
6. テストで作った worktree は片付ける:
   ```bash
   orca worktree rm --worktree branch:{{CHILD_KEY_LC}}-n --force && git branch -d {{CHILD_KEY_LC}}-n
   orca worktree rm --worktree branch:proj-<slug> --force && git branch -d proj-<slug>
   ```

**完了基準**: dry-run が Project を正しく列挙し（state / team / slug が読めている）、本実行で Project worktree ＋ Claude Code が起動し、再実行でスキップ（冪等）される。

## Step 5 — 日々の運用へ引き渡し

セットアップはここまで。以降の運用は生成物が持つ:

- **dispatch**: `node scripts/orca-linear-dispatch.mjs {{CHILD_TEAM}}`（進行中 Project を worktree 化）。大きめ issue は `--project "<名>" --issue <ID>`。
- **Project / issue 作業**: 各 worktree の Claude が dispatcher の初期プロンプトに従う（通常 issue は Project worktree の中）。
- **完了→統合→クローズ**: `docs/orca-linear-worktree-workflow.md` §3（issue を In Review → 承認後 Project ブランチ経由で main へ統合 → lane を ff → Done。**Project worktree は存続**、片付けは Project のクローズ時 §3.3）。
- **レーン / Project 追加**: 同 doc §8。

ユーザーに「セットアップ完了。日々の運用は `docs/orca-linear-worktree-workflow.md` を参照」と引き渡して終了する。

---

## ガードレール

- **チーム/Project 作成・ラベル新設・issue 起票・worktree 起動は外向き操作**。後戻りしにくいので、内容を提示して人間の承認を得てから実行する（コパイロット型）。
- **チーム・Project 作成は Web UI / MCP**。`orca linear` では作れない（team 未検出だと dispatcher が停止）。Orca は worktree を Linear Project にネイティブ紐付けできない（`--linear-project` 無し）ため、Project worktree は `proj-<slug>` の名前規約で同一性を担保する。
- **project JSON の形状はバージョン依存**。dispatcher の team 絞り込み・state 判定はこの形状に依存するので、セットアップ時に `--dry-run` で必ず検証する（Step 4）。
- **worktree の片付けは Project のクローズ契機**。個々の issue が Done になっても Project worktree は残す（文脈継続）。大きめ issue の worktree はその issue 完了時に片付ける。
- **lane は固有コミットを溜めない**（常に main を指す）。`--ff-only` が通らなければ、先に分岐を解消する。
- **エージェントは自分の worktree を消せない**。統合・クローズ・片付けは main セッション／人間側で行う。
- 業務固有の中身（外部データソース・分類軸・承認者）は各業務の判断で埋める。本スキルは連携の**骨格**だけを敷き、legal 固有の前提（CorpStack 等）は持ち込まない。

## 同梱物

| パス | 用途 |
| --- | --- |
| `scripts/orca-linear-dispatch.mjs` | repo に**コピーして使う**汎用 dispatcher（業務非依存・repo 名自動判定） |
| `references/parameters.md` | パラメータ表・命名の不変条件・legal-dock 実例・財務/経理の置き換え例 |
| `references/linear-integration.template.md` | `docs/linear-integration.md` の雛形（プレースホルダ方式） |
| `references/orca-worktree-workflow.template.md` | `docs/orca-linear-worktree-workflow.md` の雛形 |
