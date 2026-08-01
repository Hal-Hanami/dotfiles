# Design

The invariants this repository holds, and why each one exists. Sections are numbered
so that code, tests, and CI can cite them: a rule nobody checks is one the next change
breaks silently. Every `§N` below is pinned by at least one test in `tests/`, and the
build fails when one is not.

Measurements do not belong here — they live in [EVALUATION.md](EVALUATION.md).

## §1 The reproducible surface is the core layer, and the boundary is stated

One command reproduces a *core layer*: an interactive shell, the dotfiles that configure
it, a prompt, a runtime manager, and the CLI tools used daily. Everything else is placed
in one of two named classes rather than left ambiguous:

- **optional** — Docker Engine, devcontainers. These depend on host state (WSL systemd,
  `daemon.json`, group membership) that cannot be made idempotent from inside the guest.
  Automating them here would produce a script that works on one machine.
- **out of scope** — the OS itself (a system cannot reproduce its own substrate), secret
  material, and anything requiring an interactive login.

The boundary is published because a reproduction claim without one is unfalsifiable. The
set of tools the core layer installs is not prose: it is `tests/expected-tools.txt`, which
the documentation, the test suite, and the clean-room run all read. A tool named in one
place and not the others fails the build.

## §2 There is exactly one entry point, and it bootstraps itself

The supported entry is a single command that installs chezmoi, clones this repository,
applies it, and runs the provisioning scripts. A machine that has never heard of chezmoi
is a valid starting point; requiring the reader to install something first would move the
first step outside the artifact that claims to be reproducible.

This is why the prerequisites are only a fetch tool and privilege escalation: chezmoi
clones the published repository with a git implementation it carries, so the machine does
not need one. Provisioning installs git afterwards, for the user rather than for the
bootstrap. The dependency is real but not a precondition, and the distinction is load
bearing — a verification run that installs git first is no longer evidence about the
prerequisite list, so the clean-room check states which mode produced its result.

A separate `bootstrap.sh` was considered and rejected. One readable script is easier to
follow, but it splits provisioning across two mechanisms — the script and chezmoi's own
apply — and the two drift: each acquires its own idea of what is installed. The
readability that motivated it is recovered instead by keeping the scripts few, numbered,
and single-purpose (§3).

## §3 Phase order encodes a real dependency, not a preference

Scripts are split into `before_` and `after_` phases around the moment dotfiles are
written to `$HOME`:

- `before_` scripts provision the system layer and are the only ones that use `sudo`.
- `after_` scripts depend on files that apply has already written.

This is a hard dependency, not organisation. The runtime manager installs Node by reading
`~/.config/mise/config.toml` — a file this repository ships. Run it in the `before` phase
and it reads a file that does not exist yet and installs nothing, silently. The numeric
prefixes fix order within a phase, where the later scripts consume what the earlier ones
installed.

One ordering constraint is not expressible as a phase and is therefore written here: the
global npm install in the last script triggers the runtime manager's reshim hook, which
re-invokes that manager by bare name. The non-interactive environment scripts run in does
not have it on `PATH`, so the hook fails and takes the install's exit status with it — the
tool lands on disk but the script reports failure. The script prepends the manager's own
directory to `PATH` for this reason.

## §4 Idempotency is per-step, and one failure is deliberately not fatal

Applying twice must change nothing. Two mechanisms combine: chezmoi runs `run_once_`
scripts only when their contents change, and every step inside a script guards itself
by asking the system whether the work is already done. The second layer exists because
the first is keyed on script contents — editing a comment re-fires a script that must
then be safe to run against a fully provisioned machine.

Every script sets `set -euo pipefail`, so an unhandled failure stops the run rather than
continuing into a half-provisioned state. The one deliberate exception is the default-shell
change, which is allowed to fail: it depends on PAM configuration that a non-interactive
context may refuse, and the shell is installed and usable either way. A failure there
should not abort provisioning. It is the only tolerated failure, and it is tolerated
explicitly rather than by omission.

## §5 Secrets never enter this repository

Key material — age keys, SSH private keys, tokens — is supplied out of band, either
carried to the machine or generated on it. None of it is stored here in any form,
encrypted or otherwise.

The ignore rules that match key and credential filenames are a **backstop, not the
control**. They catch a mistake; they do not make it safe to put a secret in the source
directory. The control is that secret material is never written here in the first place.
Stating which one is load-bearing matters, because a repository whose safety rests on a
pattern list is one filename away from a leak.

## §6 Commit identity is the no-reply address, in metadata as well as content

Every commit's author and committer must be the GitHub no-reply address. This constrains
commit *metadata*, not just file contents: an address in an author field is published,
permanent, and searchable exactly like an address in a file, but no content scan finds it.

This repository has failed this rule before — its first commit carried a personal address
for the entire time it was public. The rule is therefore enforced by CI over the whole
history rather than by intention, and the shipped `.gitconfig` carries the no-reply
address so a fresh machine inherits the correct identity instead of a local override.

## §7 The source directory is applied to `$HOME`, so repository files must be excluded

chezmoi treats its source directory as a picture of the home directory. Files whose names
begin with a dot are internal to chezmoi and are never applied — which covers the CI
configuration but nothing else. Every other file is a target by default.

Consequently the repository's own documentation, licence, and tests are candidates for
installation into `$HOME`, and adding any of them without an ignore entry creates
`~/LICENSE`, `~/docs/`, and `~/tests/` on the next apply. The failure is silent and lands
in the user's home directory, so the set of applied targets is asserted directly: a test
applies this repository to a throwaway destination and requires that exactly the intended
dotfiles appear and nothing else. Adding a document is then safe by construction — forget
the ignore entry and the build fails rather than the home directory.

## §8 Versions drift by design; recorded versions are observations

The installers this bootstrap invokes resolve `latest` and `lts` at run time. Pinning them
is not the goal: the goal is a machine configured the way a current one would be, and a
pinned set decays into a reconstruction of one particular past day.

The consequence for honesty is that any version this repository records is an observation
from a dated run, never a guarantee about the next one. Recorded versions therefore always
carry the date and method that produced them, and the claim under test is that the
bootstrap *succeeds* and is *idempotent* — not that it yields any specific version. CI
re-runs the reproduction on a schedule for this reason: the thing that breaks is upstream,
so verifying only at commit time would verify the wrong clock.
