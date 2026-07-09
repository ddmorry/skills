# プラグイン梱包の仕組み（marketplace.json / plugin.json）

このリポジトリは Claude Code プラグイン marketplace として配布できる（会社ミラー経由・Claude Tag 経由）。その梱包で **このリポ固有・非自明な点だけ** をまとめる。一般仕様の正本は上流ドキュメント → https://code.claude.com/docs/en/plugin-marketplaces （ここを丸写しして陳腐化させない）。開発リポ専用でミラー非配布。

## 1. 役割分担 — カタログとプラグインは別物

- **`.claude-plugin/marketplace.json` = カタログ（索引）。** 何のプラグインがあり、各実体を **どこから取るか（`source`）** を列挙する。`/plugin marketplace add <owner/repo>` が読むのはこれ。
- **`.claude-plugin/plugin.json` = 1プラグインの中身（実体・導入単位）。** `/plugin install <plugin>@<marketplace>` の対象。
- **このリポは両方を持つ**（カタログ＋自前プラグイン1本の定義）。役割が違うので両方要る。

## 2. `source` は別リポを指せる（＝依存供給のレバー）

marketplace の各プラグイン `source` は、同一リポ（`"./"`）でも外部リポ（`github` / `url` / `git-subdir` / `npm`）でもよい。**カタログの在処とプラグイン実体の在処は独立**で、それぞれ別にピンできる。現在の `marketplace.json`:

- ① `soramichi-dev-plugins` → `source: "./"`（このリポジトリ自身）
- ② `mattpocock-skills` → `source: { github, repo: mattpocock/skills, sha }`（**外部参照**）

②により fork も vendor もせず上流プラグインを1エントリで載せ、`design-feature` / `afk-build-feature` が実行時に呼ぶ referenced 依存（`to-spec` / `to-tickets` / `tdd` / `code-review` / `grilling` / `domain-modeling`）を同一スコープに供給している。動機と Claude Tag 文脈は [claude-tag-distribution.md](./claude-tag-distribution.md)。

> 補足: mattpocock/skills は `plugin.json` を持つ正しい単一プラグインだが `marketplace.json` を **持たない**。よって `marketplace add mattpocock/skills` は不可（読むべきカタログが無い）。素のプラグインは単体でマーケット登録できず、こちらのカタログから外部参照する形でのみ取り込める。

## 3. スキル検出は「規約」か「明示」か（gotcha）

- 自前プラグイン①の `plugin.json` は `skills` 配列を **持たない** → **規約検出**に依存する: プラグインルート直下の `skills/<name>/SKILL.md` を **1階層** 走査。sub-agent は publish 時にルート `agents/` へ集約される。
- **落とし穴**: スキルをカテゴリ分けで **ネスト**（例 `skills/engineering/foo/`）すると規約では拾えない。その場合は `plugin.json` に `"skills": ["./skills/engineering/foo", …]` と **明示列挙** が必要になる。
  - 実例: mattpocock/skills は `skills/engineering/…` `skills/productivity/…` にネストしているため、21本を `skills` 配列で明示列挙している。
- したがって **自前スキルは `skills/<name>/`（1階層）を維持する** のが無難。ネスト構成に変えるなら plugin.json の明示列挙とセットで。

## 4. ピンの bump

②の `sha` は会社配布用の **repo レベル pin**。上流ドリフト時（`scripts/check-vendored-skills.sh`）に `vendor-deps.json` の vendored pin を bump するのと **同じタイミングで手動 bump** する（両者を乖離させない）。詳細は [claude-tag-distribution.md](./claude-tag-distribution.md) の「pin の bump 運用」と `vendor-deps.json`。
