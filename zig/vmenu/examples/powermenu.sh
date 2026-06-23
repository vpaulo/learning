#!/usr/bin/env bash
# Power menu: lock / logout / reboot / shutdown

VMENU=${VMENU:-$(dirname "$0")/../zig-out/bin/vmenu}

choice=$(printf 'lock\nlogout\nreboot\nshutdown' | "$VMENU") || exit 0

case "$choice" in
    lock)     loginctl lock-session ;;
    logout)   loginctl terminate-user "$USER" ;;
    reboot)   systemctl reboot ;;
    shutdown) systemctl poweroff ;;
esac
