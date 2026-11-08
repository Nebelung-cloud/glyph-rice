#!/usr/bin/env bash
# Glyph: ставит всё на чистый Arch и линкует конфиги из этого репо.
#   ./install.sh                   пакеты + сервисы + симлинки; спросит, что из EXTRA поставить ещё
#   ./install.sh --with telegram   то же без вопроса (--with "" — только сам рис)
#   ./install.sh --links           только симлинки (на уже готовой системе)
#   ./install.sh --sddm            только тема входа (sudo); после правок в config/sddm — снова
set -euo pipefail

DOTS="$(cd "$(dirname "$0")" && pwd)"
BACKUP="$HOME/.dots-backup-$(date +%F_%H-%M-%S)"

PACMAN=(
    # база
    base-devel git curl jq python
    # сессия
    hyprland hypridle hyprsunset hyprpicker xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    sddm quickshell polkit-gnome gnome-keyring geoclue upower xdg-user-dirs
    # звук, сеть, bluetooth
    pipewire pipewire-pulse pipewire-alsa wireplumber networkmanager bluez bluez-utils power-profiles-daemon
    # утилиты, которые зовут бинды и шелл
    brightnessctl playerctl wl-clipboard cliphist grim slurp swappy imagemagick libvips libqalculate
    gpu-screen-recorder ydotool libnotify trash-cli
    # терминал и консоль
    kitty fish starship fastfetch btop cava eza zoxide direnv
    # приложения из variables.lua
    thunar pavucontrol
    # шрифты (cjk — каомодзи в Charms), иконки (Papirus-Dark — основа темы папок Rice), тёмная база для gtk.css
    ttf-jetbrains-mono-nerd noto-fonts noto-fonts-cjk noto-fonts-emoji papirus-icon-theme adw-gtk-theme
)

AUR=(
    qtengine darkly-bin bibata-cursor-theme-bin
    zen-browser-bin
)

# на выбор, как optional components у caelestia. Что открывают бинды спец-воркспейсов — apps в hypr/variables.lua
declare -A EXTRA=(
    [telegram]="telegram-desktop"                                        # Super+D
    [spotify]="spotify-launcher spicetify-cli spicetify-marketplace-bin" # Super+M
    [clash]="clash-verge-rev-bin"                                        # панель VPN, Super+P
)

G=config/quickshell/glyph
# репо-путь → путь в $HOME
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
    "$G/term/gtk-3.0/settings.ini               .config/gtk-3.0/settings.ini"
    "$G/term/gtk-4.0/gtk.css                    .config/gtk-4.0/gtk.css"
    "$G/term/gtk-4.0/settings.ini               .config/gtk-4.0/settings.ini"
    "config/fish/config.fish                    .config/fish/config.fish"
    "config/fish/functions/fish_greeting.fish   .config/fish/functions/fish_greeting.fish"
    "config/fonts                               .local/share/fonts/glyph"
)

say() { printf '\e[38;2;215;25;33m●\e[0m %s\n' "$*"; }

