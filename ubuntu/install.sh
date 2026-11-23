#!/usr/bin/env bash
# Glyph on Ubuntu GNOME: the look of the rice without Hyprland and Quickshell (Ubuntu 24.04 has neither, nor Qt 6.9).
# What carries over: the top bar (a GNOME Shell extension: Glyph clock, pill buttons, white-on-black quick settings),
# GTK colours, the dot wallpaper, fonts, Ghostty, fish, starship, fastfetch, btop, cava. What doesn't: everything
# Quickshell draws (Glyph edges, island, launcher, Deck, Prefs…).
#   ubuntu/install.sh            apt packages + links + GNOME settings
#   ubuntu/install.sh --links    links + GNOME settings only, no sudo
#   ubuntu/install.sh --fish     also make fish the login shell
# Every run keeps what it replaced in ~/.dots-backup-<date>; ~/.dots-backup-<date>/undo.sh puts it all back.
set -euo pipefail

DOTS="$(cd "$(dirname "$0")/.." && pwd)"
U="$DOTS/ubuntu"
G="$DOTS/config/quickshell/glyph"
BACKUP="$HOME/.dots-backup-$(date +%F_%H-%M-%S)"
UNDO="$BACKUP/undo.sh"
EXT=glyph-bar@glyph-rice
APT=(fish cava eza zoxide direnv btop fastfetch python3-pil curl unzip fontconfig)

say() { printf '\n\033[1m:: %s\033[0m\n' "$*"; }
# undo.sh runs its lines in reverse, so the last change is taken back first
undo() { mkdir -p "$BACKUP"; printf '%s\n' "$*" >> "$UNDO.lines"; }
finish_undo() {
    [ -f "$UNDO.lines" ] || return 0
    { echo '#!/usr/bin/env bash'; echo "# restores what ubuntu/install.sh changed on $(date +%F)"; echo 'set -u'; tac "$UNDO.lines"; echo 'echo "restored; log out and back in for the top bar"'; } > "$UNDO"
    rm "$UNDO.lines"
    chmod +x "$UNDO"
}
trap finish_undo EXIT

# repo path → path in $HOME; an existing file moves to the backup first
link() {
    local src="$1" dst="$HOME/$2"
    [ "$(readlink "$dst" 2>/dev/null)" = "$src" ] && return 0
    mkdir -p "$BACKUP" "$(dirname "$dst")"
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        mkdir -p "$BACKUP/$(dirname "$2")"
        mv "$dst" "$BACKUP/$2"
        undo "rm -f '$dst'; mv '$BACKUP/$2' '$dst'"
    else
        undo "rm -f '$dst'"
    fi
    ln -s "$src" "$dst"
    echo "  ~/$2"
}

# gsettings set, remembering the old value for undo.sh; keys missing on this GNOME are skipped
gs() {
    local old
    old=$(gsettings get "$1" "$2" 2>/dev/null) || { echo "  skip $1 $2 (no such key)"; return 0; }
    [ "$old" = "$3" ] && return 0
    mkdir -p "$BACKUP"
    undo "gsettings set $1 $2 $(printf '%q' "$old")"
    gsettings set "$1" "$2" "$3"
}

packages() {
    say "apt"
    sudo apt-get update
    sudo apt-get install -y "${APT[@]}"
    if ! command -v starship >/dev/null; then
        say "starship (to ~/.local/bin)"
        mkdir -p "$HOME/.local/bin"
        curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"
    fi
}

