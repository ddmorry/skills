---
name: linear-orca-workspace-setup
description: 新しい業務部門（財務・経理・人事・法務など）のエージェントワークスペース repo を立ち上げ、Linear チーム階層 ⇄ リポジトリ ⇄ Orca の issue 単位 worktree を対応づける「初回セットアップ」を業務非依存の汎用手順で行うスキル。親チーム=repo全体（横断・基盤・非案件業務）、子チーム(lane)=個別依頼の作業単位（1 issue = 1 worktree = 1 作業ディレクトリ）、「team名 = laneブランチ名 = dispatcher引数」の一致規約、正の所在分担（Linear=状態/受け渡し、git=原本/成果物）、Todo 限定・冪等な dispatcher、コパイロット型責任モデルを一式そろえる。使用タイミング: ユーザーが「新しい業務ワークスペースをセットアップ」「財務/経理でも法務(legal-dock)と同じ Linear+worktree の仕組みを立ち上げたい」「別部門用に issue→worktree 連携を初期構築して」「この業務にも Orca dispatcher を入れて」「Linear チームとリポジトリを対応づけて worktree で回す仕組みを作って」と言ったとき。個別 issue の実作業や日々の dispatch そのものではなく、その土台を新規に敷く初回セットアップを担い、日々の運用は生成した dispatcher / docs に引き継ぐ。
---

# linear-orca-workspace-setup — 業務ワークスペースの初回セットアップ

新しい業務部門のエージェントワークスペース repo に、**Linear（台帳）⇄ repo（成果物）⇄ Orca の issue 単位 worktree（実行）** の連携を一式敷く。legal-dock で手作業で組み上げたパターンを、業務非依存の再利用可能な形にしたもの。

## このスキルがやること / やらないこと

- **やる（初回セットアップ）**: Linear チーム階層の設計と確認、正の所在・binding 規約の repo への落とし込み、dispatcher スクリプトと運用 doc の配置、Orca lane worktree の用意、smoke test。**1 業務 repo につき原則 1 回**。
- **やらない（日々の運用）**: 個別 issue の実作業、日々の dispatch、issue のクローズ・統合。これらはセットアップで**生成した `scripts/orca-linear-dispatch.mjs` と `docs/` が担う**。本スキルは最後にそこへ引き渡して終わる。

## 前提

- **Orca (Local)** が稼働（`orca status` で reachable）。対象 repo が Orca に登録済み、または登録できること。
- **Linear MCP** が使える（`list_teams` / `save_issue` / `create_issue_label` 等）。**ただし Linear チームの新規作成は MCP / orca では不可**で、Web UI の管理操作が要る（§Step 2）。
- 対象 repo が git 初期化済みで、`main` ブランチがある。
- `node` が使える（dispatcher は Node.js スクリプト）。

## 全体像（敷こうとしている対応関係）

同じ「階層」を、Linear（台帳）・Orca/git（実行）・作業場（成果物）が横並びで対応する:

| 階層 | Linear（台帳） | Orca worktree / git branch | 作業場（git） |
| --- | --- | --- | --- |
| 親 | `{{PARENT_TEAM}}` | `{{REPO}}` main worktree / `main` | 横断・基盤・非案件業務 |
| 子（lane） | `{{CHILD_TEAM}}` | `{{CHILD_TEAM}}` lane worktree / `{{CHILD_TEAM}}` | `{{WORK_DIR}}/`（個別依頼） |
| issue | `{{CHILD_KEY}}-n` | `{{CHILD_KEY_LC}}-n` worktree（Claude）/ `{{CHILD_KEY_LC}}-n` | `{{WORK_DIR}}/<件>/` |

`{{...}}` は業務ごとに埋めるパラメータ。埋め方と legal-dock の実例は **`references/parameters.md`** を参照。

## 不変条件（なぜそうするか — 外すと壊れる）

このパターンが成り立つ理由を理解した上で組むこと。丸暗記ではなく、以下の「なぜ」を保つ:

1. **lane 名の三点一致**: `Linear team 名 = Orca lane worktree のブランチ名 = dispatcher の第1引数`。この一致があるから、lane 名ひとつで team・作業場・base branch がすべて決まり、dispatcher が設定ファイル無しで動く。だから子チーム名は **git ブランチ名として妥当**（小文字・ハイフン）でなければならない。
2. **正の所在を一つに**: 状態・受け渡し・会話・監査証跡は Linear が正、原本・作業・成果物は git（`{{WORK_DIR}}`）が正。同じ内容を両方で編集し続けると、どちらが正か分からなくなる。だから**相互リンクだけして内容は複製しない**。
3. **コパイロット型**: AI は調査・レビュー・ドラフトまで。確定・承認の名義は常に人間。`In Review` state が人間レビュー段。外向きの操作（Linear への write、worktree 起動）は後戻りしにくいので、人間の承認・指示のもとで行う。
4. **Todo 限定・冪等 dispatch**: dispatcher は Todo の issue だけを worktree 化し、既に紐付いた issue はスキップする。だから「着手可」を人が Todo で明示でき、何度実行しても増殖しない。
5. **lane は main のポインタ**: per-issue worktree は lane を base に切るが、lane 自体は固有コミットを溜めず常に main と一致させる。統合は per-issue → main → lane を main に ff。

