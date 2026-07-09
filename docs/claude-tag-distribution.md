# Claude Tag（Claude in Slack）経由の配布 — 固めた方針

会社メンバーが **Claude Tag（= Claude in Slack）** から社内プラグイン `soramichi-skills` を使えるようにするための方針。調査フェーズの結論を固定したもの（実装は段階的）。一次情報の出典は本文中に URL で示す。

この文書は**開発リポジトリ専用**（会社ミラー `soramichi-dev/soramichi-skills` には配布しない。配布対象は `skills/` と `.claude-plugin/` のみ）。

## 前提（#0・すべてクリア済み）

- SORAMICHI に Claude organization があり、Claude Tag（public beta）が有効。
- Slack workspace ペアリング済み。`soramichi-dev` に Claude GitHub App 導入済み。
- `claude.ai/admin-settings/claude-tag` に **Owner 権限（ddmorry）** で入れる。

ここが崩れると以降は成立しないので、動かない時はまずここを疑う。

## 仕組み（一次情報で確定）

- **Claude Tag はローカル `~/.claude` を読まない。** 各スレッドは Anthropic ホストの **ephemeral sandbox** で動き、その sandbox は **「Claude Code on the web と同じエンジン」**。リポジトリを clone し、コードを実行し、PR を開ける。
  出典: https://claude.com/docs/claude-tag/concepts/how-it-works.md
- **スキル供給の正規経路は「GitHub リポジトリを org プラグイン marketplace として登録」**。admin が `claude.ai/admin-settings/claude-tag` でリポジトリを plugin source に追加し（auto-sync ON）、Access bundle の Plugins タブでプラグインを scope（org / workspace / channel）に attach する。**メンバー側のインストール作業はゼロ**（"there is nothing for channel members to install or enable"）。
  出典: https://claude.com/docs/claude-tag/admins/skills-repo.md / https://claude.com/docs/claude-tag/admins/add-connections
- **skills 形式は Claude Code と同一。** よって既存ミラー `soramichi-dev/soramichi-skills`（`marketplace.json` + `plugin.json` + `skills/` + `agents/`、CONTEXT/adr 除外）は**そのまま Claude Tag の skills リポジトリ要件を満たす**。構造改変は原則不要。
- **スキル/プラグインはスレッド開始時にロック**され、以後 admin が設定を変えても実行中スレッドには反映されない（新スレッドで反映）。

## mattpocock 依存の供給（解決済み・fork も vendor も不要）

`design-feature`（→ `to-spec` / `to-tickets` / `grilling` / `domain-modeling`）と `build-feature` の coding-agent（→ `tdd` / `code-review`）は実行時に上流 mattpocock スキルを名前で呼ぶ。Claude Tag には各自 `npx skills add` の恒久経路が無い（sandbox は使い捨て・そこで落としたファイルはスキル登録されず消える）。

**解法**: mattpocock/skills は `.claude-plugin/plugin.json` を持つ**正しい単一プラグイン**（skills を明示列挙、`marketplace.json` は無い）。素のプラグインリポジトリは単独では marketplace 登録できないが、**Claude Code の marketplace.json は別リポジトリのプラグインを外部 source として列挙できる**（"a marketplace hosted at acme-corp/plugin-catalog can list a plugin fetched from acme-corp/code-formatter"。出典: https://code.claude.com/docs/en/plugin-marketplaces）。

したがって `.claude-plugin/marketplace.json`（canonical `code/skills` 側）に mattpocock を **2つ目のプラグインエントリ**として追加済み:

```json
{ "name": "mattpocock-skills",
  "source": { "source": "github", "repo": "mattpocock/skills", "ref": "main", "sha": "<pin>" } }
```

