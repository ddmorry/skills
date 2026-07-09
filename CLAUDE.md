# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## リポジトリの目的

ユーザーオリジナルの agent skills（Claude Code スキル）を開発・管理するリポジトリ。ビルド・テスト・lint の仕組みはない。成果物は Markdown で書かれたスキル定義そのもの。

## 構成

各スキルは `skills/<skill-name>/` に 1 ディレクトリずつ置く:

```
skills/
├── design-feature/
│   └── SKILL.md               ← 補助ファイルなしの最小構成の例
├── afk-ship/
│   ├── SKILL.md               ← スキル本体（必須）
│   └── agents/
│       └── ship-executor.md   ← スキルが使う sub-agent 定義（同梱パターン）
├── grill-yourself-with-docs/
│   ├── SKILL.md
│   └── agents/
│       └── grilling-agent.md  ← 同上
├── afk-build-feature/
│   ├── SKILL.md
│   └── agents/
│       └── coding-agent.md    ← 同上（Opus の実装委譲先）
└── to-design-doc/
    ├── SKILL.md
    └── DESIGN-DOC-FORMAT.md   ← 補助ファイル（書式定義）の例
```

リポジトリ直下には、スキル群が共有する語彙の正本 `CONTEXT.md` と、スキル設計上の決定を記録した `docs/adr/` がある。スキルを書く・直すときはこの2つに従う（用語は CONTEXT.md、委譲アーキテクチャ・受け入れゲート・Design Doc の形・設計段階コンダクターの形は ADR-0001〜0004、Claude Tag 向けの人間マージ fork（build-feature）は ADR-0005、会社配布のカタログ集約＋カテゴリ別プラグイン（ハイブリッド）・dev プラグインの `soramichi-dev-plugins` 改名は ADR-0006）。

リポジトリ直下にはさらに、会社共有への配布を制御する `company-skills.txt`（マニフェスト）と、配布実体の `scripts/publish-company-skills.sh` がある（用途は後述「会社共有リポジトリ（soramichi-plugins）へのミラー配布」）。

補助ファイル（書式定義や参考資料）を持つスキルは、それらも同じ `skills/<skill-name>/` 配下に置いて SKILL.md から相対リンクで参照する。

sub-agent を使うスキルは、agent 定義（`.claude/agents/*.md` 形式: frontmatter に `name` / `description` / `model` / `tools`）を `agents/` サブディレクトリに同梱する（そこが定義の唯一のソース。`~/.claude/agents/` へはシンボリックリンクを貼る — 次節参照）。

## SKILL.md の書式

- 先頭に YAML frontmatter で `name`（ディレクトリ名と一致させる）と `description` を書く。`description` はスキルの発動条件を決める最重要フィールドで、「何をするか」に加えて「いつ使うか（Use when ...）」を含める。
- 本文は progressive disclosure を意識する: SKILL.md には手順の核だけを書き、長い書式定義や参考資料は同ディレクトリの補助ファイルに切り出して相対リンク（例: `[CONTEXT-FORMAT.md](./CONTEXT-FORMAT.md)`）で参照する。

## インストールとリンク構造（オペレーションの前提・重要）

**このリポジトリが管理するスキルは、ここが唯一のソース**（何を管理しているかは次節「スキルの出所と管理範囲」）。Claude Code が実際に読むのは `~/.claude/` 配下だが、そこはこのリポジトリへの**シンボリックリンク**であり、コピーではない。したがって編集はリポジトリ側だけで完結し、リンク先に即反映される（**二重管理は発生しない** — かつてコピー運用だった名残の記述があれば、それは古い）。

現在のリンク構造（`ls -la` で確認できる）:

- **スキル本体**: `~/.claude/skills/<skill-name>` → `skills/<skill-name>/` への**ディレクトリごとのシンボリックリンク**。SKILL.md も補助ファイルもリンク先の実体を指すので、リポジトリを編集すればそのまま反映される。
  - 例: `~/.claude/skills/afk-ship -> /Users/daisukemori/code/skills/skills/afk-ship`
- **sub-agent 定義**: `~/.claude/agents/<agent-name>.md` → `skills/<skill-name>/agents/<agent-name>.md` への**ファイル単位のシンボリックリンク**。Agent ツールが解決する実体もこれ。
  - 例: `~/.claude/agents/ship-executor.md -> /Users/daisukemori/code/skills/skills/afk-ship/agents/ship-executor.md`