---

## Step 0 — パラメータ確定

`references/parameters.md` の表に沿って、この業務の値を全部埋める。ユーザーに確認しながら決める（特に `{{CHILD_TEAM}}` はブランチ名になるので命名に注意）。以降の全 Step がこの値で駆動する。

**完了基準**: パラメータ表の全項目が具体値で埋まり、`{{CHILD_TEAM}}` が git ブランチ名として妥当。

## Step 1 — Linear チーム設計（外向き・人間の承認段）

1. **既存チームの確認**: `list_teams`（MCP）または `orca linear team list` で `{{PARENT_TEAM}}` / `{{CHILD_TEAM}}` が既にあるか確認。
2. **チーム作成（Web UI 必須）**: 無ければ **Linear Web UI で作成する**。MCP / orca にチーム作成 API は無い。`{{CHILD_TEAM}}` は `{{PARENT_TEAM}}` の**子チーム（sub-team）**にして、親でロールアップできるようにする。identifier（`{{PARENT_KEY}}` / `{{CHILD_KEY}}`）も UI で設定。ブラウザ操作が要るなら `claude-in-chrome` を使ってよいが、team 作成のような後戻りしにくい管理操作は**内容を提示して承認を得てから**行う。
3. **ラベル設計**: `{{CHILD_TEAM}}` に分類ラベルを用意する。値は `references/parameters.md` の `{{LABEL_*}}` で決めた業務固有の軸。MCP `create_issue_label` で新設。**先に作り込みすぎず**、最初は種別＋機密度など要る分だけ。
4. **state 運用**: Backlog / Todo / In Progress / In Review / Done / Canceled を、生成する doc の表（§Step 3 のテンプレート）どおりの意味で使う。`In Review` = 人間レビュー段。

**完了基準**: `{{PARENT_TEAM}}` 配下に `{{CHILD_TEAM}}` が存在し、`list_teams` で key が取れる。必要なラベルがある。

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
   これで `.orca/worktrees/{{REPO}}/{{CHILD_TEAM}}/`（branch: `{{CHILD_TEAM}}`）ができる。per-issue worktree はこの lane を base/親に切られる。
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
   lane が main を指していないと、per-issue worktree に初期ファイルが入らない。

**完了基準**: `orca worktree ps` に `{{CHILD_TEAM}}` lane worktree があり、その内容が main と一致している。

## Step 4 — 動作確認（smoke test）

1. Linear で `{{CHILD_TEAM}}` にテスト issue を 1 件作り **Todo** にする（`save_issue`、または既存の実 issue を Todo に）。
2. dry-run で対象に出ることを確認:
   ```bash
   node scripts/orca-linear-dispatch.mjs {{CHILD_TEAM}} --dry-run
   ```
3. 本実行 → worktree 作成と Claude Code 起動を確認:
   ```bash
   node scripts/orca-linear-dispatch.mjs {{CHILD_TEAM}}
   orca worktree ps    # {{CHILD_TEAM}} の子として {{CHILD_KEY_LC}}-n が見える
   ```
4. テストで作った worktree は片付ける:
   ```bash
   orca worktree rm --worktree branch:{{CHILD_KEY_LC}}-n --force
   git branch -d {{CHILD_KEY_LC}}-n
   ```

**完了基準**: dry-run が対象を正しく列挙し、本実行で per-issue worktree ＋ Claude Code が起動した。冪等（再実行でスキップ）も確認できると尚良い。

## Step 5 — 日々の運用へ引き渡し

セットアップはここまで。以降の運用は生成物が持つ:

- **dispatch**: `node scripts/orca-linear-dispatch.mjs {{CHILD_TEAM}}`（Todo を worktree 化）。
- **per-issue 作業**: 各 worktree の Claude が dispatcher の初期プロンプトに従う。
- **完了→統合→クローズ**: `docs/orca-linear-worktree-workflow.md` §3（In Review へ → main へ統合 → lane を ff → Done → 片付け）。
- **レーン追加**: 子チームを増やすときは同 doc §8。

ユーザーに「セットアップ完了。日々の運用は `docs/orca-linear-worktree-workflow.md` を参照」と引き渡して終了する。

---

## ガードレール

- **チーム作成・ラベル新設・issue 起票・worktree 起動は外向き操作**。後戻りしにくいので、内容を提示して人間の承認を得てから実行する（コパイロット型）。
- **チーム作成は Web UI のみ**。MCP / orca では作れない。ここを飛ばすと dispatcher が team 未検出で止まる。
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
