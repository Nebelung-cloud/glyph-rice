#!/usr/bin/env bash
# Glyph installer: asks everything first and shows a summary. After your yes and one password it runs to the end by itself.
#   ./install.sh               the guided install
#   ./install.sh --dry-run     the same questions, prints what it would do and changes nothing
#   ./install.sh --yes         no questions, the Recommended setup
#   ./install.sh --uninstall   takes the links away and puts your old files and login screen back
#   ./install.sh --update      gets the newest version of the rice, adds any new packages, keeps your choices and settings
#   ./install.sh --fix-plasma  coming from KDE Plasma: saves Wi-Fi passwords that were in KDE Wallet, stops Plasma's leftovers starting here
#   ./install.sh --report      prints what's useful for fixing a problem (no passwords or network names), changes nothing
#   ./install.sh --links       symlinks only, on any distro (the packages are then your own, see the README)
#   ./install.sh --lock-greeter  switch the login screen to the Lock greeter (greetd)
#   ./install.sh --dial-greeter  switch the login screen to the Dial greeter (greetd, the SDDM theme's look without SDDM)
#   ./install.sh --sddm        only the SDDM login theme; run again after edits in config/sddm
set -Eeuo pipefail

DOTS="$(cd "$(dirname "$0")" && pwd)"
BACKUP="$HOME/.dots-backup-$(date +%F_%H-%M-%S)"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/rice"
DRY=0 YES=0
SETUP=recommended LOGIN=greeter FILES=thunar BROWSER=zen EXTRAS=(wallpapers)
MIN_HYPRLAND=0.56

PACMAN=(
    # base
    base-devel git curl jq python
    # session
    hyprland hypridle hyprsunset hyprpicker xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    quickshell polkit-gnome gnome-keyring geoclue upower xdg-user-dirs xdg-utils
    # sound, network, bluetooth
    pipewire pipewire-pulse pipewire-alsa wireplumber networkmanager bluez bluez-utils power-profiles-daemon
    # System: the bluetooth code and network password window (system/agent.py), the update count in about
    python-dbus python-gobject pacman-contrib
    # utilities called by the binds and the shell; gtk3 for gtk-launch, the file manager and browser binds use it
    brightnessctl playerctl wl-clipboard cliphist grim slurp swappy imagemagick libvips libqalculate
    gpu-screen-recorder ydotool libnotify trash-cli gtk3 pciutils
    # terminal and console
    kitty fish starship fastfetch btop eza zoxide direnv
    # the sound settings bind
    pavucontrol
    # fonts (cjk — kaomoji in Charms), icons (Papirus-Dark — the base of the Rice folder theme), a dark base for gtk.css
    ttf-jetbrains-mono-nerd noto-fonts noto-fonts-cjk noto-fonts-emoji papirus-icon-theme adw-gtk-theme
)
AUR=(qtengine darkly-bin bibata-cursor-theme-bin)

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
    "$G/term/glyph-progress.fish                .config/fish/conf.d/glyph-progress.fish"
    "config/fish/config.fish                    .config/fish/config.fish"
    "config/fish/functions/fish_greeting.fish   .config/fish/functions/fish_greeting.fish"
    "config/fonts                               .local/share/fonts/glyph"
)

# ---- output ----
RED=$'\e[38;2;215;25;33m' DIM=$'\e[2m' BOLD=$'\e[1m' OFF=$'\e[0m'
# set -E: a step that fails anywhere stops here with one plain sentence. Not inside $(...), where it would end up in the captured value
trap '[ "$BASH_SUBSHELL" != 0 ] || printf "\n%s●%s Stopped at the step above. Nothing after it ran. Fix what it says, then run this again: it is safe to repeat.\n" "$RED" "$OFF" >&2' ERR
say() { printf '%s●%s %s\n' "$RED" "$OFF" "$*"; }
note() { printf '  %s%s%s\n' "$DIM" "$*" "$OFF"; }
head1() { printf '\n%s%s%s\n\n' "$BOLD" "$*" "$OFF"; }
# everything that changes the machine goes through here, so --dry-run can't touch it
run() {
    if [ "$DRY" = 1 ]; then printf '  %swould run:%s %s\n' "$DIM" "$OFF" "$*"; else "$@"; fi
}

# ---- menus: arrows or j/k move, space ticks, enter confirms. No extra packages, so they work before anything is installed ----
key() {
    local k rest
    IFS= read -rsn1 k </dev/tty || { REPLY=enter; return; }
    if [ "$k" = $'\e' ]; then
        IFS= read -rsn2 -t 0.05 rest </dev/tty || rest=""
        case "$rest" in '[A') REPLY=up ;; '[B') REPLY=down ;; *) REPLY=esc ;; esac
        return
    fi
    case "$k" in
        '') REPLY=enter ;;
        ' ') REPLY=space ;;
        k) REPLY=up ;;
        j) REPLY=down ;;
        a) REPLY=all ;;
        *) REPLY=other ;;
    esac
}
interactive() { [ "$YES" = 0 ] && [ -r /dev/tty ] && [ -w /dev/tty ] && { : </dev/tty; } 2>/dev/null; }

