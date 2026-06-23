#!/usr/bin/env bash
# SSH picker: choose a host from ~/.ssh/config and open a terminal with ssh

VMENU=${VMENU:-$(dirname "$0")/../zig-out/bin/vmenu}
TERM=${TERM_EMULATOR:-xterm}

hosts=$(grep -i '^Host ' ~/.ssh/config 2>/dev/null | awk '{print $2}' | grep -v '[*?]')
[ -z "$hosts" ] && { echo "No hosts in ~/.ssh/config" >&2; exit 1; }

host=$(printf '%s' "$hosts" | "$VMENU") || exit 0
$TERM -e ssh "$host" &
