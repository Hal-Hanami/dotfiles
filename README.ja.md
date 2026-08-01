# dotfiles

**WSL2 + Ubuntu / zsh** 向けの個人開発環境を [chezmoi](https://www.chezmoi.io) で管理する。
クリーンな Ubuntu を1コマンドで動く状態にし、2回目以降は何も変えない。

英語版（正本）は [README.md](README.md)。

## 使い方

```sh
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init --apply Hal-Hanami/dotfiles
```

この1行が chezmoi 本体の導入・このリポの clone・dotfiles の適用・プロビジョニングスクリプトの実行を
連続して行う。事前に何かを入れておく必要はない（chezmoi 自身がこのコマンドの一部として入る。
[DESIGN.md §2](docs/DESIGN.md)）。

**前提**: Ubuntu（または Debian 系）・`curl`・`sudo`・ネットワーク接続。
WSL2 の既定 Ubuntu はこの4つを満たしている。

## 何が入るか

| 層 | 導入されるもの |
|---|---|
| シェル | `zsh`（ログインシェルに設定） |
| プロンプト | `starship` |
| ツール | `git`・`age`・`keychain`・`gh` |
| ランタイム | `mise`、および mise 経由で現行 LTS の `node`・`npm` |
| CLI | `claude` |

加えて dotfiles 3点: `~/.zshrc`・`~/.gitconfig`・`~/.config/mise/config.toml`。

この一覧は文章ではなく [`tests/expected-tools.txt`](tests/expected-tools.txt) が正本で、
クリーンルーム実行がこれを assert し、CI が英語版 README の表と突き合わせる。
片方にしか無いツールがあればビルドが落ちる。

## 何が入らないか

意図的に入れない。境界を後から発見させず、書いておく。

- **optional** — Docker Engine・devcontainer。ホスト側の状態に依存し、ゲスト内部からは冪等化できない。
- **範囲外** — OS 本体・鍵などの秘密・対話ログインを要するもの（`gh auth login`・`claude` の初回起動・
  `ssh-keygen`）。

理由は [DESIGN.md §1](docs/DESIGN.md)。

## 本当に動くのか

主張ではなく、実際に走らせて確認している。CI が `main` への push ごとと週に1回、
クリーンな `ubuntu:26.04` コンテナをこのワンライナーからプロビジョニングし、
exit 0 になること・上記の全ツールが解決すること・2回目の apply が no-op であることを要求する。

結果・測定方法・検証の限界は [docs/EVALUATION.md](docs/EVALUATION.md)。
週次にしているのは意図的で、ブートストラップを壊すのは上流の変化だから、
コミット時にだけ見ていても見ている時計が違う（[DESIGN.md §8](docs/DESIGN.md)）。

## 構成

ファイル一覧は [README.md](README.md) の Layout 節にある（CI が `git ls-files` と一致を検査する）。

## 秘密情報

暗号化の有無を問わず、ここには一切置かない。鍵は手元から持ち込むか、そのマシンで生成する。
鍵のファイル名にマッチする ignore 規則は backstop であって第一防壁ではない
（[DESIGN.md §5](docs/DESIGN.md)）。

## ライセンス

MIT — [LICENSE](LICENSE) を参照。