# pick one: pick "question" default "id|label|what it does"… → PICKED
pick() {
    local q=$1 def=$2 at=0 i n id label what; shift 2
    local items=("$@")
    n=${#items[@]}
    for i in "${!items[@]}"; do [ "${items[$i]%%|*}" = "$def" ] && at=$i; done
    if ! interactive; then PICKED=$def; return; fi
    printf '%s%s%s\n%s↑↓ move · enter choose%s\n\n' "$BOLD" "$q" "$OFF" "$DIM" "$OFF" >/dev/tty
    while :; do
        for i in "${!items[@]}"; do
            IFS='|' read -r id label what <<<"${items[$i]}"
            if [ "$i" = "$at" ]; then printf '\e[2K  %s●%s %s%s%s\n' "$RED" "$OFF" "$BOLD" "$label" "$OFF" >/dev/tty
            else printf '\e[2K  ○ %s\n' "$label" >/dev/tty; fi
            printf '\e[2K    %s%s%s\n' "$DIM" "$what" "$OFF" >/dev/tty
        done
        key
        case "$REPLY" in
            up) at=$(((at + n - 1) % n)) ;;
            down) at=$(((at + 1) % n)) ;;
            enter) break ;;
        esac
        printf '\e[%dA' $((n * 2)) >/dev/tty
    done
    printf '\n' >/dev/tty
    PICKED=${items[$at]%%|*}
}

# tick any: ticks "question" "id|label|what it does|on or off"… → TICKED (array)
ticks() {
    local q=$1 at=0 i n id label what on; shift
    local items=("$@") state=()
    n=${#items[@]}
    for i in "${!items[@]}"; do IFS='|' read -r id label what on <<<"${items[$i]}"; state[i]=${on:-off}; done
    if interactive; then
        printf '%s%s%s\n%s↑↓ move · space tick · a all or none · enter done%s\n\n' "$BOLD" "$q" "$OFF" "$DIM" "$OFF" >/dev/tty
        while :; do
            for i in "${!items[@]}"; do
                IFS='|' read -r id label what on <<<"${items[$i]}"
                local box='[ ]'; [ "${state[i]}" = on ] && box="[${RED}x${OFF}]"
                local arrow=' '; [ "$i" = "$at" ] && arrow="${RED}›${OFF}"
                printf '\e[2K%s %s %-22s %s%s%s\n' "$arrow" "$box" "$label" "$DIM" "$what" "$OFF" >/dev/tty
            done
            key
            case "$REPLY" in
                up) at=$(((at + n - 1) % n)) ;;
                down) at=$(((at + 1) % n)) ;;
                space) [ "${state[at]}" = on ] && state[at]=off || state[at]=on ;;
                all)
                    local to=on
                    for i in "${!items[@]}"; do [ "${state[i]}" = on ] && to=off; done
                    for i in "${!items[@]}"; do state[i]=$to; done ;;
                enter) break ;;
            esac
            printf '\e[%dA' "$n" >/dev/tty
        done
        printf '\n' >/dev/tty
    fi
    TICKED=()
    for i in "${!items[@]}"; do [ "${state[i]}" = on ] && TICKED+=("${items[$i]%%|*}"); done
    return 0
}

ask_yes() { # ask_yes "question" y|n
    local a
    interactive || { [ "$2" = y ]; return; }
    while :; do
        read -rp "$1 [$([ "$2" = y ] && echo Y/n || echo y/N)] " a </dev/tty
        case "${a:-$2}" in y | Y | yes) return 0 ;; n | N | no) return 1 ;; esac
    done
}

# ---- what the choices mean ----
extras_packages() { # id → packages; "aur:" goes through yay
    case "$1" in
        telegram) echo "telegram-desktop" ;;
        spotify) echo "spotify-launcher aur:spicetify-cli aur:spicetify-marketplace-bin" ;;
        vpn) echo "aur:clash-verge-rev-bin" ;;
        firewall) echo "ufw" ;;
        cava) echo "cava" ;;
        brightness) echo "ddcutil" ;;
        firefox-theme) echo "aur:python-pywalfox" ;;
        tmux) echo "tmux" ;;
    esac
}
browser_package() { case "$1" in zen) echo "aur:zen-browser-bin" ;; firefox) echo "firefox" ;; chromium) echo "chromium" ;; chrome) echo "aur:google-chrome" ;; esac; }
browser_desktop() { case "$1" in zen) echo "zen.desktop" ;; firefox) echo "firefox.desktop" ;; chromium) echo "chromium.desktop" ;; chrome) echo "google-chrome.desktop" ;; esac; }

current_dm() { systemctl show -p Id --value display-manager.service 2>/dev/null | sed 's/\.service$//' | grep -v '^display-manager$' || true; }
strata_present() { command -v strata >/dev/null || [ -x "$HOME/.local/bin/strata" ] || flatpak info io.github.lgse.Strata &>/dev/null; }

