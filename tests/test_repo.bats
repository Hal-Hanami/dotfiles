#!/usr/bin/env bats
#
# Properties of the repository itself: what it applies, what it must never carry,
# and the identity it commits under.

load lib

@test "§5 the ignore backstop actually matches key and credential filenames" {
  # A backstop that has drifted from the names it is meant to catch is worse than
  # none, because it still reads like protection.
  cd "$REPO_ROOT"
  for f in key.txt .env .env.local id_ed25519 id_ed25519.pub id_rsa \
           server.pem cert.key secret.gpg age-key.txt .netrc .npmrc; do
    git check-ignore -q "$f" || { echo "not ignored: $f"; false; }
  done
}

@test "§5 no tracked file carries key material or a token" {
  cd "$REPO_ROOT"
  # This file is excluded because it has to spell out the patterns it searches for,
  # and would otherwise match itself — the same exemption gates.py takes for the
  # vocabulary it bans. Without it the check passes only while it is untracked.
  ! git ls-files -z | grep -zv '^tests/test_repo\.bats$' | xargs -0 grep -IlE \
      'BEGIN [A-Z ]*PRIVATE KEY|AGE-SECRET-KEY-1|sk-ant-|ghp_[A-Za-z0-9]{20}|AKIA[0-9A-Z]{16}'
}

@test "§5 the secret directories chezmoi would use are absent from the source" {
  # Nothing encrypted is stored here either — the rule is that key material never
  # arrives, not that it arrives protected.
  cd "$REPO_ROOT"
  [ -z "$(git ls-files | grep -E '(^|/)(encrypted_|private_.*key)' || true)" ]
}

@test "§6 the shipped git identity is a no-reply address" {
  # A fresh machine inherits this. If it carried a personal address, every commit
  # made on that machine would publish it.
  grep -qE '^\s*email\s*=\s*[^@]+@users\.noreply\.github\.com$' \
    "${REPO_ROOT}/dot_gitconfig"
}

@test "§6 no commit in this history carries a personal address" {
  # This repository has failed this before, in commit metadata rather than in any
  # file, where no content scan would have found it.
  cd "$REPO_ROOT"
  bad=$(git log --all --format='%ae%n%ce' | sort -u \
        | grep -v '@users\.noreply\.github\.com$' || true)
  [ -z "$bad" ] || { echo "non-noreply address in history: $bad"; false; }
}

@test "§7 applying this repository creates exactly the intended dotfiles" {
  # The failure this prevents is silent and lands in the user's home directory:
  # add a document without an ignore entry and apply writes ~/LICENSE, ~/docs/,
  # ~/tests/. Asserting the applied set makes adding a document safe by default.
  dest="${BATS_TEST_TMPDIR}/home"
  mkdir -p "$dest"
  run chezmoi --source "$REPO_ROOT" --destination "$dest" managed --include=files
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | sort)" = "$(printf '%s\n' \
      .config/mise/config.toml .gitconfig .zshrc | sort)" ]
}

@test "§7 documentation and tests are excluded from apply" {
  dest="${BATS_TEST_TMPDIR}/home2"
  mkdir -p "$dest"
  run chezmoi --source "$REPO_ROOT" --destination "$dest" managed
  for repo_only in README.md README.ja.md LICENSE CONTRIBUTING.md docs tests; do
    ! echo "$output" | grep -qx "$repo_only" \
      || { echo "apply would install $repo_only into \$HOME"; false; }
  done
}

@test "§7 a new top-level document cannot be applied by accident" {
  # The ignore rules must cover the class, not only today's filenames.
  dest="${BATS_TEST_TMPDIR}/home3"
  mkdir -p "$dest"
  run chezmoi --source "$REPO_ROOT" --destination "$dest" managed --include=files
  [ "$(echo "$output" | grep -c '\.md$')" -eq 0 ]
}

@test "§8 the runtime version is requested by channel, not pinned" {
  grep -qE '^\s*node\s*=\s*"lts"\s*$' "${REPO_ROOT}/dot_config/mise/config.toml"
}

@test "§8 every recorded version is accompanied by the date it was observed" {
  # Versions here are observations, so a table of them without a date is a claim
  # about now that nothing supports.
  grep -qE '20[0-9]{2}-[0-9]{2}-[0-9]{2}' "${REPO_ROOT}/docs/EVALUATION.md"
}

@test "§8 the design states no version numbers" {
  # Measurements belong to the evaluation; a version in the design is a value that
  # will silently go stale.
  ! grep -qE '\b[0-9]+\.[0-9]+\.[0-9]+\b' "${REPO_ROOT}/docs/DESIGN.md"
}
