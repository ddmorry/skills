---
name: publish-company-skills
description: このスキル開発リポジトリ（正本）から、会社共有リポジトリ soramichi-dev/soramichi-skills（ミラー先 code/soramichi/skills）へ、company-skills.txt に列挙したスキルだけを一方向でミラー同期し commit / push する。個人専用スキルは対象外。ユーザーが「会社スキルを publish して」「soramichi-skills に反映して」「会社共有スキルを同期して」「会社リポに push して」「このスキルを社内共有に出して」など、正本の変更を会社共有リポへ配布したいときに使う。
---

# publish-company-skills

このリポジトリ（`code/skills`）を唯一の正本とし、会社共有リポジトリ
`soramichi-dev/soramichi-skills`（ローカル作業コピー = `code/soramichi/skills`）へ
**一方向ミラー**でスキルを配布する運用スキル。`design-feature` などの設計・実装スキル群とは無関係な、リポジトリ運用専用のメンテナンススキル。

## 同期モデル（前提）

- **正本は `code/skills` だけ。** `code/soramichi/skills` は手編集しない純粋な下流ミラー。ミラー先を直接いじると次回同期で上書きされる。
- 何を会社共有にするかは `code/skills/company-skills.txt`（マニフェスト）で決まる。1 行 1 スキル。ここに**無い**スキルは個人専用扱いで会社リポに出さない。マニフェストから**外した**スキルは次回同期でミラー先からも削除（prune）される。
- **配布するのはスキル本体（`skills/<name>/`）と `.claude-plugin/` だけ。** `CONTEXT.md` と `docs/adr/` は開発リポジトリ専用（スキルの語彙・設計の正本）であり、プラグイン配布物には**含めない**（スキルは本文の記述で自己完結して動く）。sub-agent 定義（`skills/<name>/agents/*.md`）は各スキルディレクトリ内なので同梱で付いてくる（プラグイン用にルート `agents/` へも集約される）。
- 実体は `scripts/publish-company-skills.sh`。このスキルはそれを運転し、diff を確認してから push させるための薄いラッパー。

## 手順

1. **正本を先に確定する。** 会社共有したいスキルの変更は必ず `code/skills` 側に入れ、コミット済みにする（ミラー先ではなく）。会社共有の対象を増減するなら `company-skills.txt` を編集する。

2. **dry-run で差分を確認する:**
   ```sh
   ./scripts/publish-company-skills.sh --dry-run
   ```
   何が同期・prune されるかを rsync の一覧で確認する。初回はミラー先リポジトリがまだ無いので、全ファイルが新規として並ぶ。

3. **ミラー + ローカル commit（push しない）:**
   ```sh
   ./scripts/publish-company-skills.sh
   ```
   初回は `code/soramichi/skills` を `git init` し、remote を `soramichi-dev/soramichi-skills` に設定、identity を soramichi 用（`daisuke_mori@sora-michi.com`）にする。以降は差分だけをコミット。README は正本ルートの `README.dist.md`（手編集ソース）に「含まれるスキル」一覧を `<!-- SKILLS -->` 位置へ注入して生成される（配布 README の文言はこのテンプレを直接編集する）。

4. **PR フローで反映（outward・要確認）:**
   `soramichi-dev/soramichi-skills` は main への直接 push が禁止されている（repository rule: "Changes must be made through a pull request"）。そのため `--push` は直接 push ではなく、**ブランチ push → PR 作成 → squash マージ → ローカル main 同期**の PR フローで反映する:
   ```sh
   ./scripts/publish-company-skills.sh --push
   ```
   `soramichi-dev` org への outward 反映なので、**実行前に必ずユーザーに確認する**。commit の diff（`git -C code/soramichi/skills show --stat`）を提示し、承認を得てから実行する。
   - スクリプトは冒頭で `git fetch origin` → ローカル main を origin/main に合わせ直すので、前回 PR の squash マージで生じた履歴の分岐は毎回自動で吸収される。
   - **Claude セッションから実行すると、自分がそのセッションで作成した PR の squash マージが自動モード分類器に止められることがある**（自己承認・レビューなしマージの防止）。その場合は、表示された `gh pr merge <branch> --repo soramichi-dev/soramichi-skills --squash --delete-branch --admin` をユーザーが直接シェルで実行する。

## 注意（認証・identity）

- **push / PR 作成 / マージは ddmorry の GitHub アカウントで行う。** soramichi-dev org は ddmorry が admin メンバーとして使っており、**別個の「soramichi」GitHub アカウントは存在しない**。ミラー先 `code/soramichi/` の `.envrc`（direnv）は `GH_CONFIG_DIR` を soramichi 用（`~/.config/gh-soramichi`）に切り替えるが、これは同じ ddmorry の認証情報を graphiq 側と別保存しているだけ（アカウント自体は ddmorry）。
- 環境に `GH_TOKEN`（ddmorry）が設定されていればそれで push・PR 作成・マージが通る。初回は `gh api repos/soramichi-dev/soramichi-skills --jq .permissions` で push 権限（`"push": true`）を確認してから進める。
- commit の author はミラー先リポジトリの local config で `daisuke_mori@sora-michi.com` に固定される。これは会社リポ表示用の**メール分離**であって、GitHub アカウントの別人格ではない（GitHub の pusher は ddmorry になる）。

## やってはいけないこと

- ミラー先（`code/soramichi/skills`）を直接編集しない。修正は正本 → 再同期。
- サードパーティ製スキルや個人専用スキルを `company-skills.txt` に足さない（会社リポに正本が二重化する / 個人用途が漏れる）。