# ---- the steps ----
check_machine() {
    head1 "Checking this machine"
    command -v pacman >/dev/null || { say "This installer needs an Arch-based system. On another distro: $0 --links, and install the packages from the README yourself."; exit 1; }
    note "system:    $(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-unknown}")"
    note "memory:    $(awk '/MemTotal/ {printf "%.1f GB", $2/1048576}' /proc/meminfo)$(awk '/MemTotal/ && $2 < 7500000 {print " · Lite mode turns on by itself"}' /proc/meminfo)"
    note "graphics:  $(lspci 2>/dev/null | grep -E 'VGA|3D' | sed -E 's/^[^:]*: *[^:]*: *//' | cut -c1-60 | paste -sd'·' || echo unknown)"
    note "login now: $(current_dm | grep . || echo none)"
    if command -v curl >/dev/null && ! curl -fsI --max-time 10 https://archlinux.org >/dev/null; then
        say "No internet connection, and the install needs one. Connect, then run this again."
        exit 1
    fi
    local v
    v=$(pacman -Si hyprland 2>/dev/null | awk '/^Version/ {print $3; exit}' | cut -d- -f1)
    if [ -n "$v" ] && [ "$(vercmp "$v" "$MIN_HYPRLAND")" -lt 0 ]; then
        say "Your repositories have Hyprland $v, and this rice needs $MIN_HYPRLAND or newer (its config is written in Lua)."
        ask_yes "Continue anyway?" n || exit 1
    else
        note "hyprland:  ${v:-unknown} (needs $MIN_HYPRLAND or newer)"
    fi
    pacman -Q sddm &>/dev/null && note "sddm:      installed; it stays unless you pick another login screen"
    return 0
}

explain() {
    head1 "What this does"
    cat <<EOF
  • Installs the desktop: Hyprland, the Glyph shell, fonts, icons and the apps it calls.
  • Links the configs from this folder into your home, so 'git pull' updates them.
  • Moves anything it replaces to $BACKUP first.
  • Asks everything first. Nothing changes until you accept the summary, and after your password it needs nothing more from you.
  • './install.sh --uninstall' undoes it.

EOF
}

choose() {
    [ "$YES" = 1 ] && return 0
    pick "Which setup?" recommended \
        "recommended|Recommended|The Lock greeter, Thunar, Zen browser, starter wallpapers." \
        "custom|Custom|Choose the login screen, apps and extras yourself." \
        "minimal|Minimal|Only the desktop. Keeps your login screen and browser, no extras."
    SETUP=$PICKED
    case "$SETUP" in
        minimal) LOGIN=keep BROWSER=keep EXTRAS=() ;;
        custom) customize ;;
    esac
}

tick_state() { # tick_state <id>: on if it's already chosen
    case " ${EXTRAS[*]:-} " in *" $1 "*) echo on ;; *) echo off ;; esac
}

customize() {
    local dm; dm=$(current_dm)
    pick "Login screen?" "$LOGIN" \
        "greeter|Lock greeter|Looks like the lock screen: big dot clock, password field. Through greetd. Recommended." \
        "dial|Dial greeter|A camera dial and tachometer that revs as you type, by Nebelung. Through greetd, no SDDM." \
        "sddm|SDDM dial theme|The same dial as the original SDDM theme. Installs SDDM, which the Dial greeter avoids." \
        "keep|Keep what I have|${dm:-No display manager}: nothing changes."
    LOGIN=$PICKED

    pick "File manager? (Super+E)" "$FILES" \
        "thunar|Thunar|Small and simple, installed from the repositories." \
        "strata|Strata|Must be installed separately$(strata_present && echo ', found on this machine' || echo ', not found yet: Thunar is set until it is')."
    FILES=$PICKED

    pick "Browser? (Super+W)" "$BROWSER" \
        "zen|Zen|From the AUR." \
        "firefox|Firefox|From the repositories." \
        "chromium|Chromium|From the repositories." \
        "chrome|Google Chrome|From the AUR." \
        "keep|Keep what I have|Installs no browser."
    BROWSER=$PICKED

    ticks "Extras?" \
        "wallpapers|Starter wallpapers|five wallpapers in ~/Pictures/Wallpapers|$(tick_state wallpapers)" \
        "telegram|Telegram|its own workspace on Super+D|$(tick_state telegram)" \
        "spotify|Spotify|its own workspace on Super+M, with Spicetify|$(tick_state spotify)" \
        "vpn|Clash Verge|the VPN panel on Super+P|$(tick_state vpn)" \
        "firewall|Firewall (ufw)|blocks incoming connections, and System gets a page for it|$(tick_state firewall)" \
        "cava|Cava|the audio bars widget and the wallpaper beat, both off until you turn them on|$(tick_state cava)" \
        "brightness|External brightness|ddcutil: the brightness slider for external monitors, experimental|$(tick_state brightness)" \
        "firefox-theme|Firefox theming|python-pywalfox: Firefox follows your colors, needs its add-on too|$(tick_state firefox-theme)" \
        "tmux|tmux|with colors that follow your theme|$(tick_state tmux)"
    EXTRAS=("${TICKED[@]}")
}

summary() {
    local label
    while :; do
        head1 "Summary"
        case "$LOGIN" in greeter) label="Lock greeter (greetd)" ;; dial) label="Dial greeter (greetd)" ;; sddm) label="SDDM dial theme" ;; *) label="keep what you have" ;; esac
        printf '  %-16s %s\n' "login screen" "$label" "file manager" "$FILES" "browser" "$BROWSER" "extras" "${EXTRAS[*]:-none}" "old files go to" "$BACKUP"
        printf '\n'
        if [ "$LOGIN" != keep ] && [ -n "$(current_dm)" ] && [ "$(current_dm)" != "$([ "$LOGIN" = sddm ] && echo sddm || echo greetd)" ]; then
            note "$(current_dm) gets disabled so the new login screen can take over; --uninstall brings it back."
        fi
        if pacman -Q pulseaudio &>/dev/null; then note "pulseaudio gets replaced by pipewire-pulse."; fi
        if [ "$DRY" = 1 ]; then note "dry run: nothing below is actually done"; fi
        printf '\n'
        pick "Ready?" install \
            "install|Install|After your password it runs to the end by itself. It can take a while, you can walk away." \
            "change|Change my choices|Go through the login screen, apps and extras again." \
            "cancel|Cancel|Nothing has changed."
        case "$PICKED" in
            install) return 0 ;;
            change) customize ;;
            cancel) say "Nothing changed."; exit 0 ;;
        esac
    done
}