- Claude Tag には `soramichi-skills` を1つ marketplace 登録するだけ → Plugins タブに `soramichi-skills` と `mattpocock-skills` の2プラグインが並ぶ → 両方 ON にすると自前5本＋mattpocock 21本が sandbox に入り、referenced 依存が解決する。
- **egress は追加設定不要**: Trusted（既定ネットワークレベル）の許可ドメインに `github.com` / `api.github.com` / `codeload.github.com` / `raw.githubusercontent.com` が最初から含まれる。プラグインは "installed at session start from the marketplace you declared" で外部 source も fetch される。
  出典: https://code.claude.com/docs/en/claude-code-on-the-web （Network access / Default allowed domains）
- **surface のトレードオフ**: 参照方式は mattpocock 21本すべてが入る（必要は6本）。会社チャネルに汎用エンジニアリングスキルが増えるだけで実害は薄い。もっと絞りたい場合のみ「6本だけ vendor」に切り替える。

### pin の bump 運用

marketplace.json の `sha` は **会社配布用の repo レベル pin**。上流ドリフト時（`scripts/check-vendored-skills.sh`）に vendored の pin を bump するのと**同じタイミングで手動 bump** する。両者が乖離すると「vendored コピーと Claude Tag に載る referenced 実体が別バージョン」になりうるので揃える。

将来改善: この marketplace `sha` を `check-vendored-skills.sh` / `vendor-deps.json` のドリフト検知ループに取り込み、`--bump` で marketplace.json も同時更新するのが望ましい（現状は手動）。

## セットアップ手順（admin=ddmorry が1回だけ）

1. **（実装第一歩・完了）** canonical `code/skills/.claude-plugin/marketplace.json` に mattpocock 外部プラグインエントリを追加。
2. `publish-company-skills` スキルでミラー → `soramichi-dev/soramichi-skills` へ PR フローで反映（`.claude-plugin/` ごとコピーされる。mattpocock は外部参照なので `company-skills.txt` への追加は不要）。
3. `claude.ai/admin-settings/claude-tag` で `soramichi-dev/soramichi-skills` を **org plugin marketplace として登録**（auto-sync ON）。
4. Access bundle の **Plugins タブで `soramichi-skills` / `mattpocock-skills` を ON**、対象スコープに attach。
5. （任意）Claude に skill 改善 PR を出させたいなら bundle の **Repositories** で `soramichi-skills` に write 付与。不要なら read のみ。
6. 新規スレッドで発動と動作を確認。

## 「マージまで進める」スキルの Claude Tag 向け分岐（未実装・要対応）

現行の `ship` と `build-feature` は「main へ squash-merge（`gh --admin`）」まで一気通貫する**ローカル前提**の設計。Claude Tag では GitHub App identity が **PR を開く**のが基本挙動で、`soramichi-dev` は main 直 push 禁止・レビュー必須なので、**マージは人間が行う**形に縮退させるのが正しい（チャネルにPRが出て teammate がレビュー＆マージ、という Claude Tag のモデルと整合）。

→ **方針: Claude Tag を前提に `build-feature` を fork し、「Issue ごとに PR を出して人間マージ前提」のスキルを新設する。** 同様に `ship` も Claude Tag 版は「PR 作成で停止（マージしない）」に分岐する。`build-feature` の worktree/AFK ロングランは1スレッド使い捨て sandbox（idle で解放）と相性が悪いので、Issue 単位で PR を出す形に寄せる／routines で回すなど、実挙動を PoC で測って詰める。

## PoC で潰す検証項目（方針の障害ではない）

- 外部 github プラグイン source を Claude Tag admin console が正しく surface し、Plugins タブで toggle できるか（仕組み上は成立するはずだが beta のため実確認）。
- marketplace.json の `source: "./"`（ルート1プラグイン）が Claude Tag 登録で正しく読まれるか。
- subagent（coding-agent / grilling-agent / ship-executor）が Claude Tag sandbox で起動するか（同一エンジンなので想定 OK）。
- `build-feature` の AFK ロングラン／worktree の実挙動と、idle 解放との相性。