fonts() {
    say "fonts"
    link "$DOTS/config/fonts" .local/share/fonts/glyph
    # icons in the bar, eza and starship; apt has no nerd fonts
    # not `fc-list | grep -q`: grep quits early, fc-list dies of SIGPIPE, and pipefail reads that as "not found"
    if ! fc-list : family | grep -i "JetBrainsMono Nerd" >/dev/null; then
        local tmp; tmp=$(mktemp -d)
        curl -fsSL -o "$tmp/jb.zip" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
        mkdir -p "$HOME/.local/share/fonts/JetBrainsMonoNerd"
        unzip -oq "$tmp/jb.zip" '*.ttf' -d "$HOME/.local/share/fonts/JetBrainsMonoNerd"
        rm -rf "$tmp"
        undo "rm -rf '$HOME/.local/share/fonts/JetBrainsMonoNerd'"
        echo "  ~/.local/share/fonts/JetBrainsMonoNerd"
    fi
    fc-cache -f >/dev/null
}

configs() {
    say "configs (old files → $BACKUP)"
    link "$G/term/starship.toml" .config/starship.toml
    link "$G/term/btop" .config/btop
    link "$G/term/cava" .config/cava
    link "$U/gtk/gtk.css" .config/gtk-3.0/gtk.css
    link "$U/gtk/gtk.css" .config/gtk-4.0/gtk.css
    link "$U/ghostty" .config/ghostty
    link "$DOTS/config/fish/config.fish" .config/fish/config.fish
    link "$DOTS/config/fish/functions/fish_greeting.fish" .config/fish/functions/fish_greeting.fish
    # fastfetch: the rice's, but the SHELL line says the real shell, not quickshell
    local ff="$HOME/.config/fastfetch"
    if [ ! -L "$ff/logo.txt" ] || [ "$(readlink "$ff/logo.txt")" != "$G/term/fastfetch/logo.txt" ]; then
        if [ -e "$ff" ] || [ -L "$ff" ]; then mkdir -p "$BACKUP/.config"; mv "$ff" "$BACKUP/.config/fastfetch"; undo "rm -rf '$ff'; mv '$BACKUP/.config/fastfetch' '$ff'"
        else undo "rm -rf '$ff'"; fi
        mkdir -p "$ff"
        ln -s "$G/term/fastfetch/logo.txt" "$ff/logo.txt"
        echo "  ~/.config/fastfetch"
    fi
    sed 's|{ "type": "command", "key": "SHELL     ", "text": "echo quickshell · glyph" }|{ "type": "shell", "key": "SHELL     " }|' \
        "$G/term/fastfetch/config.jsonc" > "$ff/config.jsonc"
    # starship in bash too, for as long as bash is the shell
    if ! grep -q 'starship init bash' "$HOME/.bashrc" 2>/dev/null; then
        echo 'command -v starship >/dev/null && eval "$(starship init bash)" # glyph-rice' >> "$HOME/.bashrc"
        undo "sed -i '/# glyph-rice\$/d' '$HOME/.bashrc'"
    fi
}

wallpaper() {
    say "wallpaper"
    local out="$HOME/Pictures/Wallpapers/glyph-dots.png" tmp
    mkdir -p "$(dirname "$out")"
    tmp=$(mktemp --suffix=.png)
    python3 "$U/wallpaper.py" "$tmp" 2880x1800
    if cmp -s "$tmp" "$out"; then
        rm "$tmp"
    else
        if [ -e "$out" ]; then
            mkdir -p "$BACKUP/Pictures/Wallpapers"
            mv "$out" "$BACKUP/Pictures/Wallpapers/"
            undo "cp '$BACKUP/Pictures/Wallpapers/glyph-dots.png' '$out'"
        else
            undo "rm -f '$out'"
        fi
        mv "$tmp" "$out"
        chmod 644 "$out"
        echo "  $out"
    fi
    gs org.gnome.desktop.background picture-uri "'file://$out'"
    gs org.gnome.desktop.background picture-uri-dark "'file://$out'"
    gs org.gnome.desktop.background picture-options "'zoom'"
    gs org.gnome.desktop.background primary-color "'#000000'"
    gs org.gnome.desktop.screensaver picture-uri "'file://$out'"
}