# one password, then the installer keeps sudo alive so nothing stops to ask again
KEEPER=""
sudo_once() {
    [ "$DRY" = 1 ] && return 0
    if sudo -n true 2>/dev/null; then :; else
        head1 "Your password, once"
        sudo -v
    fi
    ( trap - ERR; set +e; while kill -0 $$ 2>/dev/null; do sudo -n true; sleep 50; done ) >/dev/null 2>&1 &
    KEEPER=$!
    trap '[ -z "$KEEPER" ] || kill "$KEEPER" 2>/dev/null || true' EXIT
}

packages() {
    head1 "Installing packages"
    local main=("${PACMAN[@]}") aur=("${AUR[@]}") p
    add() { for p in "$@"; do case "$p" in aur:*) aur+=("${p#aur:}") ;; *) main+=("$p") ;; esac; done; }
    [ "$FILES" = thunar ] && main+=(thunar)
    # thunar anyway if strata isn't there yet: Super+E needs something to open
    [ "$FILES" = strata ] && ! strata_present && main+=(thunar)
    case "$LOGIN" in greeter | dial) main+=(greetd cage) ;; sddm) main+=(sddm) ;; esac
    [ "$BROWSER" = keep ] || add $(browser_package "$BROWSER")
    for p in "${EXTRAS[@]}"; do add $(extras_packages "$p"); done

    # pulseaudio modules require pulseaudio itself — pacman wouldn't let it be replaced with pipewire-pulse.
    # As a list, not grep '^pulseaudio-': pulseaudio-alsa and pulseaudio-qt live fine with pipewire
    local pa; pa=$(pacman -Qq pulseaudio-{bluetooth,jack,lirc,rtp,zeroconf,equalizer,equalizer-ladspa} 2>/dev/null || true)
    [ -z "$pa" ] || run sudo pacman -R --noconfirm $pa
    # --noconfirm answers «no» to replacing it, so it goes first; pipewire-pulse takes over in the next step
    if pacman -Q pulseaudio &>/dev/null; then run sudo pacman -Rdd --noconfirm pulseaudio; fi
    # an old keyring rejects new packages as badly signed, a common stop on a fresh system
    run sudo pacman -Sy --needed --noconfirm archlinux-keyring || note "Keyring not updated, continuing."
    # a real conflict can't be answered for you: only then does pacman get to ask
    if ! run sudo pacman -Syu --needed --noconfirm "${main[@]}"; then
        say "pacman needs a decision, so here it is:"
        run sudo pacman -Syu --needed "${main[@]}"
    fi

    if ! command -v yay >/dev/null; then
        say "yay, for packages from the AUR"
        if [ "$DRY" = 1 ]; then
            note "would build yay-bin from aur.archlinux.org"
        else
            local tmp; tmp="$(mktemp -d)"
            git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
            (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
            rm -rf "$tmp"
        fi
    fi
    # the AUR is optional: a package failed — services and links are installed anyway
    run yay -S --needed --noconfirm "${aur[@]}" || say "AUR: not everything installed, see above"
}

services() {
    head1 "Turning on services"
    # one that can't be enabled (tlp holds power-profiles-daemon's place, no user session yet) shouldn't stop the rest
    local s
    for s in NetworkManager bluetooth power-profiles-daemon; do
        run sudo systemctl enable "$s" || say "Could not enable $s, see above. The rest continues."
    done
    for s in pipewire-pulse.socket wireplumber ydotool; do
        run systemctl --user enable "$s" || say "Could not enable $s for your user, see above. The rest continues."
    done
    run sudo usermod -aG input,video "$USER" # ydotool (uinput), brightnessctl
    run xdg-user-dirs-update || true
    case " ${EXTRAS[*]:-} " in *" firewall "*)
        run sudo systemctl enable --now ufw
        run sudo ufw --force enable ;; # --force: it would stop to ask otherwise
    esac
}

links() {
    say "Linking configs (old ones → $BACKUP)"
    local src dst
    for l in "${LINKS[@]}"; do
        read -r src dst <<<"$l"
        src="$DOTS/$src" dst="$HOME/$dst"
        # gtk and qt files may point at the shell's recolored copies: those are ours too
        case "$(readlink "$dst" 2>/dev/null)" in "$src" | "$STATE"/glyph/*) continue ;; esac
        if [ -e "$dst" ] || [ -L "$dst" ]; then
            run mkdir -p "$BACKUP/$(dirname "${dst#"$HOME"/}")"
            run mv "$dst" "$BACKUP/${dst#"$HOME"/}"
        fi
        run mkdir -p "$(dirname "$dst")"
        run ln -s "$src" "$dst"
    done
    # the shell creates rules.json and kitty.conf itself; rice starts glyph and builds the folder theme
    run mkdir -p "$HOME/.config/demonshot" "$STATE" "$HOME/Pictures/Wallpapers"
    if [ "$DRY" = 1 ]; then note "would write glyph to $STATE/shell"; else echo glyph >"$STATE/shell"; fi
    # a few wallpapers to start with, in the picker's folder (Super+Shift+W). Yours are never overwritten
    local w
    case " ${EXTRAS[*]:-} " in *" wallpapers "*)
        for w in "$DOTS"/assets/wallpapers/*.jpg; do
            [ -e "$HOME/Pictures/Wallpapers/${w##*/}" ] || run cp "$w" "$HOME/Pictures/Wallpapers/"
        done ;;
    esac
    run fc-cache -f
    command -v gsettings >/dev/null || return 0 # --links on a system without GNOME schemas
    # dark mode for browsers, Electron and libadwaita (via the portal) and a dark gtk3 base under our gtk.css
    # outside a session there's no dbus yet, and the shell sets these again at first login
    run gsettings set org.gnome.desktop.interface color-scheme prefer-dark || true
    run gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark || true
}

