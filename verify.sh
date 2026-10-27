#!/bin/sh
# Read-only touchscreen health check for the Wearness LP-W841.
#
#   ./verify.sh          # check the running system
#
# Exits nonzero if a required check fails. It does not modify the system.
set -u

REPO=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
FW=$REPO/firmware/mssl1680.fw
FW_SHA256=69334fc1a8febbaf74efa92ff870f39ff5f84d7f819993fe35f878ab78c3cfe2
FW_INSTALLED=/lib/firmware/silead/mssl1680.fw
RULE=/etc/udev/rules.d/99-silead-calibration.rules

fail=0

pass() { printf '  ok    %s\n' "$1"; }
warn() { printf '  warn  %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); }

hash_of() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | cut -d' ' -f1
    else
        return 1
    fi
}

echo "LP-W841 Silead touchscreen check"
echo

echo "firmware"
if [ ! -f "$FW" ]; then
    bad "repository copy missing: $FW"
elif ! command -v sha256sum >/dev/null 2>&1; then
    warn "sha256sum not found - cannot verify repository copy"
elif [ "$(hash_of "$FW")" = "$FW_SHA256" ]; then
    pass "repository copy matches expected SHA256"
else
    bad "repository copy has an unexpected SHA256"
fi

if [ ! -f "$FW_INSTALLED" ]; then
    bad "not installed at $FW_INSTALLED"
elif ! command -v sha256sum >/dev/null 2>&1; then
    warn "installed firmware present (hash not checked)"
elif [ "$(hash_of "$FW_INSTALLED")" = "$FW_SHA256" ]; then
    pass "installed firmware matches expected SHA256"
else
    bad "installed firmware has an unexpected SHA256"
fi

echo
echo "calibration"
if [ ! -f "$RULE" ]; then
    bad "missing udev rule: $RULE"
elif grep -q 'LIBINPUT_CALIBRATION_MATRIX' "$RULE"; then
    pass "udev calibration rule installed"
else
    bad "udev rule exists but has no LIBINPUT_CALIBRATION_MATRIX"
fi

echo
echo "driver"
if [ -d /sys/module/silead ]; then
    pass "silead module is loaded"
else
    bad "silead module is not loaded"
fi

if grep -qi 'silead_ts' /proc/bus/input/devices 2>/dev/null; then
    pass "silead_ts input device is present"
else
    bad "silead_ts input device not found"
fi

echo
echo "kernel log"
if dmesg >/dev/null 2>&1; then
    if dmesg | grep -q 'direct-loading firmware silead/mssl1680.fw'; then
        pass "firmware was direct-loaded"
    elif dmesg | grep -qi 'silead'; then
        warn "silead messages found, but no direct-loading confirmation"
    else
        warn "no silead messages found in dmesg"
    fi
else
    warn "dmesg is not readable - rerun with sudo to check the kernel log"
fi

echo
if [ "$fail" -eq 0 ]; then
    echo "all required checks passed"
    exit 0
fi

echo "$fail required check(s) failed"
exit 1
