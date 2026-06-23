#!/usr/bin/env bash
# vmenu_run — like dmenu_run: pick any executable from $PATH and launch it

VMENU=${VMENU:-$(dirname "$0")/../zig-out/bin/vmenu}

choice=$(compgen -c | sort -u | "$VMENU") || exit 0
exec $choice
