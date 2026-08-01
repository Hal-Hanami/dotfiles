#!/usr/bin/env bats
#
# The provisioning scripts. These run against rendered templates rather than source
# text, because what reaches a machine is the rendered form.

load lib

@test "§1 every provisioning script is claimed by the core-layer manifest" {
  # A script installing something nothing lists is a surface no clean-room run checks.
  for f in $(all_scripts); do
    name="${f%.sh.tmpl}"
    expected_scripts | grep -qx "$name" \
      || { echo "$f installs nothing listed in tests/expected-tools.txt"; false; }
  done
}

@test "§1 every script the manifest names exists" {
  for name in $(expected_scripts); do
    [ -f "${SCRIPT_DIR}/${name}.sh.tmpl" ] \
      || { echo "manifest names a script that is not here: $name"; false; }
  done
}

@test "§1 scripts are guarded to the operating system they were written for" {
  # Provisioning is apt- and Linux-specific. Without the guard, applying on another
  # OS runs it anyway.
  for f in $(all_scripts); do
    grep -q 'if eq .chezmoi.os "linux"' "${SCRIPT_DIR}/$f" \
      || { echo "$f has no linux guard"; false; }
  done
}

@test "§2 the repository offers no second entry point" {
  # The rejected alternative was a standalone provisioning script. If one ever
  # reappears, the single-entry claim in the README stops being true.
  for stray in bootstrap.sh install.sh setup.sh Makefile; do
    [ ! -e "${REPO_ROOT}/${stray}" ] \
      || { echo "a second entry point exists: $stray"; false; }
  done
}

@test "§2 the documented entry point installs chezmoi as part of itself" {
  grep -q 'get.chezmoi.io' "${REPO_ROOT}/README.md" \
    || { echo "README does not document the self-bootstrapping entry point"; false; }
  grep -q 'init --apply' "${REPO_ROOT}/README.md"
}

@test "§3 every script renders and is syntactically valid shell" {
  for f in $(all_scripts); do
    render "$f" > "${BATS_TEST_TMPDIR}/${f%.tmpl}"
    bash -n "${BATS_TEST_TMPDIR}/${f%.tmpl}" \
      || { echo "$f does not render to valid shell"; false; }
  done
}

@test "§3 phase prefixes match the dependency direction" {
  # `before` provisions the system; `after` consumes files apply has written. A
  # script in the wrong phase reads a file that does not exist yet.
  for f in $(all_scripts); do
    case "$f" in
      run_once_before_*|run_once_after_*) ;;
      *) echo "$f declares no phase"; false ;;
    esac
  done
  # Node is the case that forces the split: it is installed by reading an applied
  # dotfile, so its script must run after apply.
  expected_scripts | grep -q '^run_once_after_.*mise-node$'
}

@test "§3 numeric prefixes order before-phase ahead of after-phase" {
  order=$(all_scripts | sed -E 's/^run_once_(before|after)_([0-9]+)_.*/\1 \2/')
  [ "$(echo "$order" | awk '$1=="before"{print $2}' | sort -n | tail -1)" \
    -lt "$(echo "$order" | awk '$1=="after"{print $2}' | sort -n | head -1)" ]
}

@test "§3 the npm install puts the runtime manager on PATH before invoking it" {
  # Regression: the reshim hook re-invokes the manager by bare name, which the
  # non-interactive PATH does not resolve. The install succeeded and the script
  # still failed. Removing this line reintroduces that exact failure.
  render run_once_after_40_claude-code.sh.tmpl | grep -q 'export PATH='
}

@test "§4 every script stops on an unhandled failure" {
  for f in $(all_scripts); do
    render "$f" | grep -q 'set -euo pipefail' \
      || { echo "$f does not set -euo pipefail"; false; }
  done
}

@test "§4 every script guards its work so a second run is a no-op" {
  # run_once hashing alone is not enough: editing a comment re-fires a script,
  # which must then be safe against an already-provisioned machine.
  for f in $(all_scripts); do
    render "$f" | grep -qE 'command -v|dpkg -s' \
      || { echo "$f has no already-installed guard"; false; }
  done
}

@test "§4 the default-shell change is the only tolerated provisioning failure" {
  rendered=$(render run_once_before_10_apt-packages.sh.tmpl)
  # It may fail on PAM configuration, and the shell is usable regardless.
  echo "$rendered" | grep -q 'chsh .*|| true'
  # No step that installs or fetches anything may swallow its exit status. A query
  # that tolerates failure is fine — `command -v x || true` asks a question. An
  # install that tolerates failure reports success for a machine it did not finish.
  ! echo "$rendered" | grep -E 'apt-get|install -|curl ' | grep -q '|| true'
}

@test "§8 no script pins a version the installer is asked to resolve" {
  # Pinning here would contradict the lts/latest contract the documentation states.
  for f in $(all_scripts); do
    ! render "$f" | grep -vE '^\s*#' | grep -qE '@[0-9]+\.[0-9]+\.[0-9]+' \
      || { echo "$f pins a version"; false; }
  done
}