extras() { # --with или вопрос → в EXT, ставит yay (и из репо) отдельно от AUR
    local w; EXT=()
    if [ -z "${WITH+x}" ]; then
        say "что ещё поставить? через пробел, Enter — ничего"
        for w in "${!EXTRA[@]}"; do printf '  %-9s %s\n' "$w" "${EXTRA[$w]}"; done
        read -rp "  > " WITH || true
    fi
    for w in ${WITH//,/ }; do
        [ -n "${EXTRA[$w]-}" ] || { echo "нет такого: $w (есть: ${!EXTRA[*]})"; exit 1; }
        EXT+=(${EXTRA[$w]})
    done
}

packages() {
    say "pacman"
    # модули pulseaudio требуют его самого — pacman не дал бы заменить его на pipewire-pulse.
    # Списком, не grep '^pulseaudio-': pulseaudio-alsa и pulseaudio-qt с pipewire живут
    local pa; pa=$(pacman -Qq pulseaudio-{bluetooth,jack,lirc,rtp,zeroconf,equalizer,equalizer-ladspa} 2>/dev/null || true)
    [ -z "$pa" ] || sudo pacman -R $pa
    pacman -Q pulseaudio &>/dev/null && say "pacman спросит «Remove pulseaudio?» — ответь y, его заменит pipewire-pulse"
    # без --noconfirm: на конфликте (pulseaudio → pipewire-pulse) он ответил бы «нет» и уронил установку
    sudo pacman -Syu --needed "${PACMAN[@]}"

    if ! command -v yay >/dev/null; then
        say "yay"
        local tmp; tmp="$(mktemp -d)"
        git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
        (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
        rm -rf "$tmp"
    fi

    say "aur"
    # AUR необязателен: упал пакет — сервисы и ссылки всё равно ставим
    yay -S --needed --noconfirm "${AUR[@]}" || say "aur: встало не всё, см. выше"
    # отдельно: не собрался spicetify — ядро AUR от этого не страдает
    [ ${#EXT[@]} -eq 0 ] || yay -S --needed --noconfirm "${EXT[@]}" || say "на выбор: встало не всё, см. выше"
}

services() {
    say "сервисы"
    sudo systemctl enable NetworkManager bluetooth power-profiles-daemon
    systemctl is-enabled -q display-manager.service 2>/dev/null || sudo systemctl enable sddm
    systemctl --user enable pipewire-pulse.socket wireplumber ydotool
    sudo usermod -aG input,video "$USER" # ydotool (uinput), brightnessctl
    xdg-user-dirs-update
}

links() {
    say "симлинки (старое → $BACKUP)"
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
    # rules.json и kitty.conf шелл создаст сам; rice поднимет glyph и соберёт тему папок
    mkdir -p "$HOME/.config/demonshot" "${XDG_STATE_HOME:-$HOME/.local/state}/rice"
    echo glyph > "${XDG_STATE_HOME:-$HOME/.local/state}/rice/shell"
    mkdir -p "$HOME/Pictures/Wallpapers" # пикер обоев (Super+Shift+W) смотрит сюда
    fc-cache -f >/dev/null
    command -v gsettings >/dev/null || return 0 # --links на системе без GNOME-схем
    # тёмный режим для Zen, Electron и libadwaita (через портал) и тёмная gtk3-база под наш gtk.css
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark
    gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark
}

greeter() { # тема входа. Копия, а не ссылка: пользователь sddm не прочтёт закрытый $HOME. fonts в теме — ссылка на config/fonts, -L копирует сами файлы
    say "sddm: тема glyph"
    [ -d /usr/share/sddm/themes ] || { say "sddm не стоит — тему ставить некуда"; return 0; }
    # rm: файлы, удалённые из репо, не остаются висеть в теме; chmod: при umask 077 копия вышла бы 600 и sddm её не прочтёт
    sudo rm -rf /usr/share/sddm/themes/glyph
    sudo cp -rLT "$DOTS/config/sddm/glyph" /usr/share/sddm/themes/glyph
    sudo chmod -R a+rX /usr/share/sddm/themes/glyph
    # InputMethod пустой: умолчание sddm — qtvirtualkeyboard, и с этой темой вылезает экранная клавиатура на весь экран
    sudo mkdir -p /etc/sddm.conf.d
    # zz-: файлы conf.d читаются по алфавиту, следующий перекрывает — наш последним, поверх чужих (virtualkbd.conf у astronaut)
    printf '[Theme]\nCurrent=glyph\n\n[General]\nInputMethod=\n' | sudo tee /etc/sddm.conf.d/zz-glyph.conf >/dev/null
    # /etc/sddm.conf главнее conf.d
    if grep -qsE '^\s*Current=' /etc/sddm.conf && ! grep -qsE '^\s*Current=glyph\s*$' /etc/sddm.conf; then
        say "в /etc/sddm.conf своя тема, он главнее: поставь там Current=glyph"
    fi
}

[ "$EUID" -eq 0 ] && { echo "запускай от пользователя, sudo спросит сам"; exit 1; }

case "${1:-}" in
    --links) links ;; # на любом дистрибутиве (NixOS, Fedora…): пакеты тогда свои, список — в README
    --sddm) greeter ;;
    ""|--with) command -v pacman >/dev/null || { echo "пакеты ставлю только на Arch; на другом дистрибутиве: $0 --links"; exit 1; }
        [ "${1:-}" = --with ] && WITH="${*:2}" # и через запятую, и через пробел
        extras; packages; services; links; greeter
        # spicetify нужен уже скачанный Spotify с входом в аккаунт, поэтому применять до первого запуска нечего
        [[ " ${WITH//,/ } " == *" spotify "* ]] && say "spotify: запусти, войди, потом spicetify config custom_apps marketplace && spicetify backup apply"
        say "готово. перезагрузись и выбери Hyprland в sddm" ;;
    *) echo "usage: $0 [--with telegram,spotify,clash | --links | --sddm]"; exit 1 ;;
esac
