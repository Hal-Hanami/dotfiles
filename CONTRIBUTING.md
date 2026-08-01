# Contributing

Conventions for this repository, and what the build enforces so that they do not
depend on anyone remembering them.

## Running the checks

Everything except the container run is offline and safe to run on the machine this
repository configures — the suite never writes outside a temporary directory.

```sh
git clone --depth 1 --branch v1.11.0 https://github.com/bats-core/bats-core /tmp/bats-core
/tmp/bats-core/bin/bats tests/          # the scripts, and what apply produces
python3 tests/gates.py                  # whole-repository gates
```

The real bootstrap needs a throwaway machine, so it runs in a container:

```sh
docker run --rm -v "$PWD:/src:ro" ubuntu:26.04 bash /src/tests/cleanroom.sh Hal-Hanami/dotfiles
```

Pass a local path instead of the repository name to verify a working tree before
pushing it. Which source was used is recorded with the result, because only the
published one tests the command the README gives a reader.

## Commits

Conventional Commits, in English, in the imperative mood:

```
<type>(<scope>): <summary, lower case, no trailing period>

<body: why this change is needed>
```

Types: `feat`, `fix`, `docs`, `test`, `refactor`, `build`, `chore`.

The body says **why**. The diff already says what. Constraints, rejected alternatives,
and the measurement that motivated a change belong here; the author's working process
does not.

**Never set `user.email` locally.** The global configuration is the GitHub no-reply
address, and overriding it publishes a personal address into commit metadata, where it
is permanent and no content scan finds it. This has happened here before, which is why
a test now fails the build on any commit in the history whose author or committer is
not a no-reply address (DESIGN.md §6).

## Comments

Comments say why, not what. The code already says what, and a comment describing it
stops being true the first time the code changes without it — a comment that lies is
worse than no comment.

Worth writing: a constraint not visible at that line, a non-obvious ordering
dependency, a rejected alternative, a value that came from a measurement. Not worth
writing: anything a reader gets from the line itself.

## Where things go

| File | Holds |
|---|---|
| `README.md` | the entry point: what this is, how to run it, numbers quoted by link |
| `docs/DESIGN.md` | invariants and their reasons, numbered `§N`. No measurements |
| `docs/EVALUATION.md` | measurements, dates, method, limits. No design decisions |
| `tests/expected-tools.txt` | the core layer as data, read by docs, tests, and CI |

If a number would appear in two places, something must check that the two agree.

## What CI enforces

`checks.yml` runs on every push and pull request, offline:

1. every provisioning script renders, is valid shell, sets `set -euo pipefail`, and
   guards its own work
2. applying the repository produces exactly the intended dotfiles and nothing else
3. every `§N` in `docs/DESIGN.md` is cited by at least one test — an unchecked rule is
   worse than an absent one, because it reads as a guarantee
4. every `§` reference resolves to a section this repository defines, so no reference
   points at a document the reader cannot open
5. no tracked file carries planning vocabulary, and all of them are English except
   `README.ja.md`
6. the README's file inventory matches `git ls-files`, and its tool table matches
   `tests/expected-tools.txt`

`cleanroom.yml` runs the documented one-liner against a bare container on every push
to `main`, once a week, and on request. The weekly run is the point: what breaks a
bootstrap is upstream change, and a check that only fires on commits watches the wrong
clock (DESIGN.md §8).