（`~/.claude/skills/` には、このリポジトリ管理外の実ディレクトリのスキルや `../../.agents/skills/` 配下への別ソースのリンクも混在する。このリポジトリが管理するのは上記2種のシンボリックリンクだけ。）

### 消費者リポジトリと `CLAUDE_CONFIG_DIR` の分離（見落としやすい前提）

`~/.claude/` に貼っただけでは**全ての起動で読まれるとは限らない**。一部の消費者リポジトリは `.envrc`（direnv）で `CLAUDE_CONFIG_DIR` を**リポジトリ内の別ディレクトリに切り替え**ており、その配下で Claude Code を起動すると `~/.claude/` ではなくそちらが設定ディレクトリになる（アカウント／認証情報を個人用と分離するため）。

| 消費者リポジトリ | `CLAUDE_CONFIG_DIR`（direnv で設定） | スキルの実体 |
|---|---|---|
| `code/graphiq/`（＋配下の `slideman-v2/` 等サブディレクトリ） | `code/graphiq/.claude-config` | `code/graphiq/.claude-config/skills/` |
| `code/soramichi/` | `code/soramichi/.claude-config` | `code/soramichi/.claude-config/skills/` |

- サブディレクトリ（例: `slideman-v2/`）は自前の `.envrc` を持たなくても、direnv が**親の `.envrc` を継承**するため親リポジトリの config を使う。
- したがってこのリポジトリのスキルを消費者で使うには、`~/.claude/skills/` に加えて**各消費者の `.claude-config/skills/` にも symlink を貼る**必要がある（前節の手順4）。ここが漏れると「個人グローバルでは動くのに消費者リポジトリでは発動しない」という不一致が起きる。
- agent 定義は例外で、各消費者の `.claude-config/agents` が `~/.claude/agents` への symlink になっているため**個人グローバル1箇所に貼れば全消費者に効く**。追随が要るのは skills だけ。

### 新しいスキルを追加するときの手順

1. `skills/<skill-name>/SKILL.md`（agent 同梱なら `skills/<skill-name>/agents/*.md` も）を作る。
2. スキル本体を個人グローバルにリンク: `ln -s /Users/daisukemori/code/skills/skills/<skill-name> ~/.claude/skills/<skill-name>`
3. agent 定義があれば各ファイルもリンク: `ln -s /Users/daisukemori/code/skills/skills/<skill-name>/agents/<agent>.md ~/.claude/agents/<agent>.md`
4. **消費者リポジトリにも追随リンクを貼る（忘れやすい・重要）**: 次節のとおり graphiq / soramichi は `CLAUDE_CONFIG_DIR` を分離しており `~/.claude/skills/` を参照しない。各消費者の `.claude-config/skills/` にも同じ symlink を貼る:
   ```sh
   for c in /Users/daisukemori/code/graphiq/.claude-config/skills \
            /Users/daisukemori/code/soramichi/.claude-config/skills; do
     ln -s /Users/daisukemori/code/skills/skills/<skill-name> "$c/<skill-name>"
   done
   ```
   agent 定義は追随不要（各消費者の `.claude-config/agents` は `~/.claude/agents` への symlink で共有される。**skills だけが消費者ごとに個別ディレクトリ**）。
5. 新しい Claude Code セッションで発動条件に合う指示を出し、発動と動作を確認する（このリポジトリに置いただけでは発動しない）。**確認は必ず消費者リポジトリ配下でも行う**（例: `code/graphiq/slideman-v2/` は `.envrc` を持たないが親 graphiq の direnv を継承するため graphiq の config を使う）。

**コピーは作らないこと。** リンクさえ貼れば以降の編集はリポジトリ側だけで反映される。コピーを作るとどちらが最新か分からなくなる。既存スキルを直したときも、リンクが正しく張られていれば追加の同期作業は不要。スキルを**改名**したときは、旧名のリンクが個人グローバルと全消費者に残らないよう掃除する（改名忘れの残骸リンクは「あるのに動かない別物」を生む）。

（この symlink 運用は**個人環境でスキルを「使う」ため**のもの。会社の他メンバーへ**配布**するのは別経路 = 次節のミラー。symlink は machine 依存の絶対パスを含むため git で共有できない。）

## 会社共有リポジトリ（soramichi-plugins）へのミラー配布

会社で共有するスキルは、この正本リポジトリから **`soramichi-dev/soramichi-plugins`**（GitHub）へ**一方向ミラー**で配布する。ローカル作業コピーは **`code/soramichi/plugins`**（`code/soramichi` は git リポジトリではない素のディレクトリなので、その直下に独立リポジトリとして置ける＝入れ子にならない）。

