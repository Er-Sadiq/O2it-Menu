#!/bin/sh
# Enumerates every installed, visible .desktop application the same way any
# XDG-compliant launcher does: scan "$dir/applications/*.desktop" across
# XDG_DATA_DIRS (falling back to the spec's documented default) plus the
# user's own ~/.local/share/applications, skipping NoDisplay/Hidden entries
# and anything that isn't Type=Application.
#
# This replaces org.kde.plasma.private.kicker's AppsModel/RootModel, which
# were confirmed live (twice) to return zero results when instantiated
# outside a running Plasmoid — that private API apparently only populates
# when driven from inside Kickoff's own applet context, which a KCM config
# page doesn't have. Reading .desktop files directly is the same mechanism
# every other launcher (GNOME Shell, rofi, etc.) uses, has no dependency on
# any KDE-private API, and works identically on any Linux distro.
#
# Only POSIX-portable awk (mawk/gawk/busybox awk all support this — no
# gawk-only extensions like ENDFILE) is used, since /usr/bin/awk varies by
# distro. Output: one "id<TAB>name<TAB>icon" line per app, sorted by name.

dirs="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
IFS=:
set -- $dirs
unset IFS

searchdirs=""
for d in "$@"; do
    [ -d "$d/applications" ] && searchdirs="$searchdirs $d/applications"
done
[ -d "$HOME/.local/share/applications" ] && searchdirs="$searchdirs $HOME/.local/share/applications"

[ -z "$searchdirs" ] && exit 0

find $searchdirs -maxdepth 1 -name '*.desktop' -print0 2>/dev/null | xargs -0 -r awk -F'=' '
    function flush() {
        if (type == "Application" && !nodisplay && !hidden && name != "" && id != "")
            apps[id] = id "\t" name "\t" icon
    }
    FNR == 1 {
        flush()
        n = split(FILENAME, parts, "/")
        id = parts[n]
        sub(/\.desktop$/, "", id)
        insec = 0; name = ""; icon = ""; nodisplay = 0; hidden = 0; type = ""
    }
    /^\[/ { insec = ($0 == "[Desktop Entry]") ? 1 : 0 }
    insec && /^Name=/ && name == "" { name = substr($0, 6) }
    insec && /^Icon=/ { icon = substr($0, 6) }
    insec && /^NoDisplay=true/ { nodisplay = 1 }
    insec && /^Hidden=true/ { hidden = 1 }
    insec && /^Type=/ { type = substr($0, 6) }
    END {
        flush()
        for (k in apps) print apps[k]
    }
' | sort -t "$(printf '\t')" -k2,2f
