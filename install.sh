#!/usr/bin/env bash
# Glyph: installs everything on a clean Arch and links the configs from this repo.
#   ./install.sh                   packages + services + symlinks; asks what else from EXTRA to install
#   ./install.sh --with telegram   the same without asking (--with "" — just the rice itself)
#   ./install.sh --links           symlinks only (on an already set-up system)
set -euo pipefail

DOTS="$(cd "$(dirname "$0")" && pwd)"
BACKUP="$HOME/.dots-backup-$(date +%F_%H-%M-%S)"

PACMAN=(
    # base
    base-devel git curl jq python
    # session
    hyprland hypridle hyprsunset hyprpicker xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    sddm quickshell polkit-gnome gnome-keyring geoclue upower xdg-user-dirs
    # sound, network, bluetooth
    pipewire pipewire-pulse pipewire-alsa wireplumber networkmanager bluez bluez-utils power-profiles-daemon
    # System: the bluetooth code and network password window (system/agent.py), the update count in about
    python-dbus python-gobject pacman-contrib
    # utilities called by the binds and the shell
    brightnessctl playerctl wl-clipboard cliphist grim slurp swappy imagemagick libvips libqalculate
    gpu-screen-recorder ydotool libnotify trash-cli
    # terminal and console
    kitty fish starship fastfetch btop cava eza zoxide direnv
    # apps from variables.lua
    thunar pavucontrol
    # fonts (cjk — kaomoji in Charms), icons (Papirus-Dark — the base of the Rice folder theme), a dark base for gtk.css
    ttf-jetbrains-mono-nerd noto-fonts noto-fonts-cjk noto-fonts-emoji papirus-icon-theme adw-gtk-theme
)

AUR=(
    qtengine darkly-bin bibata-cursor-theme-bin
    zen-browser-bin
)

# optional, like caelestia's optional components. What the special workspace binds open — apps in hypr/variables.lua
declare -A EXTRA=(
    [telegram]="telegram-desktop"                                        # Super+D
    [spotify]="spotify-launcher spicetify-cli spicetify-marketplace-bin" # Super+M
    [clash]="clash-verge-rev-bin"                                        # VPN panel, Super+P
)

G=config/quickshell/glyph
# repo path → path in $HOME
LINKS=(
    "config/hypr                                .config/hypr"
    "$G                                         .config/quickshell/glyph"
    "config/quickshell/rice                     .config/quickshell/rice"
    "config/quickshell/rice/rice                .local/bin/rice"
    "config/kitty                               .config/kitty"
    "config/qtengine                            .config/qtengine"
    "$G/term/qtengine.colors                    .config/qtengine.colors"
    "$G/term/starship.toml                      .config/starship.toml"
    "$G/term/fastfetch                          .config/fastfetch"
    "$G/term/btop                               .config/btop"
    "$G/term/cava                               .config/cava"
    "$G/term/gtk-3.0/gtk.css                    .config/gtk-3.0/gtk.css"
    "$G/term/gtk-4.0/gtk.css                    .config/gtk-4.0/gtk.css"
    "config/fish/config.fish                    .config/fish/config.fish"
    "config/fish/functions/fish_greeting.fish   .config/fish/functions/fish_greeting.fish"
    "config/fonts                               .local/share/fonts/glyph"
)

say() { printf '\e[38;2;215;25;33m●\e[0m %s\n' "$*"; }