- **正本は常に `code/skills`。** `code/soramichi/plugins` は手編集しない下流ミラー。個人スキルも会社スキルもどちらもここで開発し、会社共有分だけをミラーへ押し出す。ミラー側を直接いじると次回同期で上書きされる。
- **何を会社共有にするかは `company-skills.txt`（マニフェスト）で決める。** 1 行 1 スキル（`skills/` 配下のディレクトリ名、`#` はコメント）。ここに無いものは個人専用でミラーに出ない。一覧から外したスキルは次回同期でミラー側から prune（削除）される。
- **配布するのはスキル本体（`skills/<name>/`）と `.claude-plugin/` だけ。** `CONTEXT.md` と `docs/adr/` は開発リポジトリ専用（スキルの語彙・設計の正本）で、プラグイン配布物には**含めない**（スキルは本文で自己完結して動く）。agents/ は各スキル配下なので同梱で付き、プラグイン用にルート `agents/` へも集約される。teammate 向け `README.md` は、正本ルートの手編集ソース `README.dist.md`（**開発リポ専用＝ミラーには出さない**）に「含まれるスキル」一覧（各 SKILL.md の description 冒頭）を `<!-- SKILLS -->` の位置へ注入してスクリプトが生成する。**配布 README の文言・セクションの増減はこの `README.dist.md` を直接編集する**（`echo` によるハードコードは廃止済み）。`.claude-plugin/` の梱包の仕組み（`marketplace.json`＝カタログ／`plugin.json`＝実体、`source` の外部参照、スキル検出の規約 vs 明示の gotcha）は [docs/plugin-packaging.md](./docs/plugin-packaging.md) を参照。
- **配布プラグイン名は `soramichi-dev-plugins`（dev カテゴリ）、marketplace（カタログ）名は `soramichi-plugins`、GitHub リポジトリ名は `soramichi-dev/soramichi-plugins`**。命名は `plugins` で統一している（配布単位は「スキル集」ではなくプラグイン＝skills に加え agents / commands / hooks / MCP を束ねる導入単位のため）。install は `soramichi-dev-plugins@soramichi-plugins`、スキルの名前空間は `/soramichi-dev-plugins:<skill>`。今後 finance / accounting / common などカテゴリが増える際は、**カタログを `soramichi-plugins` に集約したままプラグインをカテゴリごとに分割**し（機密系は `source: github` の別リポ外部参照、非機密系は同リポ）、メンバーは必要なプラグインだけ install する（ハイブリッド。判断は ADR-0006）。プラグイン名前空間はプラグイン経由 install（会社配布・Claude Tag）だけに効き、個別スキル名で張るローカル symlink 運用には影響しない。
- 実体は **`scripts/publish-company-skills.sh`**、運転役は **`publish-company-skills` スキル**。`--dry-run`（差分確認）→ 無印（ミラー＋ローカル commit・push しない）→ `--push`（**PR フローで origin/main へ反映**＝ブランチ push → PR 作成 → squash マージ → ローカル main 同期）の順で使う。初回は `git init` で `code/soramichi/plugins` を作り、remote と identity を設定する。
- **反映は soramichi-dev への outward、かつ PR 経由が必須。** `soramichi-dev/soramichi-plugins` は main への直接 push を禁止している（repository rule）ため、`--push` は直接 push せず PR フローで反映する。push / PR 作成 / マージは **ddmorry アカウント**で行う（soramichi-dev org を ddmorry が admin として使っており、**別個の soramichi GitHub アカウントは存在しない**）。`code/soramichi/.envrc` の `GH_CONFIG_DIR` 分離は同じ ddmorry の認証情報を graphiq 側と別保存しているだけで、アカウント自体は ddmorry。環境に `GH_TOKEN`（ddmorry）があればそれで通る。commit の author はミラー側 local config で `daisuke_mori@sora-michi.com` に固定（会社リポ表示用のメール分離で、GitHub の pusher は ddmorry になる）。**Claude セッションから `--push` すると、自分が作成した PR の squash マージが自動モード分類器に止められることがある**（その場合は表示される `gh pr merge … --admin` を手動実行）。
- teammate 側のインストールは、clone 後に `skills/*` を各自の config dir の `skills/` へ、`skills/*/agents/*.md` を `agents/` へ symlink する（手順は生成される README 参照）。

### Claude Tag（Claude in Slack）経由の配布

