#!/usr/bin/env bats

# Bats is a testing framework for Bash
# Documentation https://bats-core.readthedocs.io/en/stable/
# Bats libraries documentation https://github.com/ztombol/bats-docs

# For local tests, install bats-core, bats-assert, bats-file, bats-support
# And run this in the add-on root directory:
#   bats ./tests/test.bats
# To exclude release tests:
#   bats ./tests/test.bats --filter-tags '!release'
# For debugging:
#   bats ./tests/test.bats --show-output-of-passing-tests --verbose-run --print-output-on-failure

setup() {
  set -eu -o pipefail

  # Override this variable for your add-on:
  export GITHUB_REPO=vaxul/ddev-safe-chain

  TEST_BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
  export BATS_LIB_PATH="${BATS_LIB_PATH}:${TEST_BREW_PREFIX}/lib:/usr/lib/bats"
  bats_load_library bats-assert
  bats_load_library bats-file
  bats_load_library bats-support

  export DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." >/dev/null 2>&1 && pwd)"
  export PROJNAME="test-$(basename "${GITHUB_REPO}")"
  mkdir -p "${HOME}/tmp"
  export TESTDIR="$(mktemp -d "${HOME}/tmp/${PROJNAME}.XXXXXX")"
  export DDEV_NONINTERACTIVE=true
  export DDEV_NO_INSTRUMENTATION=true
  export CI=true
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1 || true
  cd "${TESTDIR}"
  run ddev config --project-name="${PROJNAME}" --project-tld=ddev.site
  assert_success
  run ddev start -y
  assert_success
}

health_checks() {
  local shims=/usr/local/safe-chain/shims

  # Non-interactive shells, as started by `ddev exec`
  run ddev exec command -v npm npx yarn pnpm
  assert_success
  assert_output "${shims}/npm
${shims}/npx
${shims}/yarn
${shims}/pnpm"

  # Login shells source /etc/profile, which resets PATH
  run ddev exec bash -lc 'command -v npm'
  assert_success
  assert_output "${shims}/npm"

  # The bashrc snippet moves the shims to the front instead of adding them twice
  run ddev exec bash -lc 'echo "$PATH" | tr : "\n" | grep -c "^/usr/local/safe-chain/shims$"'
  assert_success
  assert_output "1"

  run ddev npm safe-chain-verify
  assert_success
  assert_output --partial "OK: Safe-chain works!"

  # Without bash, only ENV PATH from the Dockerfile applies
  run ddev exec --raw npm safe-chain-verify
  assert_success
  assert_output --partial "OK: Safe-chain works!"

  # safe-chain-test is Aikido's test package, always reported as malware
  run ddev exec 'mkdir -p /tmp/safe-chain-test && cd /tmp/safe-chain-test && echo "{}" >package.json && npm install safe-chain-test </dev/null'
  assert_failure
  assert_output --partial "safe-chain-test"
  run ddev exec test -e /tmp/safe-chain-test/node_modules/safe-chain-test
  assert_failure

  # A clean package still installs, so the proxy and its CA work and the
  # project user can write the malware list cache
  run ddev exec 'cd /tmp/safe-chain-test && npm install is-number@7 </dev/null'
  assert_success
  run ddev exec test -d /tmp/safe-chain-test/node_modules/is-number
  assert_success
}

teardown() {
  set -eu -o pipefail
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1
  # Persist TESTDIR if running inside GitHub Actions. Useful for uploading test result artifacts
  # See example at https://github.com/ddev/github-action-add-on-test#preserving-artifacts
  if [ -n "${GITHUB_ENV:-}" ]; then
    [ -e "${GITHUB_ENV:-}" ] && echo "TESTDIR=${HOME}/tmp/${PROJNAME}" >> "${GITHUB_ENV}"
  else
    [ "${TESTDIR}" != "" ] && rm -rf "${TESTDIR}"
  fi
}

@test "install from directory" {
  set -eu -o pipefail
  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success
  health_checks
}

# bats test_tags=release
@test "install from release" {
  set -eu -o pipefail
  echo "# ddev add-on get ${GITHUB_REPO} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${GITHUB_REPO}"
  assert_success
  run ddev restart -y
  assert_success
  health_checks
}

@test "remove the add-on" {
  set -eu -o pipefail
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success
  run ddev exec command -v npm
  assert_success
  assert_output "/usr/local/safe-chain/shims/npm"

  run ddev add-on remove safe-chain
  assert_success
  assert_file_not_exist .ddev/web-build/Dockerfile.safe-chain
  run ddev restart -y
  assert_success
  run ddev exec command -v npm
  assert_success
  assert_output "/usr/local/n/bin/npm"
}