gnome() {
    say "GNOME"
    # top bar: the extension lives in the repo; an older copy (glyph-bar@local) steps aside
    local dir="$HOME/.local/share/gnome-shell/extensions"
    link "$U/gnome-shell/$EXT" ".local/share/gnome-shell/extensions/$EXT"
    if [ -d "$dir/glyph-bar@local" ]; then
        mkdir -p "$BACKUP/.local/share/gnome-shell/extensions"
        mv "$dir/glyph-bar@local" "$BACKUP/.local/share/gnome-shell/extensions/"
        undo "mv '$BACKUP/.local/share/gnome-shell/extensions/glyph-bar@local' '$dir/'"
    fi
    local on
    on=$(gsettings get org.gnome.shell enabled-extensions | python3 -c "
import ast, sys
s = sys.stdin.read().strip()
l = [e for e in ast.literal_eval(s.removeprefix('@as ')) if e != 'glyph-bar@local']
print(repr(l if '$EXT' in l else l + ['$EXT']))")
    gs org.gnome.shell enabled-extensions "$on"
    gs org.gnome.shell disable-user-extensions false

    # black, white, one red: Yaru's red accent is the closest stock theme; gtk.css paints over it
    gs org.gnome.desktop.interface color-scheme "'prefer-dark'"
    gs org.gnome.desktop.interface gtk-theme "'Yaru-red-dark'"
    # Glyph-Mono (ubuntu/mono-icons.py) once it's built; the dock's snap icons point at it, so don't step back to Yaru-red
    if [ -f "$HOME/.local/share/icons/Glyph-Mono/index.theme" ]; then
        gs org.gnome.desktop.interface icon-theme "'Glyph-Mono'"
    else
        gs org.gnome.desktop.interface icon-theme "'Yaru-red'"
    fi
    gs org.gnome.desktop.interface font-name "'Space Grotesk 11'"
    gs org.gnome.desktop.interface document-font-name "'Space Grotesk 11'"
    gs org.gnome.desktop.interface monospace-font-name "'Space Mono 11'"
    gs org.gnome.desktop.wm.preferences titlebar-font "'Space Grotesk Bold 11'"
    gs org.gnome.desktop.interface clock-format "'24h'"
    gs org.gnome.desktop.interface enable-hot-corners false

    # Ubuntu Dock in the bar's place: left, black, dots for running apps
    local d=org.gnome.shell.extensions.dash-to-dock
    gs $d dock-position "'LEFT'"
    gs $d extend-height true
    gs $d transparency-mode "'FIXED'"
    gs $d custom-background-color true
    gs $d background-color "'#000000'"
    gs $d background-opacity 1.0
    gs $d running-indicator-style "'DOTS'"
    gs $d custom-theme-customize-running-dots true
    gs $d custom-theme-running-dots-color "'#D71921'"
    gs $d custom-theme-running-dots-border-width 0
    gs $d dash-max-icon-size 44
}

shell() {
    local fish; fish=$(command -v fish) || { echo "fish is not installed: run without --links first"; return 1; }
    [ "$(getent passwd "$USER" | cut -d: -f7)" = "$fish" ] && return 0
    say "login shell → fish"
    undo "chsh -s '$(getent passwd "$USER" | cut -d: -f7)'"
    chsh -s "$fish"
}

grep -qi ubuntu /etc/os-release || echo "not Ubuntu: apt names and GNOME keys may differ"
[[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]] || echo "not in a GNOME session: GNOME settings apply when you log into one"

LINKS_ONLY=0 FISH=0
for a in "$@"; do
    case $a in
        --links) LINKS_ONLY=1 ;;
        --fish) FISH=1 ;;
        *) sed -n '2,10p' "$0"; exit 1 ;;
    esac
done

[ $LINKS_ONLY = 1 ] || packages
fonts
configs
wallpaper
gnome
[ $FISH = 0 ] || shell

say "done"
echo "log out and back in: GNOME picks up a new shell extension only on login (Wayland)"
[ -d "$BACKUP" ] && echo "replaced files are in $BACKUP; $UNDO puts them back"