clone + symlink とは別に、**Claude Tag（Claude in Slack）**からメンバーにプラグインを使わせる経路も固めてある。要点だけ:

- Claude Tag は各自のローカル `~/.claude` を読まず、Anthropic ホストの sandbox（Claude Code on the web と同じエンジン）で動く。**スキル供給の正規経路は「`soramichi-dev/soramichi-plugins` を org プラグイン marketplace として admin 登録」**。メンバー側のインストール作業はゼロ。
- mattpocock 依存（`design-feature` / `afk-build-feature` が実行時に呼ぶ referenced 6本）は Claude Tag に各自インストールの経路が無いため、**`.claude-plugin/marketplace.json` に mattpocock を外部プラグインとして参照追加**して同一 marketplace から供給する（fork も vendor も不要）。この `sha` ピンは `vendor-deps.json` のドリフト検知と揃えて bump する。
- `afk-ship` / `afk-build-feature` の「main へ squash-merge」までやる挙動は Claude Tag では**「PR 作成で停止・マージは人間」に縮退**させるのが正。→ `afk-build-feature` の人間マージ fork として **`build-feature`（1 Issue → open PR で停止・人間マージ）を新設済み**（ADR-0005。既定の機能開発スキルで、afk-build-feature は「AFK・複数 Issue・マージまで」明示時のみ）。`afk-ship` の Claude Tag 版（PR 作成で停止）は未対応。

全体像・出典・セットアップ手順・PoC 検証項目は [docs/claude-tag-distribution.md](./docs/claude-tag-distribution.md) を正本とする（この文書は開発リポ専用でミラー対象外）。

## スキルの出所と管理範囲（正本の所在）

`~/.claude/skills/` には複数の出所のスキルが同居している。**このリポジトリが正本（編集すべき本物）なのは以下の9つだけ**。それ以外は別ソースが正本なので、ここでは編集しない（`~/.claude/skills/` 側で直接いじっても上流に反映されず、再インストールで上書きされる）。どのスキルを触るときも「正本はどこか」を最初に確かめる。

| スキル | 正本（編集する場所） | `~/.claude` への現れ方・更新方法 |
|---|---|---|
| `afk-ship` | **このリポジトリ** (`skills/afk-ship/`) | `~/.claude/skills/afk-ship` はここへの symlink。編集は即反映。2026-07 に `ship` から改名（承認を挟まずマージまで進める AFK スキルと明示し、社内アプリ開発等に運用を限定するため afk- を冠した） |
| `grill-yourself-with-docs` | **このリポジトリ** (`skills/grill-yourself-with-docs/`) | 同上 |
| `afk-build-feature` | **このリポジトリ** (`skills/afk-build-feature/`) | 同上。2026-07 に `run-epic`→`build-feature`→`afk-build-feature` と改名（旧版=メインセッション自身が実装する実ディレクトリは、委譲版へ刷新した際 symlink に置換済み。afk- は無人で複数 Issue をマージまで進める AFK スキルと明示し運用を限定するため）。**現在の `build-feature` は空いた旧名を再利用した別スキル**（単一 Issue・open PR 停止・人間マージ版。ADR-0005）で、両者は description で相互に振り分ける |
| `build-feature` | **このリポジトリ** (`skills/build-feature/`) | 同上。2026-07 追加。機能開発の**既定**スキル（1 Issue → open PR で停止・**人間マージ**）。`afk-build-feature`（AFK・複数 Issue・マージまで）の人間マージ版で、Claude Tag（Claude in Slack）やレビュー必須リポジトリの通常フロー向け。実装は afk-build-feature 同梱の `coding-agent` を**改変せず再利用**（複製を持たない＝vendored 二重化を避ける）。**会社共有＝`company-skills.txt` に記載**。判断の背景は ADR-0005 |
| `to-design-doc` | **このリポジトリ** (`skills/to-design-doc/`) | 同上 |
| `design-feature` | **このリポジトリ** (`skills/design-feature/`) | 同上 |
| `publish-company-skills` | **このリポジトリ** (`skills/publish-company-skills/`) | 同上。会社共有ミラーの配布運用スキル（前節参照）。**個人専用＝`company-skills.txt` に載せず会社リポには出さない** |
| `risk-scan` | **このリポジトリ** (`skills/risk-scan/`) | 同上。法務の案件相談・契約レビューでリスクを横断洗い出しする（姉妹 `risk-deep-dive` と分離・ハンドオフ）。2026-07 追加。**個人専用＝`company-skills.txt` に載せず会社リポには出さない**。実行時 cwd = `soramichi-legal-dock` 前提で、ランタイム登録は soramichi consumer config (`.claude-config/skills/`) のみ（個人グローバル `~/.claude/skills/` には貼らない） |
| `risk-deep-dive` | **このリポジトリ** (`skills/risk-deep-dive/`) | 同上。`risk-scan` の縦の対で、リスクポイントを一次資料で深掘りし法務レビューシートを md→HTML/Artifact 出力。2026-07 追加。個人専用・cwd 前提・登録先は `risk-scan` と同じ |
| `caveman` / `diagnose` / `tdd` など一群 | **mattpocock/skills（上流・GitHub）** | `npx skills@latest add mattpocock/skills` でインストールした実ディレクトリ。更新も同コマンドの再実行で行う。ここで手編集しない |
| `orca-cli` / `computer-use` / `orchestration` | **Orca**（`~/.agents/skills/` 配下） | `~/.claude/skills/` から `../../.agents/skills/` への symlink。Orca 側が正本 |

