#!/usr/bin/env bash
# Provision a bare container from the documented entry point and check the claims.
#
# Runs as root inside a throwaway container: it creates the non-root sudo user a real
# machine has, because provisioning takes a different path as root and testing the
# path nobody uses would prove nothing.
#
# usage: cleanroom.sh <source>
#   <source> is what the entry point is pointed at — the published repository for CI,
#   a local path when verifying a working tree before it is pushed. Everything after
#   the clone is identical, and which one was used is recorded with the result.
set -euo pipefail

SOURCE="${1:?usage: cleanroom.sh <repo-or-path>}"
USER_NAME=tester

# Cloning a local path makes chezmoi shell out to git, while cloning the published
# repository uses its own built-in git — which is why the documented prerequisites are
# only curl and sudo (DESIGN.md §2). So the working-tree mode has to add git, and it
# is then no longer evidence about the prerequisite list. Only the published mode is.
case "$SOURCE" in
  /*|./*|../*) MODE=working-tree ;;
  *)           MODE=published ;;
esac
echo "### mode: $MODE  source: $SOURCE"

# Only what the documentation claims a machine already has (README: Assumed present).
# Anything else installed here would be a prerequisite the documentation hides.
apt-get update -qq
apt-get install -y -qq curl sudo >/dev/null
if [ "$MODE" = working-tree ]; then
  apt-get install -y -qq git >/dev/null
  echo "NOTE: git added for the local clone; this run does not test the prerequisites"
fi

id -u "$USER_NAME" >/dev/null 2>&1 || useradd -m -s /bin/bash "$USER_NAME"
echo "$USER_NAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/"$USER_NAME"

if [ "$MODE" = working-tree ]; then
  # The mounted tree is owned by the host user, which git refuses to read from another
  # uid. Only the harness needs this; the published mode clones over https.
  sudo -iu "$USER_NAME" git config --global --add safe.directory "$SOURCE/.git"
fi

# The manifest is read from the source tree rather than from inside the container,
# so the assertion set is the one this commit declares.
MANIFEST=$(dirname "$0")/expected-tools.txt

echo "### starting point"
sudo -iu "$USER_NAME" bash -c 'whoami; echo "login shell: $(getent passwd "$(whoami)" | cut -d: -f7)"'
absent="zsh starship mise node claude"
if [ "$MODE" = published ]; then absent="git $absent"; fi
for t in $absent; do
  if sudo -iu "$USER_NAME" bash -c "command -v $t" >/dev/null 2>&1; then
    echo "PRECONDITION FAILED: $t is already present"
    exit 1
  fi
done
echo "absent before we start: $absent"
if [ "$MODE" = published ]; then
  echo "  (git among them: the entry point clones without it — DESIGN.md §2)"
fi

echo
echo "### one-liner"
start=$(date +%s)
if sudo -iu "$USER_NAME" bash -c \
     "sh -c \"\$(curl -fsLS https://get.chezmoi.io)\" -- init --apply '$SOURCE'"; then
  status=0
else
  status=$?
fi
elapsed=$(( $(date +%s) - start ))
echo "### one-liner end  exit=$status  elapsed=${elapsed}s"
[ "$status" -eq 0 ] || exit 1

echo
echo "### every tool the manifest claims must resolve"
missing=0
while read -r tool _script resolver; do
  case "$resolver" in
    path)
      probe="command -v $tool"
      vcmd="$tool --version" ;;
    home-bin)
      probe="test -x \$HOME/.local/bin/$tool"
      vcmd="\$HOME/.local/bin/$tool --version" ;;
    mise)
      # `command` is a shell builtin, so it needs a shell — `mise exec -- command`
      # looks for an executable of that name and always fails.
      probe="\$HOME/.local/bin/mise exec -- sh -c 'command -v $tool'"
      vcmd="\$HOME/.local/bin/mise exec -- $tool --version" ;;
    *)
      echo "unknown resolver: $resolver"; exit 1 ;;
  esac
  if sudo -iu "$USER_NAME" bash -c "$probe" >/dev/null 2>&1; then
    # Versions are recorded, not asserted: the installers resolve them at run time
    # (DESIGN.md §8), so a specific one is an observation of this run.
    ver=$(sudo -iu "$USER_NAME" bash -c "$vcmd" 2>/dev/null | head -1 || true)
    printf '  %-10s ok    %s\n' "$tool" "$ver"
  else
    printf '  %-10s MISSING\n' "$tool"
    missing=1
  fi
done < <(grep -vE '^\s*#|^\s*$' "$MANIFEST")

echo
echo "### the shell this repository configures resolves the runtime"
# The environment being reproduced is zsh with the shipped .zshrc, and that file is
# what puts the version manager and its shims on PATH. Verifying only through bash
# would test a shell this repository does not configure and would pass while the
# environment a user actually gets was broken.
for t in mise node claude; do
  if sudo -iu "$USER_NAME" zsh -ic "command -v $t" >/dev/null 2>&1; then
    printf '  %-10s ok\n' "$t"
  else
    printf '  %-10s NOT RESOLVED in the configured shell\n' "$t"
    missing=1
  fi
done

[ "$missing" -eq 0 ] || { echo "manifest claims a tool the bootstrap did not install"; exit 1; }

echo
echo "### login shell was changed"
if sudo -iu "$USER_NAME" bash -c 'getent passwd "$(whoami)" | grep -q ":.*/zsh$"'; then
  echo "  login shell is zsh"
else
  echo "  NOTE: login shell unchanged (tolerated — see DESIGN.md §4)"
fi

echo
echo "### second apply must change nothing"
# The entry point installs chezmoi under ~/bin, which is why the shipped .zshrc puts
# that directory on PATH. Resolve it explicitly: a fallback that shells out to a
# missing command would put its own error text into the diff and read as a change.
CHEZMOI=$(sudo -iu "$USER_NAME" bash -c 'command -v chezmoi || echo "$HOME/bin/chezmoi"')
sudo -iu "$USER_NAME" bash -c "test -x '$CHEZMOI'" \
  || { echo "chezmoi is not where the entry point leaves it: $CHEZMOI"; exit 1; }
second=$(sudo -iu "$USER_NAME" bash -c "'$CHEZMOI' apply --dry-run --verbose")
if [ -n "$second" ]; then
  echo "NOT IDEMPOTENT — a second apply would change:"
  echo "$second"
  exit 1
fi
echo "  a second apply is a no-op"

echo
echo "### result: bootstrap from '$SOURCE' succeeded and is idempotent"
