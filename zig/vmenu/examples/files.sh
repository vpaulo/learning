#!/usr/bin/env bash
# File picker: browse files in a directory and open the selected one with xdg-open
# Usage: ./files.sh [directory]   (defaults to $HOME)

VMENU=${VMENU:-$(dirname "$0")/../zig-out/bin/vmenu}
DIR=${1:-$HOME}

file=$(find "$DIR" -maxdepth 2 -type f | sed "s|$DIR/||" | sort | "$VMENU") || exit 0
xdg-open "$DIR/$file" &