- **CODEX**（`~/.codex/` に独自の `skills/` を持つ別システム）へのスキル同期は、現時点では本リポジトリの管理対象外（`skill-sync` スキルで扱うが、運用整理は別途）。
- 新しい**オリジナル**スキルを増やすときは、必ずこのリポジトリに置いて symlink する（前節の手順）。サードパーティ製スキルをこのリポジトリに取り込まない（正本が二重化するため）。

## 上流 mattpocock/skills への依存追随（ドリフト検知）

一部の自作スキルは `mattpocock/skills`（`npx skills@latest add mattpocock/skills` で入る上流。**Claude Code のプラグイン自動更新の対象外**）に依存する。依存は2種類で、追随の手当てが要るのは前者だけ:

- **vendored（内容をコピー内蔵）= 上流変化のたびに手で port が要るハード依存。**
  - `grill-with-docs` → `skills/grill-yourself-with-docs/agents/grilling-agent.md`（方法論を全文内蔵）
  - `implement` → `skills/afk-build-feature/agents/coding-agent.md`（薄いループを内蔵）
- **referenced（実行時に名前で Skill 呼び出し）= 内容変化は自己修復するソフト依存。** `tdd` / `code-review` / `grilling` / `domain-modeling` / `to-spec`・`to-tickets`（design-feature）等。ただし**上流のリネーム/削除は参照を壊す**ので存在だけ監視する（例: 2026-07 に上流が `to-prd`→`to-spec`, `to-issues`→`to-tickets` に改名 → design-feature の参照を追随）。

### 仕組み

- **pin は `vendor-deps.json`（リポジトリ直下）。** vendored は上流の**サブツリーハッシュ**（`git rev-parse <commit>:<path>`）を pin する。これは skills CLI が `~/.agents/.skill-lock.json` に書く `skillFolderHash` と**同一値**なので、上流 git・ローカル lock のどちらとも直接比較できる。referenced は存在監視のみ（ハッシュ不要）。
- **検知は `scripts/check-vendored-skills.sh`（ローカル/CI 共通）。** 上流を clone し、vendored のサブツリーハッシュ差分（＋ pin→現在の diff）と referenced の消滅を Markdown で報告する（exit 3=ドリフト / 0=一致）。
- **定期検知は `.github/workflows/check-vendored-skills.yml`（毎週月曜）。** ドリフトを検知すると `upstream-drift` ラベルの Issue を起票／更新し、一致に戻ると自動クローズする。手動実行は Actions の workflow_dispatch。

### 上流が更新されたときの手順

1. CI が起票した Issue（または手元で `bash scripts/check-vendored-skills.sh`）で差分を確認。
2. vendored: diff を該当ファイルへ手で port。referenced: リネームなら参照側スキルを新名に直し、`vendor-deps.json` の該当パスも更新（例: `to-prd`→`to-spec`, `to-issues`→`to-tickets`）。
3. `bash scripts/check-vendored-skills.sh --bump` で vendored の pin を上流 HEAD に更新。
4. 会社共有分（`grill-yourself-with-docs` / `afk-build-feature` など）は `publish-company-skills` スキルでミラーへ反映（PR フロー）。会社メンバー側は、内蔵コピー分はプラグイン更新／`git pull` で届き、**referenced の上流スキル本体は各自が `npx skills@latest add mattpocock/skills` を再実行**して追随する（冪等・README に記載）。
