#!/bin/sh
# Apply the LP-E841 device configuration to the running system.
#
#   sudo ./install.sh            # apply everything
#   sudo ./install.sh --dry-run  # only show what would change
#
# This covers the device level only (firmware, /etc configs). The desktop
# (sway/waybar/OSK) is installed separately from the sway-tablet repo:
#   https://github.com/cicag/sway-tablet
set -eu

REPO=$(cd "$(dirname "$0")" && pwd)
DRY_RUN=0

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done

run() {
    if [ "$DRY_RUN" = 1 ]; then
        echo "  $*"
    else
        "$@"
    fi
}

if [ "$(id -u)" != "0" ] && [ "$DRY_RUN" = 0 ]; then
    echo "must run as root (or with sudo)" >&2
    exit 1
fi

# target desktop user for the @USER@ templates
LOGIN_USER=${SUDO_USER:-${USER:-$(logname 2>/dev/null || echo root)}}

echo "==> touchscreen firmware"
run install -d /lib/firmware/silead
run install -m 0644 "$REPO/firmware/mssl1680.fw" /lib/firmware/silead/mssl1680.fw

echo "==> system configuration"
run cp -a "$REPO/config/etc/." /etc/

# /etc/fstab is machine-specific (partition UUIDs), so it is not shipped.
echo "  note: /etc/fstab is not touched - adapt reference/fstab.example if needed"

# The getty autologin drop-in is a template - fill in the target user.
AUTOLOGIN=/etc/systemd/system/getty@tty1.service.d/autologin.conf
if [ -f "$AUTOLOGIN" ] && grep -q '@USER@' "$AUTOLOGIN"; then
    if [ "$DRY_RUN" = 1 ]; then
        echo "  sed -i 's/@USER@/$LOGIN_USER/' $AUTOLOGIN"
    else
        sed -i "s/@USER@/$LOGIN_USER/" "$AUTOLOGIN"
        echo "  autologin user: $LOGIN_USER"
    fi
fi

# sudoers rule that lets the desktop user run the scroll helper as root.
# It is kept outside config/etc/ and installed only after visudo accepts it, so
# a bad rule can never make sudo unusable.
SUDOERS_SRC=$REPO/config/sudoers/scrollbridge
SUDOERS_DST=/etc/sudoers.d/scrollbridge
if [ -f "$SUDOERS_SRC" ]; then
    if [ "$DRY_RUN" = 1 ]; then
        echo "  install -m 0440 <$SUDOERS_SRC with @USER@=$LOGIN_USER> $SUDOERS_DST"
    else
        TMP_SUDOERS=$(mktemp)
        sed "s/@USER@/$LOGIN_USER/g" "$SUDOERS_SRC" > "$TMP_SUDOERS"
        chmod 0440 "$TMP_SUDOERS"
        if visudo -cf "$TMP_SUDOERS" >/dev/null 2>&1; then
            install -m 0440 "$TMP_SUDOERS" "$SUDOERS_DST"
            echo "  sudoers rule: $LOGIN_USER may run scrollbridge"
        else
            echo "  invalid sudoers rule - not installed" >&2
        fi
        rm -f "$TMP_SUDOERS"
    fi
fi

echo "==> reloading udev rules"
run udevadm control --reload-rules
run udevadm trigger --subsystem-match=input --action=change

echo "==> reloading the silead driver (if loaded)"
if [ "$DRY_RUN" = 0 ] && lsmod | grep -q '^silead'; then
    modprobe -r silead && modprobe silead || echo "  (could not reload silead - reboot)"
fi

echo "==> regenerating initramfs (for /etc/initramfs-tools/modules)"
run update-initramfs -u

echo "==> rebuilding grub"
run update-grub

cat <<'EOF'

next steps
  1. reboot
  2. verify:  dmesg | grep -i silead        -> i2c-MSSL1680:00
              dmesg | grep -iE "hci0|rtl:"  -> RTL: fw version ...
              ls /sys/class/backlight/       -> intel_backlight
              wpctl status                   -> bytcr-rt5640
  3. install the desktop: https://github.com/cicag/sway-tablet
EOF