default_apps() {
    # Super+E and Super+W open your default apps; System → default apps changes them later
    if [ "$FILES" = strata ] && strata_present; then run xdg-mime default io.github.lgse.Strata.desktop inode/directory
    else run xdg-mime default thunar.desktop inode/directory; fi
    if [ "$BROWSER" != keep ]; then run xdg-mime default "$(browser_desktop "$BROWSER")" x-scheme-handler/http x-scheme-handler/https text/html application/xhtml+xml; fi
    case " ${EXTRAS[*]:-} " in *" tmux "*)
        local conf="$HOME/.config/tmux/tmux.conf"
        grep -qs 'tmux/theme.conf' "$conf" && return 0
        run mkdir -p "$(dirname "$conf")"
        if [ "$DRY" = 1 ]; then note "would add source-file to $conf"
        else echo 'source-file -q ~/.config/tmux/theme.conf # glyph: colors written by the shell' >>"$conf"; fi ;;
    esac
}

sddm_theme() { # login theme. A copy, not a link: the sddm user can't read a private $HOME. fonts in the theme link to config/fonts, -L copies the files themselves
    say "SDDM: the Glyph theme"
    [ -d /usr/share/sddm/themes ] || [ "$DRY" = 1 ] || { say "SDDM isn't installed: nowhere to put the theme"; return 0; }
    # rm: files removed from the repo don't linger in the theme; chmod: under umask 077 the copy would come out 600 and sddm couldn't read it
    run sudo rm -rf /usr/share/sddm/themes/glyph
    run sudo cp -rLT "$DOTS/config/sddm/glyph" /usr/share/sddm/themes/glyph
    run sudo chmod -R a+rX /usr/share/sddm/themes/glyph
    # InputMethod empty: sddm's default is qtvirtualkeyboard, and with this theme a full-screen on-screen keyboard pops up
    run sudo mkdir -p /etc/sddm.conf.d
    # zz-: conf.d files are read alphabetically and the next overrides — ours last, over others (astronaut's virtualkbd.conf)
    run sudo sh -c "printf '[Theme]\nCurrent=glyph\n\n[General]\nInputMethod=\n' > /etc/sddm.conf.d/zz-glyph.conf"
    # /etc/sddm.conf outranks conf.d
    if grep -qsE '^\s*Current=' /etc/sddm.conf && ! grep -qsE '^\s*Current=glyph\s*$' /etc/sddm.conf; then
        say "/etc/sddm.conf sets its own theme and outranks this: set Current=glyph there"
    fi
}

switch_dm() { # switch_dm <new>: remembers the old one for --uninstall
    local old; old=$(current_dm)
    if [ "$old" = "$1" ]; then return 0; fi
    if [ -n "$old" ]; then
        if [ "$DRY" = 1 ]; then note "would remember $old in $STATE/previous-dm"; else mkdir -p "$STATE"; echo "$old" >"$STATE/previous-dm"; fi
        run sudo systemctl disable "$old"
    fi
    run sudo systemctl enable "$1"
}

login_screen() {
    case "$LOGIN" in
        greeter)
            run sudo "$DOTS/config/greeter/install.sh"
            switch_dm greetd ;;
        dial)
            run sudo "$DOTS/config/greeter-dial/install.sh"
            switch_dm greetd ;;
        sddm)
            sddm_theme
            switch_dm sddm ;;
    esac
}

sleep_tip() { # the laptops this happened on: NVIDIA, and firmware that only offers s2idle
    [ -r /sys/power/mem_sleep ] || return 0
    lspci 2>/dev/null | grep -qi nvidia || return 0
    grep -q deep /sys/power/mem_sleep && return 0
    head1 "A note about sleep on this laptop"
    cat <<'EOF'
  It has NVIDIA graphics and its firmware only offers "s2idle" sleep. That combination can hang on wake.
  Nothing was changed for this. If it happens to you, see "Sleep on NVIDIA laptops" in the README.

EOF
}

