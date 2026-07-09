---
status: accepted
date: 2026-07-09
---

# 会社配布はカタログ集約・プラグインをカテゴリ分割する（ハイブリッド）— 命名を plugins に統一し dev プラグインを soramichi-dev-plugins に

会社共有スキルはカテゴリ（dev / finance / accounting / common …）ごとに増えていく見込み（現状は dev のみ）。配布形態として、marketplace（カタログ）は `soramichi-plugins` 単一に**集約**し、その中で**プラグインをカテゴリごとに分割**する。メンバー／admin は marketplace を1回登録するだけで、必要なプラグインだけを個別に install できる（`/plugin install soramichi-dev-plugins@soramichi-plugins` のように）。

プラグイン実体の在処は**アクセス制御の要否で決める**（`marketplace.json` の各プラグイン `source` はカタログと独立にピンできる。ADR の前提は [docs/plugin-packaging.md](../plugin-packaging.md) §2）:

- **機密でなく共有インフラを共用したいカテゴリ（dev / common）** → 同リポ（`source: "./"` または `./plugins/<cat>`）。`CONTEXT.md` / `docs/adr/` / `vendor-deps.json` + ドリフト検知 CI / `publish-company-skills.sh` / `README.dist.md` 生成を1セットで共用でき、common の横断参照も相対リンクで済む。
- **機密で権限分離したいカテゴリ（finance / accounting）** → 別リポ外部参照（`source: github`）。BigQuery 財務データ・freee・給与テーブル・勘定科目マッピングに触れる本文を、read 権限を持つ者だけに限定できる（既に `soramichi-finance-plugin` / `soramichi-kaikei-plugin` が別プラグインとして存在する実績と整合）。カタログにはプラグイン名と description だけが出る。

命名は `skills` ではなく **`plugins`** で統一する。配布単位は Claude Code の**プラグイン**（スキルに加え agents / commands / hooks / MCP を束ねる導入単位）であり「スキル集」ではないため、GitHub リポジトリ・marketplace（カタログ）・プラグインの三者とも `plugins` で名付ける: リポジトリ `soramichi-dev/soramichi-plugins`、marketplace 名 `soramichi-plugins`（抽象カタログ名）、dev カテゴリのプラグイン `soramichi-dev-plugins`。旧称はそれぞれ `soramichi-dev/soramichi-skills` / `soramichi-skills` / `soramichi-skills`（当初 `soramichi-dev-skills` へ改名しかけたが `plugins` 統一に集約）。common / finance の実体分割と marketplace.json への追加は将来の作業。

## Considered Options

- **案A リポジトリ完全分割** — カテゴリごとに独立リポ＝独立 marketplace（`soramichi-dev-plugins` / `soramichi-finance-plugins` …、install は `soramichi-dev-plugins@soramichi-dev-plugins`）。オーナーシップ／リリースサイクルは完全独立になるが、(1) marketplace 登録が admin 側で N 回、(2) 共有インフラ（CONTEXT / ADR / vendor-deps ドリフト検知 CI / publish / README 生成）を各リポに複製するか別リポへ切り出す必要があり二重管理リスク、(3) common の横断参照が別リポ依存になる。チームごとのガバナンス完全分離が必須でない限り重い。
- **案B 単一リポ・全カテゴリ同居** — 1リポに `plugins/<cat>/` を並べ、1カタログに複数プラグインを列挙（install は `soramichi-dev-plugins@soramichi-plugins`）。最もシンプルで共有インフラ1セット・登録1回だが、finance / accounting の本文も同一リポに同居するため **read 権限がカテゴリ横断で一括**になり、機密分離ができない。
- **ハイブリッド（採用）** — カタログを集約しつつ、実体はアクセス制御の要否で同リポ／別リポに振り分ける。案B の運用の軽さ（登録1回・共有インフラ共用）と案A の機密分離を両取りする。`marketplace.json` が既に「1カタログ・複数プラグイン」（自前＋mattpocock 外部参照）を実装済みで、追加の仕組みが要らない。

## Consequences

- install は `soramichi-dev-plugins@soramichi-plugins`、スキルの名前空間は `/soramichi-dev-plugins:<skill>` になる（例: `/soramichi-dev-plugins:afk-build-feature`）。
- 今回、GitHub リポジトリ名（`soramichi-dev/soramichi-skills`→`soramichi-dev/soramichi-plugins`）・marketplace 名（`soramichi-skills`→`soramichi-plugins`）・プラグイン名（`soramichi-skills`→`soramichi-dev-plugins`）を一度に改名した。本番の marketplace 登録・`enabledPlugins` 配布・Claude Tag org 登録がまだ無いため既存参照の破壊はない。もし稼働済みなら、GitHub リポジトリの実 rename（旧名リダイレクトは効くが新名に統一）＋ marketplace の再登録（`/plugin marketplace add soramichi-dev/soramichi-plugins`）＋ `enabledPlugins` キーの張り替え（`soramichi-dev-plugins@soramichi-plugins` と `mattpocock-skills@soramichi-plugins`）が必要。
- 各プラグインは**ルート直下 `skills/<name>/` の1階層規約検出**を維持する（カテゴリでフォルダをネストしない）。ネストするなら `plugin.json` の `skills` 明示列挙が必要（plugin-packaging.md §3 の gotcha）。
- **物理再編（`plugins/<cat>/` への分割）のトリガーは「common / finance など dev 以外の会社配布スキルが最初に生まれたとき」**。それまでは会社配布 6 本が全て dev カテゴリで整合しているため、`source: "./"`（リポジトリ全体＝ `soramichi-dev-plugins`）のまま据え置く。単一リポ内に複数プラグインを別サブディレクトリの `source`（`./plugins/dev` 等）で出し分けることは公式サポート機能なので（[docs/plugin-packaging.md](../plugin-packaging.md) §2・上流 marketplace ドキュメントの Relative path source / `metadata.pluginRoot`）、リポジトリ分割は機密アクセス制御が要るカテゴリにのみ必要で、非機密カテゴリは 1 リポで分割できる。
- 再編時は、正本 `code/skills` を物理分割せず「フラット `skills/` ＋ publish が配布物を整形」の疎結合を保つ案（`company-skills.txt` をカテゴリ付きにして publish がミラーを `plugins/<cat>/` で生成）も選べる。正本ごと物理分割するとローカル symlink（個人グローバル＋消費者 config）の全張り直し・`vendor-deps.json` / `check-vendored-skills.sh` のパス更新・CONTEXT 相対リンク見直しに波及する。いずれの案でも common を `./plugins/common`、finance / accounting を `source: github` の外部参照として `marketplace.json` の `plugins[]` に追加し、`publish-company-skills.sh` / `README.dist.md` 生成 / `company-skills.txt` をカテゴリ対応させる（本 ADR では未実施）。
- `mattpocock-skills` は従来どおり2つ目の外部参照プラグインとして同一カタログに残る（referenced 依存供給。ADR とは独立、plugin-packaging.md §2）。
- ローカルの symlink 運用（`~/.claude/skills/<skill>` と各消費者 config への直リンク）は**個別スキル名**で張るため、プラグイン名前空間とは別系統で影響を受けない。プラグイン名変更が効くのはプラグイン経由 install（会社配布・Claude Tag）だけ。
