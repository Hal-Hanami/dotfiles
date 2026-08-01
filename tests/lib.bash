# Shared helpers. Everything here is offline: no network, no writes outside a temp
# directory, and never a write to the real home directory — the suite has to be safe
# to run on the machine this repository configures.

REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
SCRIPT_DIR="${REPO_ROOT}/.chezmoiscripts"

# Provisioning scripts are chezmoi templates, so reading them raw would test the
# template rather than what runs. Render through chezmoi for the same reason.
render() {
  chezmoi execute-template --source "$REPO_ROOT" < "${SCRIPT_DIR}/$1"
}

all_scripts() {
  find "$SCRIPT_DIR" -name '*.sh.tmpl' -printf '%f\n' | sort
}

# Column 1 of the core-layer manifest (DESIGN.md §1).
expected_tools() {
  awk '!/^#/ && NF {print $1}' "${REPO_ROOT}/tests/expected-tools.txt"
}

# Column 2: the script each tool comes from.
expected_scripts() {
  awk '!/^#/ && NF {print $2}' "${REPO_ROOT}/tests/expected-tools.txt" | sort -u
}
