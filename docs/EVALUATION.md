# Evaluation

What has been measured, how, and what the measurement does not cover. Design decisions
are not here — they are in [DESIGN.md](DESIGN.md).

## What is claimed

1. The documented command turns a machine with none of these tools into a provisioned
   one, exiting zero.
2. Every tool the core layer claims is present afterwards, and resolves in the shell
   this repository configures.
3. Applying a second time changes nothing.
4. The stated prerequisites are sufficient.

## Method

A throwaway `ubuntu:26.04` container, with a non-root user holding passwordless sudo —
not root, because provisioning takes a different path as root and the path nobody uses
would prove nothing. Only `curl` and `sudo` are installed before the run. The harness is
[`tests/cleanroom.sh`](../tests/cleanroom.sh); CI runs the same file.

The run asserts its own starting conditions: it fails if any core tool is already
present, so a passing result cannot come from a dirty image.

There are two modes, and which one produced a result matters:

- **published** — points at the repository on GitHub, exactly what the README's command
  clones. This is the only mode that tests claim 4, because it starts without git.
- **working-tree** — points at a local checkout, for verifying changes before they are
  pushed. It installs git first, since cloning a local path makes chezmoi shell out to
  git rather than use its built-in one. That makes it silent on claim 4.

## Results

### Bootstrap, 2026-08-01, working-tree mode

`ubuntu:26.04`, image digest as pulled on that date. **exit 0, 72 seconds.**

| Claim | Result |
|---|---|
| Bootstrap succeeds from a bare machine | exit 0 |
| Every tool in the manifest resolves | 10 of 10 |
| Runtime resolves in the configured shell | `mise`, `node`, `claude` all resolve under zsh with the shipped configuration |
| Login shell changed | yes, to zsh |
| Second apply is a no-op | yes, empty diff |

Versions observed on that run. These are observations, not guarantees — the installers
resolve `latest` and `lts` when they run (DESIGN.md §8), so a later run will differ and
that is the intended behaviour:

| Tool | Version |
|---|---|
| git | 2.53.0 |
| zsh | 5.9 |
| age | 1.2.1 |
| keychain | (reports no version string) |
| gh | 2.97.0 |
| starship | 1.26.0 |
| mise | 2026.7.18 |
| node | 24.18.1 |
| npm | 11.16.0 |
| claude | 2.1.220 |

### Prerequisites, 2026-08-01, clone only

Run separately against the published repository on a container with `curl` and `sudo`
and **no git**: the clone succeeded, confirming that chezmoi's built-in git covers the
entry point and that the prerequisite list is not hiding a dependency. This exercised
the clone alone, not provisioning.

### Earlier

A hand-run reproduction on 2026-06-12 produced the same outcome — exit 0 in roughly
41 seconds, with a second apply as a no-op. It was recorded as pasted output and never
re-run, which is why it has been replaced by a harness. It is kept here as the origin
measurement, not as evidence about the current state.

The scripts have been revised since, so that run is not evidence about the current
ones. Everything reported above comes from the harness against the code as it now
stands.

## Reproducing

```sh
# what the README's command actually does
docker run --rm -v "$PWD:/src:ro" ubuntu:26.04 \
  bash /src/tests/cleanroom.sh Hal-Hanami/dotfiles

# a working tree, before pushing it
docker run --rm -v "$PWD:/src:ro" ubuntu:26.04 bash /src/tests/cleanroom.sh /src
```

CI runs the published form on every push to `main`, once a week, and on request. The
schedule is the point: these installers track upstream, so the failure mode is a change
nobody here made, and the observed versions in a CI run are newer than the table above
by design.

## What this does not show

- **A container is not WSL2.** The core layer behaves the same in both as far as has
  been observed, but the claim is about a container. Changing the login shell in
  particular depends on PAM configuration and can fail where it succeeded here; the
  bootstrap tolerates that deliberately (DESIGN.md §4), so a run can pass with the login
  shell unchanged. The output says which happened.
- **The optional layer is untested**, because it is not implemented (DESIGN.md §1).
  Nothing here says anything about Docker or devcontainers.
- **Nothing interactive is covered** — authentication, key generation, and first-run
  logins are out of scope and no measurement touches them.
- **Idempotency is checked one step deep.** A second apply produces an empty diff. This
  does not prove that a machine which has drifted in some other way converges.
- **The 72 seconds is one sample** on one machine with one network. It is recorded to
  give a sense of scale, not as a benchmark.