finish() {
    head1 "Done. Reboot and log in to Hyprland."
    cat <<EOF
  First keys to know:
    Super                launcher           Super+T         terminal
    Super+I              system settings    Super+A         quick settings
    Super+Tab            workspaces         Super+Space     dashboard
    Super+Shift+W        wallpapers         Super+Q         close a window
    Super+L              lock               Super+Escape    power menu

  A welcome card with these appears on your first login.

  To undo all of it:  $0 --uninstall
EOF
    if [ -d "$BACKUP" ]; then printf '  Your old files:     %s\n' "$BACKUP"; fi
    if [ "$LOGIN" = greeter ] || [ "$LOGIN" = dial ]; then
        cat <<EOF

  If the new login screen ever fails: Ctrl+Alt+F2, log in, run  $0 --uninstall
EOF
    fi
    case " ${EXTRAS[*]:-} " in
        *" spotify "*) printf '\n  Spotify: launch it, log in, then: spicetify config custom_apps marketplace && spicetify backup apply\n' ;;
    esac
    case " ${EXTRAS[*]:-} " in
        *" firefox-theme "*) printf '\n  Firefox: add the Pywalfox add-on from addons.mozilla.org. Do not run "pywalfox install" yourself.\n' ;;
    esac
    return 0
}

update() { # step 1: the new code. Bash reads a script as it runs, so step 2 starts fresh from the new file
    local old; old=$(git -C "$DOTS" rev-parse HEAD)
    say "Getting the newest version"
    if ! git -C "$DOTS" pull --ff-only; then
        say "Could not update: there are local changes or no connection, see above. Nothing changed."
        exit 1
    fi
    exec "$DOTS/install.sh" --update-rest "$old"
}

update_rest() { # step 2: whatever the new version needs. Asks for a password only if something needs it
    local old=$1 missing aur_missing
    if [ "$old" = "$(git -C "$DOTS" rev-parse HEAD)" ]; then say "Already up to date."; return 0; fi
    git -C "$DOTS" log --format='  · %s' "$old..HEAD" | cut -c1-100
    # pacman -T lists what isn't installed, and needs no password
    missing=$(pacman -T "${PACMAN[@]}" || true)
    aur_missing=$(pacman -T "${AUR[@]}" || true)
    # the greeter runs from a copy, which only changes when its own files or the lock screen do
    local greeter_changed="" greeter_script=greeter watch='^config/greeter/|glyph/lock/|glyph/Theme.qml|glyph/components/'
    if grep -qs '/dial/' /etc/greetd/config.toml; then greeter_script=greeter-dial watch='^config/greeter-dial/'; fi
    if [ "$(current_dm)" = greetd ] && git -C "$DOTS" diff --name-only "$old" HEAD | grep -qE "$watch"; then greeter_changed=1; fi
    if [ -n "$missing$aur_missing$greeter_changed" ]; then sudo_once; fi
    # shellcheck disable=SC2086 # one package per word
    if [ -n "$missing" ]; then run sudo pacman -S --needed --noconfirm $missing; fi
    # shellcheck disable=SC2086
    if [ -n "$aur_missing" ]; then run yay -S --needed --noconfirm $aur_missing || say "AUR: not everything installed, see above"; fi
    links
    if [ -n "$greeter_changed" ]; then run sudo "$DOTS/config/$greeter_script/install.sh"; fi
    if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then run "$DOTS/config/quickshell/rice/rice" restart; fi
    say "Updated. Your choices and settings are as they were."
}

needs_psk() { # a password network with no password stored
    case "$(nmcli -g 802-11-wireless-security.key-mgmt connection show "$1" 2>/dev/null)" in wpa-psk | sae) ;; *) return 1 ;; esac
    [ -z "$(nmcli -s -g 802-11-wireless-security.psk connection show "$1" 2>/dev/null)" ]
}

# ---- KDE Wallet: Plasma keeps each password in the folder "Network Management" under "{uuid};802-11-wireless-security", as JSON ----
WALLET_KEYS=""
wallet_open() { # one call, so a locked wallet asks once. Empty if there's no wallet, or it stays locked
    command -v kwallet-query >/dev/null || return 0
    say "Opening KDE Wallet to read the saved passwords. It may ask for the wallet's password once."
    WALLET_KEYS=$(timeout 120 kwallet-query -l -f "Network Management" kdewallet 2>/dev/null | grep -F ';802-11-wireless-security' || true)
}
wallet_has() { case "$WALLET_KEYS" in *"{$1};"*) return 0 ;; *) return 1 ;; esac; }
wallet_psk() { # prints the password; nothing if it can't be read
    wallet_has "$1" || return 0
    timeout 30 kwallet-query -r "{$1};802-11-wireless-security" -f "Network Management" kdewallet 2>/dev/null | jq -r '.psk // empty' 2>/dev/null || true
}

