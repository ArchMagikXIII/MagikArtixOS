#!/bin/bash

set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/base-test.sh"

stub_dir=$(mktemp -d)
trap 'rm -rf "$stub_dir"' EXIT

cat >"$stub_dir/ufw" <<'STUB'
#!/bin/bash
printf 'ufw %s\n' "$*" >>"$TEST_LOG"
if [[ ${1:-} == status ]]; then
  echo 'Status: inactive'
fi
STUB

# firewall.sh skips when the running kernel cannot execute iptables; stub a
# healthy version so the test exercises the configuration path itself.
cat >"$stub_dir/iptables" <<'STUB'
#!/bin/bash
printf 'iptables %s\n' "$*" >>"$TEST_LOG"
if [[ ${1:-} == --version ]]; then
  echo 'iptables v1.8.13 (nf_tables)'
fi
STUB

cat >"$stub_dir/sed" <<'STUB'
#!/bin/bash
printf 'sed %s\n' "$*" >>"$TEST_LOG"
STUB

cat >"$stub_dir/systemctl" <<'STUB'
#!/bin/bash
printf 'systemctl %s\n' "$*" >>"$TEST_LOG"
STUB

chmod +x "$stub_dir"/*

export TEST_LOG="$stub_dir/firewall.log"
PATH="$stub_dir:$PATH" bash -eE -c 'source "$1"' bash "$ROOT/install/config/firewall.sh"

grep -q '^ufw default deny incoming$' "$TEST_LOG" || fail "incoming traffic is denied by default"
grep -q '^ufw allow 53317/udp$' "$TEST_LOG" || fail "LocalSend UDP port is allowed"
grep -q '^ufw allow 53317/tcp$' "$TEST_LOG" || fail "LocalSend TCP port is allowed"
grep -qE '^ufw .*ENABLED' "$TEST_LOG" || grep -q '^sed .*ENABLED' "$TEST_LOG" ||
  fail "ufw is configured to start on boot"
grep -q '^systemctl enable ufw$' "$TEST_LOG" || fail "ufw is enabled for next boot"

pass "firewall config sets policy, allows LocalSend, and enables ufw for next boot"
