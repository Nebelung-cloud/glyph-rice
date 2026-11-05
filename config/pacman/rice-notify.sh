#!/bin/bash
# pacman runs this as your user after a system update (the hook comes from install.sh): says if the rice has new changes. It only tells you,
# updating stays your choice. Never fails an update: no connection, no message. yay runs pacman several times, so it checks once a minute
stamp=${XDG_CACHE_HOME:-$HOME/.cache}/glyph-rice-notify
if [ -n "$(find "$stamp" -mmin -1 2>/dev/null)" ]; then exit 0; fi
mkdir -p "${stamp%/*}" 2>/dev/null && : >"$stamp" 2>/dev/null
repo=$(dirname "$(dirname "$(dirname "$(readlink -f "$0")")")")
timeout 8 git -C "$repo" fetch -q 2>/dev/null || exit 0
n=$(git -C "$repo" rev-list --count 'HEAD..@{u}' 2>/dev/null) || exit 0
if [ "${n:-0}" -gt 0 ]; then echo "Glyph rice: $n new change(s). To get them, run: rice update"; fi
exit 0
