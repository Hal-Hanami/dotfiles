# dotfiles

Personal development environment for **WSL2 + Ubuntu / zsh**, managed with
[chezmoi](https://www.chezmoi.io). One command turns a clean Ubuntu into a working
setup, and running it twice changes nothing.

A Japanese version of this page is at [README.ja.md](README.ja.md).

## Use it

```sh
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init --apply Hal-Hanami/dotfiles
```

That single line installs chezmoi, clones this repository, writes the dotfiles, and runs
the provisioning scripts. Nothing needs to be installed first — chezmoi arrives as part
of the command ([DESIGN.md §2](docs/DESIGN.md)).

**Assumed present:** Ubuntu (or a Debian derivative), `curl`, `sudo`, and network access.
A default WSL2 Ubuntu has all four.

## What it installs

<!-- BEGIN core-tools -->
| Layer | Installed |
|---|---|
| Shell | `zsh`, set as the login shell |
| Prompt | `starship` |
| Tools | `git`, `age`, `keychain`, `gh` |
| Runtime | `mise`, and through it `node` and `npm` at the current LTS |
| CLI | `claude` |
<!-- END core-tools -->

Plus three dotfiles: `~/.zshrc`, `~/.gitconfig`, and `~/.config/mise/config.toml`.

This list is not prose — it is [`tests/expected-tools.txt`](tests/expected-tools.txt),
which the clean-room run asserts against and CI compares to this table. A tool named in
one place and not the other fails the build.

## What it does not install

Deliberately, with the boundary written down rather than left to be discovered:

- **optional** — Docker Engine and devcontainers, which depend on host state that cannot
  be made idempotent from inside the guest.
- **out of scope** — the OS itself, key material, and anything needing an interactive
  login (`gh auth login`, the first `claude` run, `ssh-keygen`).

The reasoning is in [DESIGN.md §1](docs/DESIGN.md).

## Does it work?

Verified by running it, not by assertion. CI provisions a clean `ubuntu:26.04` container
from the one-liner on every push to `main` and once a week, and requires that it exits
zero, that every tool above resolves afterwards, and that a second apply is a no-op.

Results, method, and the limits of the test are in
[docs/EVALUATION.md](docs/EVALUATION.md). The weekly schedule is deliberate: what breaks
a bootstrap is upstream change, so checking only at commit time would watch the wrong
clock ([DESIGN.md §8](docs/DESIGN.md)).

## Layout

<!-- BEGIN repo-tree -->
```
README.md                                          this page
README.ja.md                                       the same, in Japanese
LICENSE                                            MIT
CONTRIBUTING.md                                    conventions, and what CI enforces
docs/DESIGN.md                                     invariants and the reasons for them
docs/EVALUATION.md                                 measurements, method, and limits
dot_zshrc                                          -> ~/.zshrc
dot_gitconfig                                      -> ~/.gitconfig
dot_config/mise/config.toml                        -> ~/.config/mise/config.toml
.chezmoiignore                                     repository files, excluded from apply
.gitignore                                         backstop against committing secrets
.chezmoiscripts/run_once_before_10_apt-packages.sh.tmpl   system packages, gh, login shell
.chezmoiscripts/run_once_before_20_starship.sh.tmpl       prompt
.chezmoiscripts/run_once_after_30_mise-node.sh.tmpl       runtime manager and node
.chezmoiscripts/run_once_after_40_claude-code.sh.tmpl     cli
tests/expected-tools.txt                           the core layer, as data
tests/lib.bash                                     shared test helpers
tests/test_scripts.bats                            the provisioning scripts
tests/test_repo.bats                               what the repository applies and carries
tests/gates.py                                     whole-repository gates
tests/cleanroom.sh                                 the bootstrap, run against a bare machine
.github/workflows/checks.yml                       offline gates, every push
.github/workflows/cleanroom.yml                    the real bootstrap, in a container
```
<!-- END repo-tree -->

## Secrets

None are stored here, encrypted or otherwise. Keys are brought to the machine or
generated on it. The ignore rules that match key filenames are a backstop, not the
control ([DESIGN.md §5](docs/DESIGN.md)).

## License

MIT — see [LICENSE](LICENSE).
