<div align="center">

<img src="assets/title.svg" width="760" alt="Glyph: a Nothing OS rice for Hyprland + Quickshell">

Black, white dots, one red. **rice_nothing** is a fork of [Glyph by Nebelung](https://github.com/Nebelung-cloud/glyph-rice):
everything the original does, plus a full System settings app, the best ideas from every other fork, and a guided installer.

<br>

![Glyph desktop](screenshots/desktop.png)

</div>

<div align="center"><img src="assets/divider-dots.svg" width="720" alt=""></div>

<h2 align="center">What's different in this fork</h2>

**New here**

| | |
|---|---|
| **System app** (`Super` `I`) | Network, Bluetooth, Sound, Display, Workspaces, Power, Battery, Input, Idle, Firewall, Default apps, About. One place for what used to need a terminal. |
| **Network editor** | Everything `nmtui` can do: Wi-Fi, Ethernet, DSL, InfiniBand, bond, bridge, team, VLAN, IP tunnel and WireGuard connections, with IP, DNS and security fields. |
| **Password windows** | Bluetooth pairing codes, Wi-Fi passwords and admin prompts (polkit) appear as Glyph cards instead of hiding behind the settings. |
| **Workspace overview** (`Super` `Tab`) | Live thumbnails, drag a window to another workspace, set the number of workspaces. A wrap-around limit that the binds respect. |
| **Display arrangement** | Choose which side a second screen sits on, mirror it or turn it off. |
| **Default apps** | One click from a list of apps of the right kind for each category, so a code editor never shows up as a browser. `Super` `E` and `Super` `W` follow your choice. |
| **Lite mode** | Fewer effects for slower machines. Turns on by itself under about 7.5 GB of RAM. |
| **More color** | A saturation control, Extra Dark, and colors that fade instead of jumping. |
| **More looks** | Ribbed glass and color dots on the wallpaper, a hazy lock screen, a bar on the right, volume and brightness in the island. |
| **Glyph greeter** | A greetd login screen with the lock screen's look. The SDDM theme stays available as an option. |
| **Guided installer** | Menus with tick boxes, a summary before anything changes, `--dry-run` and `--uninstall`. Safe to run again, and it stops with a plain message if a step fails. |
| **System updates** | System → About counts updates and opens one terminal for them, in front of everything. |
| **Welcome card** | The keys to know, on first login. |
| **All English** | Code, comments and interface. |

**From other forks, with thanks**

| Feature | Where | Author |
|---|---|---|
| Palettes, top bar, corners dial, GIF tile, RunCat, SDDM theme, lock before sleep | prefs → STYLE, BAR, WINDOWS | [Nebelung](https://github.com/Nebelung-cloud/glyph-rice) |
| No auto-HDR, deck over fullscreen, VPN behind a captive portal, plain kitty, theme icons in the launcher | automatic | [Nebelung](https://github.com/Nebelung-cloud/glyph-rice) `dev` branch |
| Live level meter | System → Sound | [Nebelung](https://github.com/Nebelung-cloud/glyph-rice) `dev` branch, [Isaqdn03](https://github.com/Isaqdn03/glyph-rice) |
| Scroll over the workspace dots, scroll over the sliders, first-drag fix | bar, quick settings | [rawnullbyte](https://github.com/rawnullbyte/glyph-rice) |
| External monitor brightness (experimental) | quick settings | [rawnullbyte](https://github.com/rawnullbyte/glyph-rice), [Isaqdn03](https://github.com/Isaqdn03/glyph-rice) |
| Hide the clock, greeting or widgets | prefs → LOOK | [Isaqdn03](https://github.com/Isaqdn03/glyph-rice) |
| Automatic game mode, and what stays on in it | prefs → WINDOWS | [Isaqdn03](https://github.com/Isaqdn03/glyph-rice) |
| Right-click the volume slider for outputs | quick settings | [Isaqdn03](https://github.com/Isaqdn03/glyph-rice) |
| Bar auto-hide per screen (experimental) | prefs → BAR | [Isaqdn03](https://github.com/Isaqdn03/glyph-rice) |
| Wallpaper beat, off by default | wall picker | [Isaqdn03](https://github.com/Isaqdn03/glyph-rice) |
| tmux and Firefox follow the palette | automatic if installed | [Isaqdn03](https://github.com/Isaqdn03/glyph-rice) |
| Hide the password's length, plain cover on other screens | prefs → LOOK | [SenulMapa](https://github.com/SenulMapa/glyph-rice) |
| A rotated first screen no longer shrinks the shell | automatic | [SenulMapa](https://github.com/SenulMapa/glyph-rice) |
| GPU load on Intel integrated graphics | deck, home | [Dimashyt](https://github.com/Dimashyt/glyph-rice) |
| The idea of a corners setting | prefs → WINDOWS | [Shykid002](https://github.com/Shykid002), [GloomyGuava](https://github.com/GloomyGuava/glyph-rice) |

Commits picked directly keep their author. Features ported by hand name their source in the commit message and in a comment beside the code.

<div align="center"><img src="assets/divider-glyph.svg" width="720" alt=""></div>

<h2 align="center">Tested, and not tested</h2>

Developed on one laptop: AMD CPU, NVIDIA GPU, one 1080p screen, CachyOS, Hyprland 0.56.

**Tested:**

- Every System and rice settings page, and the panels, in dark and light. Some were also checked with a palette.
- The update button, with a fake update: one terminal, in front, however many times it's pressed.
- The installer in a throwaway home with fake system commands: a fresh run, a second run, Recommended, Minimal and Custom through a real terminal, saying no at the summary, a refused package install, a failed service, a too-old Hyprland, `--dry-run` and `--uninstall`.
- The greeter's install script the same way, then its login screen as a preview window.
- Every package name in the installer, against the Arch repositories and the AUR.

**Not tested yet, so tell me if something breaks:**

- A real install on a clean system, and the login screen at an actual boot from this repository's script.
- A real `yay` update through the update button.
- Saving a Wi-Fi password typed into the agent during a real connection. The save itself was tested on a throwaway profile.
- The lock screen's keyboard on a machine where it failed. It works on the development laptop, and a safeguard was added without a way to reproduce the problem.
- The SDDM option on a real machine.
- A second monitor: display arrangement, per-screen bar auto-hide, the lock's "one screen" option.
- External monitor brightness (DDC), Intel graphics, a rotated screen.
- Automatic game mode with a real game, and Firefox theming.
- The wallpaper beat. It needs cava, and it stays off until you turn it on.

<div align="center"><img src="assets/divider-glyph.svg" width="720" alt=""></div>

<h2 align="center">What's inside</h2>

| | | |
|---|---|:---:|
| **Bar** | launcher, workspaces, clock, tray; left, right or top | |
| **Home** | clock, greeting, widgets, dot grid; each can be hidden | |
| **Glyph** | screen edges as OSD: volume, brightness, notifications, progress | |
| **Launcher** | apps, style, windows, calculator | `Super` |
| **Quick** | quick settings, game mode, media, notifications; also opens from the screen edge | `Super` `A` |
| **Deck** | dashboard from the bottom edge | `Super` `Space` |
| **System** | network, bluetooth, sound, display, workspaces, power, battery, input, idle, firewall, default apps, about | `Super` `I` |
| **Prefs** | the rice's look: home, deck, bar, look, style, windows | System → customize the rice; esc comes back |
| **Overview** | workspaces as live tiles | `Super` `Tab` |
| **Shot** | screenshots, editor, recording | `Print` |
| **Clip** | clipboard history | `Super` `V` |
| **Charms** | emoji, kaomoji, symbols | `Super` `.` |
| **Walls** | wallpapers as dots | `Super` `Shift` `W` |
| **VPN** | Clash Verge panel | `Super` `P` |
| **Cal** | calendar, focus timer | click the clock |
| **Buds** | Nothing / CMF earbuds: battery, ANC | |
| **Power** | power menu | `Super` `Esc` |
| **Lock** | lock screen | `Super` `L` |
| **Login** | Glyph greeter, or the original SDDM theme with its camera dial and tachometer | |
| **Style** | where the color comes from: Nothing, the wallpaper through a Material You variant, or a palette (Catppuccin, Rosé Pine, Gruvbox, Nord, Dracula, Tokyo Night, Everforest, Kanagawa) | |
| **Rice** | shell switcher, if Demon's Shot is installed too | `rice switch <name>` |

Also: Hyprland (Lua), hypridle, kitty, fish, starship, fastfetch, btop, GTK, Qt and folder colors.

<div align="center"><img src="assets/divider-glyph.svg" width="720" alt=""></div>

<h2 align="center">Screenshots</h2>

Wi-Fi names, Bluetooth devices, the hostname and the laptop model are blanked out in these on purpose.

### Color

![colors fading between sources](screenshots/colors.gif)

| | |
|:---:|:---:|
| ![style, nothing](screenshots/style-nothing.png) **Style: Nothing** | ![style, wallpaper](screenshots/style-wallpaper.png) **Style: from the wallpaper** |
| ![style, palette](screenshots/style-palette.png) **Style: palettes** | ![home on a wallpaper](screenshots/home-wallpaper.png) **Wallpaper as color dots** |
| ![Catppuccin Mocha](screenshots/home-mocha.png) **Catppuccin Mocha** | ![light](screenshots/home-light-nothing.png) **Light** |

### System

| | |
|:---:|:---:|
| ![network](screenshots/system-network.png) **Network** | ![bluetooth](screenshots/system-bluetooth.png) **Bluetooth** |
| ![sound](screenshots/system-sound.png) **Sound, with live levels** | ![display](screenshots/system-display.png) **Display** |
| ![workspaces](screenshots/system-workspaces.png) **Workspaces** | ![power](screenshots/system-power.png) **Power and Lite mode** |
| ![battery](screenshots/system-battery.png) **Battery** | ![input](screenshots/system-input.png) **Input** |
| ![idle](screenshots/system-idle.png) **Idle and lid** | ![firewall](screenshots/system-firewall.png) **Firewall** |
| ![default apps](screenshots/system-apps.png) **Default apps** | ![about](screenshots/system-about.png) **About** |

### The rice's look

| | |
|:---:|:---:|
| ![home](screenshots/prefs-home.png) **Home widgets** | ![deck](screenshots/prefs-deck.png) **Deck** |
| ![bar](screenshots/prefs-bar.png) **Bar** | ![look](screenshots/prefs-look.png) **Look, on home and on the lock** |
| ![windows](screenshots/prefs-windows.png) **Windows, corners and game mode** | ![home hidden](screenshots/home-hidden.png) **Everything hidden on home** |
| ![bar on the right](screenshots/bar-right.png) **Bar on the right, Extra Dark** | ![bar on top](screenshots/bar-top.png) **Bar on top** |

### Panels

| | |
|:---:|:---:|
| ![overview](screenshots/overview.png) **Overview** (thumbnails pixelated here) | ![launcher](screenshots/launcher.png) **Launcher** |
| ![quick](screenshots/quick.png) **Quick** | ![quick on the left](screenshots/quick-bar-right.png) **Quick moves when the bar does** |
| ![deck](screenshots/deck.png) **Deck** | ![calendar](screenshots/cal.png) **Calendar and focus timer** |
| ![charms](screenshots/charms.png) **Charms** | ![walls](screenshots/walls.png) **Wallpapers** |
| ![power](screenshots/power.png) **Power** | ![shot](screenshots/shot.png) **Shot** (from the original) |
| ![clip](screenshots/clip.png) **Clip** (from the original) | ![greeter](screenshots/greeter.png) **Glyph greeter** (preview, username blanked) |
| ![sddm](screenshots/login.png) **SDDM theme, optional** (from the original) | ![installer](screenshots/installer.png) **Installer** |

<div align="center"><img src="assets/divider-matrix.svg" width="720" alt=""></div>

<h2 align="center">Install</h2>

```sh
git clone https://github.com/AMM021/rice_nothing ~/.local/share/glyph
~/.local/share/glyph/install.sh
```

It checks your machine and your connection, explains what will happen, and asks which setup you want:

- **Recommended**: the Glyph login screen, Thunar, Zen and the starter wallpapers.
- **Custom**: choose the login screen, file manager, browser and extras. Move with the arrow keys, tick with space.
- **Minimal**: only the desktop. Your login screen and browser stay.

All the questions come first. At the summary you can install, change your choices or cancel. After that it asks for your password once and runs to the end by itself, so you can walk away. The one exception is a real package conflict, which pacman has to ask you about. Files it replaces move to `~/.dots-backup-<date>/`. If a step fails it stops and says so, and running it again is safe.

| Flag | What it does |
|---|---|
| `--dry-run` | The same questions, prints what it would do, changes nothing |
| `--yes` | No questions, the Recommended setup |
| `--update` | Gets the newest version, adds any new packages, keeps your choices and settings. Also in System → About |
| `--report` | Prints what's useful for fixing a problem. No passwords or network names, safe to paste |
| `--uninstall` | Removes the links, restores your old files and login screen. Packages stay. With `--yes` it doesn't ask first |
| `--links` | Symlinks only, on any distro. The packages are then your own, see below |
| `--sddm` | Only the SDDM theme; run again after editing it |

If a new login screen ever fails: `Ctrl` `Alt` `F2`, log in, run `install.sh --uninstall`.

Wallpapers are read from `~/Pictures/Wallpapers`, and the installer can copy [five CC0 ones](assets/wallpapers) there.
Gifs for the home cat tile come from `~/Pictures/Gifs`: pick one in prefs → home or click the tile. With none there, you get the cat.

| `config/` | goes to |
|---|---|
| `hypr/` | `~/.config/hypr` |
| `quickshell/glyph/` | `~/.config/quickshell/glyph` |
| `quickshell/rice/` | `~/.config/quickshell/rice`, `~/.local/bin/rice` |
| `quickshell/glyph/term/` | `starship.toml` `fastfetch/` `btop/` `cava/` `gtk-*/gtk.css` `qtengine.colors` in `~/.config` (with a Style color, copies in `~/.local/state/rice/glyph`), `glyph-progress.fish` in fish's `conf.d` |
| `kitty/` `qtengine/` | `~/.config/…` |
| `fish/` | `~/.config/fish` |
| `fonts/` | `~/.local/share/fonts/glyph` |
| `greeter/` | copied to `/var/lib/greetd`, set in `/etc/greetd/config.toml` (the old one is kept as `config.toml.bak`) |
| `sddm/glyph/` | copied to `/usr/share/sddm/themes/glyph`, set in `/etc/sddm.conf.d/zz-glyph.conf`; to undo, delete both |

Monitor, backlight, GPU and sensors are detected. Keyboard layouts are in `hypr/hyprland/input.lua`.
Your own binds and overrides go in `hypr/user.lua`: it's gitignored, so `git pull` never touches it.
Apps for the special workspaces and the editor are read when you press the key, so `user.lua` can swap them:

```lua
local apps = require("variables").apps
apps.editor = "codium"              -- Super Shift K, empty by default
apps.todo   = "planify"             -- Super R, empty by default
apps.music  = "spicetify watch -s"  -- Super M, spotify-launcher by default

hl.bind("SUPER + G", hl.dsp.global("shell:game"))  -- game mode has no key by default
```

### Updating

System → About shows when the rice has new changes, with a button that opens a terminal and updates it. Or run `install.sh --update`. It only asks for a password if a new package or the login screen needs it. Local edits to tracked files make it stop before changing anything, so keep yours in `hypr/user.lua`.

### Troubleshooting

**Wi-Fi asks for its password at every boot.** Type it once more on this version: it now saves into the profile. If it still asks, run `install.sh --report` and send the result.


**`sudo` says "Sorry, try again" with the right password.** After 3 failed attempts in a short time, the system locks your account for up to 10 minutes, and the lock rejects even the correct password. Abandoned password prompts count as failures. Wait it out, or check with `faillock --user $USER`. The update button tells you when this is the reason.

**The new login screen doesn't work.** `Ctrl` `Alt` `F2`, log in, run `install.sh --uninstall`. It brings back the login screen you had.

**An app is missing from System → Apps.** The list only shows apps whose `.desktop` file says they are that kind of app (`Categories=`) and can open that type (`MimeType=`). Your current default always stays listed, even if it isn't that kind. An app that declares no categories at all is listed too.

**A panel or widget looks empty.** The VPN panel needs Clash Verge and the audio bars widget needs cava. Both are extras in the installer.

### Sleep on NVIDIA laptops

Some laptops with NVIDIA graphics and firmware that only offers `s2idle` sleep hang on wake. The installer mentions it if yours looks like this, and changes nothing.
What fixed it on the laptop this was developed on was adding these kernel parameters in the bootloader:

```
nvme_core.default_ps_max_latency_us=0 nvidia.NVreg_EnableS0ixPowerManagement=1 pcie_aspm=off
```

They are specific to that hardware, and `pcie_aspm=off` costs some battery life, so try them only if you have the problem.

<div align="center"><img src="assets/divider-glyph.svg" width="720" alt=""></div>

<h2 align="center">Dependencies</h2>

| | |
|---|---|
| **Shell** | `quickshell` (Qt 6.9+) · `hyprland` 0.56+ · `hypridle` · `hyprsunset` · `xdg-desktop-portal-hyprland` · `jq` · `curl` · `python3` · `libqalculate` |
| **System** | `networkmanager` · `bluez` · `pipewire` · `pipewire-pulse` · `pipewire-alsa` · `wireplumber` · `upower` · `power-profiles-daemon` · `polkit-gnome` · `gnome-keyring` · `geoclue` · `brightnessctl` · `playerctl` · `libnotify` · `python-dbus` · `python-gobject` · `pacman-contrib` · `xdg-utils` · `gtk3` · `pciutils` |
| **Capture** | `grim` · `slurp` · `imagemagick` · `libvips` · `gpu-screen-recorder` · `cliphist` · `wl-clipboard` |
| **Terminal** | `kitty` · `fish` · `starship` · `fastfetch` · `btop` · `eza` · `zoxide` · `direnv` |
| **Look** | `papirus-icon-theme` · `adw-gtk-theme` · JetBrains Mono Nerd Font · `noto-fonts-emoji` (Emoji 17) · `noto-fonts-cjk` · Bibata · `qtengine` · `darkly` |
| **Login** | `greetd` and `cage` for the Glyph greeter, or `sddm` 0.21+ (Qt 6 greeter) for the theme |
| **Optional** | `thunar` or [Strata](https://github.com/lgse/strata) · `cava` · `ddcutil` · `ufw` · `tmux` · `python-pywalfox` · `clash-verge-rev` · `nvidia-utils` · `ydotool` · `hyprpicker` · `swappy` · `trash-cli` · `libteam` for team connections |

The VPN panel expects Clash Verge in English.
NixOS: change the `/usr/lib` agent paths in `hypr/hyprland/execs.lua` and the Papirus path in `quickshell/rice/rice`.

<div align="center"><img src="assets/divider-dots.svg" width="720" alt=""></div>

<h2 align="center">Colors</h2>

<div align="center"><img src="assets/palette.svg" width="720" alt="Palette, dark: #000000 #0E0E0E #1A1A1A #2A2A2A #4A4A4A #8C8C8C #F2F2F2 #D71921; light: #E9E9E9 #FFFFFF #F1F1F1 #D9D9D9 #B8B8B8 #6E6E6E #0B0B0B #D71921"></div>

<br>

Dark and light. Red marks the one live thing on screen.
Fonts: Doto, Space Grotesk, Space Mono, JetBrains Mono Nerd Font.

<div align="center"><img src="assets/divider-glyph.svg" width="720" alt=""></div>

<h2 align="center">Inspiration</h2>

- [**Nothing OS**](https://nothing.tech): the look and the Glyph lights.
- [**Doto**](https://github.com/oliverlalan/Doto): the dot matrix font.
- [**Gadgetbridge**](https://codeberg.org/Freeyourgadget/Gadgetbridge): the earbuds protocol in `glyph/ear`.
- [**Caelestia**](https://github.com/caelestia-dots/shell): the original author's earlier shell; the deck and hardware detection follow it.
- [**Glyph**](https://github.com/Nebelung-cloud/glyph-rice) by Nebelung: the rice this fork is built on. All of its design is theirs.

<div align="center"><img src="assets/divider-matrix.svg" width="720" alt=""></div>

<h2 align="center">License</h2>

[GPL-3.0](LICENSE). Fonts are under the [OFL](config/fonts/OFL.txt), cava shaders keep their MIT headers.
Nothing, Nothing OS and Glyph are trademarks of Nothing Technology Ltd; this is a fan project, not affiliated with Nothing.

<div align="center"><img src="assets/divider-dots.svg" width="720" alt=""></div>

<div align="center">

```
ᓚᘏᗢ  · · ·
```

```
⠀⠀⠀⠀⣰⣶⣦⣄⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣤⣶⣶⡆⠀⠀⠀⠀
⠀⠀⠀⢠⣿⣿⣿⣿⣿⣦⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⣶⣿⣿⣿⣿⣿⠀⠀⠀⠀
⠀⠀⠀⢸⣿⣿⣿⣿⣿⣿⣿⣦⡀⠀⠀⠀⠀⠀⠀⢀⣾⣿⣿⣿⣿⣿⣿⣿⡆⠀⠀⠀
⠀⠀⠀⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣄⣀⣀⣀⣀⣰⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀⠀⠀
⠀⠀⠀⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀⠀⠀
⠀⠀⠀⠸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠁⠀⠀⠀
⠀⠀⠀⠀⢿⣿⣿⣿⣿⣿⡿⢿⣿⣿⣿⣿⣿⣿⣿⣿⠿⣿⣿⣿⣿⣿⣿⡏⠀⠀⠀⠀
⠀⠀⠀⠀⣼⣿⣿⣿⣿⡏⠀⠀⢹⣿⣿⣿⣿⣿⣿⠃⠀⠀⣿⣿⣿⣿⣿⣆⠀⠀⠀⠀
⠀⠀⠀⣸⣿⣿⣿⣿⣿⣷⣀⣀⣼⣿⣿⣿⣿⣿⣿⣦⣀⣠⣿⣿⣿⣿⣿⣿⡆⠀⠀⠀
⣀⣠⣤⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣤⣀⡀
⠻⠿⠛⣿⣿⣿⣿⣿⣿⣿⢿⣿⣿⣿⣷⠀⢀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⠛⠿⠇
⠀⢀⣠⣾⣿⣿⣿⣿⣿⣿⡈⢿⣿⣿⣿⠃⠸⣿⣿⣿⡿⢰⣿⣿⣿⣿⣿⣿⣷⣄⠀⠀
⠀⢿⠿⠋⢻⣿⣿⣿⣿⣿⣷⣄⣉⣉⣡⣾⣧⣈⣉⣉⣴⣿⣿⣿⣿⣿⣿⠏⠙⢿⡗⠀
⠀⠀⠀⠀⠀⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠏⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠈⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠟⠁⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠛⠻⠿⢿⣿⣿⣿⣿⠿⠿⠟⠛⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀
```

</div>
