#!/usr/bin/env bash
# App launcher: shows all installed .desktop applications, runs the selected one.

VMENU=${VMENU:-$(dirname "$0")/../zig-out/bin/vmenu}

# Collect .desktop files from XDG standard directories
mapfile -t desktop_files < <(find \
    /usr/share/applications \
    /usr/local/share/applications \
    "$HOME/.local/share/applications" \
    -maxdepth 1 -name "*.desktop" 2>/dev/null)

[ ${#desktop_files[@]} -eq 0 ] && { echo "No .desktop files found." >&2; exit 1; }

# Parse into "Name\tExec" pairs, skipping hidden/nodisplay entries.
# Uses only POSIX awk (works with mawk/nawk/gawk).
entries=$(awk '
    function flush() {
        if (type == "Application" && nodisplay != "true" && hidden != "true" && name != "" && exec != "") {
            gsub(/ ?%[fFuUdDnNickKv]/, "", exec)
            print name "\t" exec
        }
        in_entry = 0; name = ""; exec = ""; nodisplay = ""; hidden = ""; type = ""
    }
    /^\[Desktop Entry\]/            { flush(); in_entry = 1 }
    /^\[/ && !/^\[Desktop Entry\]/  { flush() }
    in_entry && /^Name=/ && name=="" { name      = substr($0, 6) }
    in_entry && /^Exec=/             { exec      = substr($0, 6) }
    in_entry && /^NoDisplay=/        { nodisplay = substr($0, 11) }
    in_entry && /^Hidden=/           { hidden    = substr($0, 8) }
    in_entry && /^Type=/             { type      = substr($0, 6) }
    END { flush() }
' "${desktop_files[@]}" | sort -t$'\t' -k1,1 -f)

[ -z "$entries" ] && { echo "No applications found." >&2; exit 1; }

choice=$(cut -f1 <<< "$entries" | "$VMENU") || exit 0

exec_cmd=$(awk -F'\t' -v name="$choice" '$1 == name { print $2; exit }' <<< "$entries")
exec $exec_cmd