extras() { # --with or a question → into EXT, installs yay (and from the repo) separately from AUR
    local w; EXT=()
    if [ -z "${WITH+x}" ]; then
        say "what else to install? space-separated, Enter — nothing"
        for w in "${!EXTRA[@]}"; do printf '  %-9s %s\n' "$w" "${EXTRA[$w]}"; done
        read -rp "  > " WITH || true
    fi
    for w in ${WITH//,/ }; do
        [ -n "${EXTRA[$w]-}" ] || { echo "no such thing: $w (there is: ${!EXTRA[*]})"; exit 1; }
        EXT+=(${EXTRA[$w]})
    done
}

packages() {
    say "pacman"
    # pulseaudio modules require pulseaudio itself — pacman wouldn't let it be replaced with pipewire-pulse.
    # As a list, not grep '^pulseaudio-': pulseaudio-alsa and pulseaudio-qt live fine with pipewire
    local pa; pa=$(pacman -Qq pulseaudio-{bluetooth,jack,lirc,rtp,zeroconf,equalizer,equalizer-ladspa} 2>/dev/null || true)
    [ -z "$pa" ] || sudo pacman -R $pa
    pacman -Q pulseaudio &>/dev/null && say "pacman will ask «Remove pulseaudio?» — answer y, it gets replaced by pipewire-pulse"
    # no --noconfirm: on a conflict (pulseaudio → pipewire-pulse) it would answer «no» and abort the install
    sudo pacman -Syu --needed "${PACMAN[@]}"

    if ! command -v yay >/dev/null; then
        say "yay"
        local tmp; tmp="$(mktemp -d)"
        git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
        (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
        rm -rf "$tmp"
    fi

    say "aur"
    # AUR is optional: a package failed — services and links are installed anyway
    yay -S --needed --noconfirm "${AUR[@]}" || say "aur: not everything installed, see above"
    # separately: spicetify failed to build — the AUR core doesn't suffer from it
    [ ${#EXT[@]} -eq 0 ] || yay -S --needed --noconfirm "${EXT[@]}" || say "optional: not everything installed, see above"
}

services() {
    say "services"
    sudo systemctl enable NetworkManager bluetooth power-profiles-daemon
    systemctl is-enabled -q display-manager.service 2>/dev/null || sudo systemctl enable sddm
    systemctl --user enable pipewire-pulse.socket wireplumber ydotool
    sudo usermod -aG input,video "$USER" # ydotool (uinput), brightnessctl
    xdg-user-dirs-update
}

links() {
    say "symlinks (old → $BACKUP)"
    local src dst
    for l in "${LINKS[@]}"; do
        read -r src dst <<<"$l"
        src="$DOTS/$src" dst="$HOME/$dst"
        [ "$(readlink "$dst")" = "$src" ] && continue
        if [ -e "$dst" ] || [ -L "$dst" ]; then
            mkdir -p "$BACKUP/$(dirname "${dst#"$HOME"/}")"
            mv "$dst" "$BACKUP/${dst#"$HOME"/}"
        fi
        mkdir -p "$(dirname "$dst")"
        ln -s "$src" "$dst"
        echo "  $dst"
    done
    # the shell creates rules.json and kitty.conf itself; rice starts glyph and builds the folder theme
    mkdir -p "$HOME/.config/demonshot" "${XDG_STATE_HOME:-$HOME/.local/state}/rice"
    echo glyph > "${XDG_STATE_HOME:-$HOME/.local/state}/rice/shell"
    mkdir -p "$HOME/Pictures/Wallpapers" # the wallpaper picker (Super+Shift+W) looks here
    fc-cache -f >/dev/null
    command -v gsettings >/dev/null || return 0 # --links on a system without GNOME schemas
    # dark mode for Zen, Electron and libadwaita (via the portal) and a dark gtk3 base under our gtk.css
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark
    gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark
}

[ "$EUID" -eq 0 ] && { echo "run as your user, sudo will ask by itself"; exit 1; }

case "${1:-}" in
    --links) links ;; # on any distro (NixOS, Fedora…): packages are then your own, the list is in the README
    ""|--with) command -v pacman >/dev/null || { echo "I only install packages on Arch; on another distro: $0 --links"; exit 1; }
        [ "${1:-}" = --with ] && WITH="${*:2}" # comma- or space-separated
        extras; packages; services; links
        # spicetify needs an already downloaded Spotify logged into an account, so there's nothing to apply before the first launch
        [[ " ${WITH//,/ } " == *" spotify "* ]] && say "spotify: launch it, log in, then spicetify config custom_apps marketplace && spicetify backup apply"
        say "done. reboot and pick Hyprland in sddm" ;;
    *) echo "usage: $0 [--with telegram,spotify,clash | --links]"; exit 1 ;;
esac
