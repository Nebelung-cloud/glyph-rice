#!/bin/sh
# Installs the Dial greeter for greetd. The main install.sh calls this; by hand: sudo config/greeter-dial/install.sh
# Rerun after a theme change, to pick up your 24 hours and dot grid settings. The greeter sees copies, not your home.
# It does not switch display managers; it prints the command for that.
set -eu
[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }
me=${SUDO_USER:?run with sudo from your own account}
home=$(getent passwd "$me" | cut -d: -f6)
here=$(dirname "$(readlink -f "$0")")
dst=/var/lib/greetd # root-owned: the greeter and its settings. home/ is the greeter user's own (the last pick)

pacman -S --needed --noconfirm greetd cage quickshell

rm -rf "$dst/dial"
mkdir -p "$dst/dial" "$dst/state/rice" "$dst/home"
cp -L "$here/greeter.qml" "$dst/dial/"
cp -rL "$here/fonts" "$dst/dial/fonts"

# only the two settings it reads, no notification counts or paths from your home
state="$home/.local/state/rice/glyph.json"
[ -r "$state" ] || state=/dev/null
jq -n --slurpfile s "$state" '($s[0] // {}) | { clock24: (if .clock24 == false then false else true end), grid: (if .grid == false then false else true end) }' > "$dst/state/rice/glyph.json"

chown -R root:root "$dst/dial" "$dst/state"
chmod -R a+rX "$dst/dial" "$dst/state"
chown -R greeter:greeter "$dst/home"
usermod -d "$dst/home" greeter

[ -f /etc/greetd/config.toml ] && cp /etc/greetd/config.toml /etc/greetd/config.toml.bak
install -m644 "$here/config.toml" /etc/greetd/config.toml

echo "installed. greetd reads its config only at start: reboot to apply config.toml changes"
systemctl -q is-enabled greetd || echo "if you ran this by hand, switch to it with:  sudo systemctl disable sddm && sudo systemctl enable greetd"
