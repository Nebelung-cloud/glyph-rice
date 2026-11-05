#!/bin/sh
# Installs the glyph login screen for greetd. The main install.sh calls this; by hand: sudo config/greeter/install.sh
# Rerun after a glyph update, a new wallpaper or a theme change: the greeter sees copies, not your home.
# It does not switch display managers; it prints the command for that.
set -eu
[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }
me=${SUDO_USER:?run with sudo from your own account}
home=$(getent passwd "$me" | cut -d: -f6)
here=$(dirname "$(readlink -f "$0")")
glyph=$(readlink -f "$home/.config/quickshell/glyph")
dst=/var/lib/greetd # root-owned: shell copy and state. home/ is the greeter user's own (cache, last pick)

pacman -S --needed --noconfirm greetd cage

# shell: a copy of glyph plus the greeter. LockView is LockSurface without WlSessionLock, user and avatar passed in
rm -rf "$dst/shell" "$dst/state"
mkdir -p "$dst/state/rice" "$dst/home/.cache/glyph/walls"
cp -r "$glyph" "$dst/shell"
cp "$here/greeter.qml" "$dst/shell/"
mkdir -p "$dst/shell/greeter"
cp "$here/Pick.qml" "$dst/shell/greeter/"
view="$dst/shell/lock/LockView.qml"
sed -e 's/^WlSessionLockSurface {/Item {/' \
    -e 's/text: Quickshell.env("USER")/text: root.user/' \
    -e 's|url: `file://${Quickshell.env("HOME")}/.face`|url: root.face|' \
    -e 's/^    color: Theme.bg$/    property string user: Quickshell.env("USER")\n    property string face: ""\n    property alias stage: stage/' \
    -e '/^import Quickshell.Hyprland$/d' \
    -e '/mainName = Hyprland.focusedMonitor/d' \
    -e 's/readonly property bool primary: .*/readonly property bool primary: true/' \
    "$glyph/lock/LockSurface.qml" > "$view"
for want in '^Item {' 'text: root.user' 'url: root.face' 'property alias stage'; do
    grep -q "$want" "$view" || { echo "glyph's LockSurface.qml changed, LockView not built (missing: $want)" >&2; exit 1; }
done

# theme state and the wallpaper's screen-sized copy; no notification count before login
# nothing there yet on a first install: the greeter starts from the defaults
state="$home/.local/state/rice/glyph.json"
[ -r "$state" ] || state=/dev/null
jq -n --slurpfile s "$state" '($s[0] // {}) + { unread: 0 }' > "$dst/state/rice/glyph.json"
wall=$(jq -r '.wall // ""' "$dst/state/rice/glyph.json")
[ -n "$wall" ] && cp "$home/.cache/glyph/walls/${wall##*/}.jpg" "$dst/home/.cache/glyph/walls/" 2>/dev/null || true

# fonts the greeter user can't read from your home
install -Dm644 -t /usr/share/fonts/glyph "$here/../fonts/"*.[ot]tf
fc-cache -f /usr/share/fonts/glyph
[ -f "$home/.face" ] && install -Dm644 "$home/.face" "/var/lib/AccountsService/icons/$me" || true

chown -R root:root "$dst"
chmod -R a+rX "$dst"
chown -R greeter:greeter "$dst/home"
usermod -d "$dst/home" greeter

[ -f /etc/greetd/config.toml ] && cp /etc/greetd/config.toml /etc/greetd/config.toml.bak
install -m644 "$here/config.toml" /etc/greetd/config.toml

echo "installed. greetd reads its config only at start: reboot to apply config.toml changes"
systemctl -q is-enabled greetd || echo "if you ran this by hand, switch to it with:  sudo systemctl disable sddm && sudo systemctl enable greetd"