fix_plasma() { # things that worked under Plasma because Plasma's own helpers were running
    head1 "Fixing what Plasma left behind"
    # ---- Wi-Fi: a password kept in KDE Wallet (flag 1) or asked for every time (flag 2) isn't there at boot, and a private profile waits for a login ----
    local u name flags perm why items=() active
    active=$(nmcli -g UUID,ACTIVE connection show 2>/dev/null | awk -F: '$2 == "yes" {print $1}')
    local any_wallet="" tick
    while IFS=: read -r u t; do
        if [ "$t" = 802-11-wireless ] && [ "$(nmcli -g 802-11-wireless-security.psk-flags connection show "$u" 2>/dev/null)" = 1 ]; then any_wallet=1; fi
    done < <(nmcli -g UUID,TYPE connection show 2>/dev/null)
    if [ -n "$any_wallet" ]; then wallet_open; fi
    while IFS=: read -r u t; do
        [ "$t" = 802-11-wireless ] || continue
        flags=$(nmcli -g 802-11-wireless-security.psk-flags connection show "$u" 2>/dev/null)
        perm=$(nmcli -g connection.permissions connection show "$u" 2>/dev/null)
        case "$flags" in 1) why="password in KDE Wallet, type it" ;; 2) why="asks every time" ;; *) why="" ;; esac
        tick=off
        case "$active" in *"$u"*) tick=on ;; esac
        # the wallet has it: nothing to type, so it's ticked and Enter does them all
        if wallet_has "$u"; then why="found in KDE Wallet"; tick=on; fi
        # flag 0 only says where a password would be kept: check that one is there. Enterprise and open networks don't have this kind
        if [ -z "$why" ] && needs_psk "$u"; then why="no password saved"; fi
        if [ -z "$why" ] && [ -z "$perm" ]; then continue; fi
        name=$(nmcli -g connection.id connection show "$u" 2>/dev/null | tr -d '|' | cut -c1-22)
        # a menu row is "id|label|what|on"
        items+=("$u|$name|${why:-only connects after login}|$tick")
    done < <(nmcli -g UUID,TYPE connection show 2>/dev/null)
    say "Wi-Fi: ${#items[@]} saved network(s) won't connect by themselves."
    if [ ${#items[@]} -eq 0 ]; then
        say "Wi-Fi: every saved network has its password and can connect at boot, so KDE Wallet isn't the cause."
    else
        ticks "Which networks should connect by themselves at boot?" "${items[@]}"
        for u in "${TICKED[@]}"; do
            name=$(nmcli -g connection.id connection show "$u")
            flags=$(nmcli -g 802-11-wireless-security.psk-flags connection show "$u")
            if [ "$flags" = 1 ] || [ "$flags" = 2 ] || needs_psk "$u"; then
                local p
                p=$(wallet_psk "$u")
                # shorter than any Wi-Fi password: not something usable from the wallet
                if [ ${#p} -lt 8 ]; then p=""; else note "$name: password from KDE Wallet."; fi
                while [ -z "$p" ]; do
                    read -rsp "Password for $name (nothing shows as you type, Enter alone skips it): " p </dev/tty; echo
                    if [ -z "$p" ]; then break; fi
                    if [ ${#p} -ge 8 ]; then break; fi
                    say "Wi-Fi passwords have at least 8 characters."
                    p=""
                done
                if [ -z "$p" ]; then note "Skipped $name."; continue; fi
                if [ "$DRY" = 1 ]; then note "would save the password for $name"; continue; fi
                nmcli connection modify "$u" 802-11-wireless-security.psk-flags 0 802-11-wireless-security.psk "$p" connection.permissions "" \
                    && say "Saved $name." || say "Could not save $name, see above."
            elif [ "$DRY" = 1 ]; then note "would make $name connect before login"
            else
                nmcli connection modify "$u" connection.permissions "" && say "$name now connects before login." || say "Could not change $name, see above."
            fi
        done
    fi
    # ---- autostart: Plasma's helpers that make no sense here. Plasma keeps them, this only applies under Hyprland ----
    local f d found=""
    # an earlier version of this command could leave a junk file here
    find "$HOME/.config/autostart" -maxdepth 1 -type f -name '*●*' -delete 2>/dev/null || true
    # his own entry wins over the system's, so both places count
    for f in $(grep -ls 'xwaylandvideobridge' /etc/xdg/autostart/*.desktop "$HOME"/.config/autostart/*.desktop || true); do
        d=$HOME/.config/autostart/${f##*/}
        found=1
        if grep -qs 'NotShowIn=.*Hyprland' "$d"; then note "xwaylandvideobridge is already stopped under Hyprland."; continue; fi
        if [ "$DRY" = 1 ]; then note "would stop ${f##*/} under Hyprland"; continue; fi
        mkdir -p "$HOME/.config/autostart"
        local body; body=$(grep -v '^NotShowIn=' "$f")
        printf '%s\nNotShowIn=Hyprland;\n' "$body" >"$d"
        say "Stopped xwaylandvideobridge under Hyprland. To undo: delete $d"
    done
    if [ -z "$found" ]; then note "xwaylandvideobridge has no autostart entry here, so something else starts it."; fi
    say "Done. Reboot to check."
}

report() { # safe to paste: nothing here names a network, a device or a password
    set +eE +o pipefail; trap - ERR # a report keeps going past anything it can't read
    printf '== system\n%s · %s\n' "$(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-unknown}")" "$(uname -r)"
    printf 'version: %s\n' "$(git -C "$DOTS" rev-parse --short HEAD 2>/dev/null)"
    printf 'hyprland: %s\n' "$(hyprctl version -j 2>/dev/null | jq -r .tag 2>/dev/null)"
    lspci 2>/dev/null | grep -E 'VGA|3D' | sed -E 's/^[^:]*: *[^:]*: *//' | cut -c1-70
    printf 'login: %s%s · screens: %s · input methods: %s\n' "$(current_dm)" "$(grep -qs '/dial/' /etc/greetd/config.toml && echo ' (dial)')" "$(hyprctl monitors -j 2>/dev/null | jq length 2>/dev/null)" "${QT_IM_MODULE:-none}/${XMODIFIERS:-none}"
    printf '\n== network services\n'
    for s in NetworkManager systemd-networkd dhcpcd iwd wpa_supplicant netctl connman systemd-resolved; do
        printf '%-20s %s %s\n' "$s" "$(systemctl is-enabled "$s" 2>/dev/null || true)" "$(systemctl is-active "$s" 2>/dev/null || true)"
    done
    printf 'resolv.conf: %s · %s nameserver line(s)\n' "$(readlink /etc/resolv.conf || echo plain file)" "$(grep -c '^nameserver' /etc/resolv.conf 2>/dev/null || true)"
    printf '\n== network state\n'
    nmcli -t -f TYPE,STATE device 2>/dev/null
    printf 'internet: %s\n' "$(nmcli networking connectivity check 2>/dev/null || true)"
    printf '\n== saved profiles: type, autoconnect, private to a user?, wi-fi password flag (0 = saved)\n'
    nmcli -g UUID,TYPE connection show 2>/dev/null | while IFS=: read -r u t; do
        printf '%s auto=%s private=%s psk-flags=%s has-password=%s\n' "$t" \
            "$(nmcli -g connection.autoconnect connection show "$u" 2>/dev/null)" \
            "$( [ -n "$(nmcli -g connection.permissions connection show "$u" 2>/dev/null)" ] && echo yes || echo no)" \
            "$(nmcli -g 802-11-wireless-security.psk-flags connection show "$u" 2>/dev/null)" \
            "$( [ -n "$(nmcli -s -g 802-11-wireless-security.psk connection show "$u" 2>/dev/null)" ] && echo yes || echo no)"
    done
    printf '\n== network log, this boot (names removed)\n'
    journalctl -b -u NetworkManager --no-pager -o cat 2>/dev/null | grep -E 'no secrets|no-secrets|failed|secrets|-> failed' | sed -E "s/(connection|point|profile) '[^']*'/\1 '…'/g; s/([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}/MAC/g" | tail -8 | cut -c1-110
    printf '\n== lock\n'
    printf 'lock running: %s\n' "$(pgrep -fc '^qs .*/lock[.]qml' || true)"
    journalctl -b --no-pager -o cat -g 'WlSessionLock|session lock|sessionLock|lock.qml' 2>/dev/null | tail -5 | cut -c1-110
}

uninstall() {
    head1 "Uninstalling"
    [ "$YES" = 1 ] || ask_yes "Remove the links and restore your old files and login screen? Packages stay installed." n || exit 0
    local src dst first
    first=$(find "$HOME" -maxdepth 1 -type d -name '.dots-backup-*' 2>/dev/null | sort | head -n1)
    for l in "${LINKS[@]}"; do
        read -r src dst <<<"$l"
        src="$DOTS/$src" dst="$HOME/$dst"
        # gtk and qt files may point at the shell's recolored copies
        case "$(readlink "$dst" 2>/dev/null)" in
            "$src" | "$STATE"/glyph/*) run rm "$dst" ;;
            *) continue ;;
        esac
        if [ -n "$first" ] && { [ -e "$first/${dst#"$HOME"/}" ] || [ -L "$first/${dst#"$HOME"/}" ]; }; then
            run mv "$first/${dst#"$HOME"/}" "$dst"
        fi
    done
    local old=""
    [ -r "$STATE/previous-dm" ] && old=$(cat "$STATE/previous-dm")
    if [ -n "$old" ]; then
        run sudo systemctl disable "$(current_dm)"
        run sudo systemctl enable "$old"
        run rm "$STATE/previous-dm"
        say "Login screen back to $old."
    elif [ "$(current_dm)" = greetd ] || [ "$(current_dm)" = sddm ]; then
        note "$(current_dm) stays enabled: no earlier login screen is on record."
    fi
    say "Done. Packages, your settings in $STATE and any backup that's left stay in place."
}

# ---- main ----
[ "$EUID" -eq 0 ] && { echo "Run this as your user, sudo will ask by itself."; exit 1; }

MODE=install
for a in "$@"; do
    case "$a" in
        --dry-run) DRY=1 ;;
        --yes | -y) YES=1 ;;
        --uninstall) MODE=uninstall ;;
        --update) MODE=update ;;
        --update-rest) MODE=update-rest ;;
        --report) MODE=report ;;
        --lock-greeter) MODE=lock-greeter ;;
        --dial-greeter) MODE=dial-greeter ;;
        --fix-plasma) MODE=fix-plasma ;;
        --links) MODE=links ;;
        --sddm) MODE=sddm ;;
        [0-9a-f]*) [ "$MODE" = update-rest ] && OLD=$a ;;
        *) echo "usage: $0 [--dry-run] [--yes] [--update] [--fix-plasma] [--report] [--uninstall] [--links] [--lock-greeter] [--dial-greeter] [--sddm]"; exit 1 ;;
    esac
done

case "$MODE" in
    links) links ;;
    sddm) sddm_theme ;;
    lock-greeter | dial-greeter)
        sudo_once
        LOGIN=greeter
        [ "$MODE" = lock-greeter ] || LOGIN=dial
        login_screen
        say "Done. Reboot to see it. If it ever fails: Ctrl+Alt+F2, log in, run  $0 --uninstall"
        ;;
    update) update ;;
    update-rest) update_rest "$OLD" ;;
    report) report ;;
    fix-plasma) fix_plasma ;;
    uninstall) uninstall ;;
    install)
        check_machine
        explain
        choose
        summary
        sudo_once
        packages
        services
        links
        default_apps
        login_screen
        sleep_tip
        finish
        ;;
esac
