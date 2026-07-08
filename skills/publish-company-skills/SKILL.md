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
- スキル本体に加え、`build-feature` / `design-feature` が「スキル開発リポジトリの CONTEXT.md・docs/adr/ を正とする」と参照するため、`CONTEXT.md` と `docs/adr/` も一緒にミラーされる。sub-agent 定義（`skills/<name>/agents/*.md`）は各スキルディレクトリ内なので同梱で付いてくる。
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
   初回は `code/soramichi/skills` を `git init` し、remote を `soramichi-dev/soramichi-skills` に設定、identity を soramichi 用（`daisuke_mori@sora-michi.com`）にする。以降は差分だけをコミット。README も teammate 向けに自動生成される。

4. **push（outward・要確認）:**
   ```sh
   ./scripts/publish-company-skills.sh --push
   ```
   `soramichi-dev` org への push なので、**push 前に必ずユーザーに確認する**。commit の diff（`git -C code/soramichi/skills show --stat`）を提示し、承認を得てから push する。

## 注意（認証・identity）

- push は `git` / `gh` の**現在の環境の資格情報**で行われる。ミラー先は `code/soramichi/` 配下にあり、その `.envrc`（direnv）は `GH_CONFIG_DIR` を soramichi 用に切り替える。soramichi アカウントで push したい場合は `code/soramichi/skills` 配下で（direnv を効かせて）`git push` するのが確実。
- 環境に `GH_TOKEN` が設定されているとそれが `GH_CONFIG_DIR` を上書きするため、意図しないアカウントで push しないよう、初回は `gh api repos/soramichi-dev/soramichi-skills --jq .permissions` などで push 権限と使用アカウントを確認してから進める。
- commit の author は常に soramichi identity（ミラー先リポジトリの local config）に固定される。

## やってはいけないこと

- ミラー先（`code/soramichi/skills`）を直接編集しない。修正は正本 → 再同期。
- サードパーティ製スキルや個人専用スキルを `company-skills.txt` に足さない（会社リポに正本が二重化する / 個人用途が漏れる）。
