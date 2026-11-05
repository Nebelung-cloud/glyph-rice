<div align="center">

<img src="assets/title.svg" width="760" alt="Glyph: a Nothing OS rice for Hyprland + Quickshell">

Black, white dots, one red. **rice_nothing** is a fork of [Glyph by Nebelung](https://github.com/Nebelung-cloud/glyph-rice):
everything the original does, plus a full System settings app, the best ideas from every other fork, and a guided installer.

<br>

![Glyph desktop](screenshots/desktop.png)

</div>

<div align="center"><img src="assets/divider-dots.svg" width="720" alt=""></div>

<h2 align="center">What's different in this fork</h2>

Recent changes are in the [changelog](CHANGELOG.md).

**New here**

| | |
|---|---|
| **System app** (`Super` `I`) | Network, Bluetooth, Sound, Display, Workspaces, Power, Battery, Input, Idle, Firewall, Default apps, About. One place for what used to need a terminal. |
| **Drives** | Plugged-in drives mount by themselves, with a page to open them and safely remove them. |
| **Network editor** | Everything `nmtui` can do: Wi-Fi, Ethernet, DSL, InfiniBand, bond, bridge, team, VLAN, IP tunnel and WireGuard connections, with IP, DNS and security fields. |
| **Password windows** | Bluetooth pairing codes, Wi-Fi passwords and admin prompts (polkit) appear as Glyph cards instead of hiding behind the settings. |
| **Workspace overview** (`Super` `Tab`) | Live thumbnails, drag a window to another workspace, set the number of workspaces. A wrap-around limit that the binds respect. |
| **Display arrangement** | Choose which side a second screen sits on, mirror it or turn it off. |
| **File manager choice** | Thunar, Dolphin or Strata, at install or later from System → Apps. Dolphin gets what it needs outside Plasma, like thumbnails and a working "Open With". |
| **Default apps** | One click from a list of apps of the right kind for each category, so a code editor never shows up as a browser. `Super` `E` and `Super` `W` follow your choice. |
| **Lite mode** | Fewer effects for slower machines. Turns on by itself under about 7.5 GB of RAM. |
| **More color** | A saturation control, Extra Dark, and colors that fade instead of jumping. |
| **More looks** | Ribbed glass and color dots on the wallpaper, a hazy lock screen, a bar on the right, volume and brightness in the island. |
| **Two greetd login screens** | The **Lock greeter** has the lock screen's look. The **Dial greeter** brings Nebelung's camera dial and tachometer to greetd, so that look no longer needs SDDM. The original SDDM theme stays available too. |
| **Guided installer** | Menus with tick boxes, a summary before anything changes, `--dry-run` and `--uninstall`. Safe to run again, and it stops with a plain message if a step fails. |
| **Updates** | System → About counts system updates and new versions of the rice, and updates either from one terminal. `install.sh --update` does the rice too. |
| **Moving from KDE Plasma** | `install.sh --fix-plasma` copies Wi-Fi passwords out of KDE Wallet so they connect at boot. |
| **Welcome card** | The keys to know, on first login. |
| **All English** | Code, comments and interface. |

**From other forks, with thanks**

| Feature | Where | Author |
|---|---|---|
| Palettes, top bar, corners dial, GIF tile, RunCat, SDDM theme, lock before sleep | prefs → STYLE, BAR, WINDOWS | [Nebelung](https://github.com/Nebelung-cloud/glyph-rice) |
| No auto-HDR, deck over fullscreen, VPN behind a captive portal, plain kitty, theme icons in the launcher, plain-text names for security, one step per wheel notch, wheel on the volume ring | automatic | [Nebelung](https://github.com/Nebelung-cloud/glyph-rice) `dev` branch |
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

Developed on one laptop: AMD CPU, NVIDIA GPU, one 1080p screen, CachyOS, Hyprland 0.56. Also installed on a second one: Intel and NVIDIA graphics, one screen, EndeavourOS moving from KDE Plasma, Hyprland 0.57.

**Tested:**

- Every System and rice settings page, and the panels, in dark and light. Some were also checked with a palette.
- The update button, with a fake update: one terminal, in front, however many times it's pressed.
- The installer in a throwaway home with fake system commands: a fresh run, a second run, Recommended, Minimal and Custom through a real terminal, saying no at the summary, a refused package install, a failed service, a too-old Hyprland, `--dry-run` and `--uninstall`.
- The greeter's install script the same way, then its login screen as a preview window.
- Every package name in the installer, against the Arch repositories and the AUR.
- A real install from this repository on the second laptop, keeping its SDDM login screen.
- A real session lock with typing, on the development laptop.
- System → Drives with stand-ins for the system tools: the right drives listed, mounting, safely removing, and showing an error.
- The lockout message on a real session lock, using a stand-in PAM file so the real account was never at risk, and Caps Lock detection.
- `--update` in a sandbox against a throwaway copy of the repository: no changes, a new change, a new package, a lock screen change and a local edit.
- `--fix-plasma` on throwaway network profiles, with a stand-in for KDE's wallet tool.
- `--fix-plasma` on the second laptop: its Wi-Fi now connects by itself after a reboot, with no password prompt.

**Not tested yet, so tell me if something breaks:**

- Booting into the Lock greeter or the Dial greeter from this repository's scripts. The Dial greeter was tested as a window with real key presses against a fake greetd: a wrong password refused, the right one starting the chosen session.
- `--update` and the update everything button on a real update, and the pacman notice during a real `pacman` run. The notice's script and the hook's text were tested, but not pacman running it.
- A real `yay` update through the update button.
- Whether `--fix-plasma` read the passwords from a real KDE Wallet, or they were typed. The format comes from KDE's source code.
- Saving a Wi-Fi password typed into the agent during a real connection. The save itself was tested on a throwaway profile.
- The lock screen's keyboard long term on the laptop where it failed. It worked again once that laptop was updated, but the problem couldn't be reproduced, so the safeguard isn't proven to be the reason.
- A real USB drive or phone with mounting by itself, and real mounting from System → Drives. udiskie wasn't installed on the development laptop during testing, and it can't create test disks without admin rights.
- A real lockout on the lock screen or a greeter, and the wording PAM uses there.
- Installing Dolphin from zero through the installer. It was run on the development laptop, where it was already installed, and its menu fix was checked in a sandbox.
- The SDDM option on a real machine.
- A second monitor: display arrangement, per-screen bar auto-hide, the lock's "one screen" option.
- External monitor brightness (DDC), the Intel GPU load reading, a rotated screen.
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
| **System** | network, bluetooth, sound, display, drives, workspaces, power, battery, input, idle, firewall, default apps, about | `Super` `I` |
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
| **Login** | Lock greeter, Dial greeter, or the original SDDM dial theme | |
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
| ![clip](screenshots/clip.png) **Clip** (from the original) | ![greeter](screenshots/greeter.png) **Lock greeter** (preview, username blanked) |
| ![dial](screenshots/login.png) **Dial greeter and SDDM dial theme** (they share this look, screenshot from the original) | ![installer](screenshots/installer.png) **Installer** |

<div align="center"><img src="assets/divider-matrix.svg" width="720" alt=""></div>

<h2 align="center">Install</h2>

```sh
git clone https://github.com/AMM021/rice_nothing ~/.local/share/glyph
~/.local/share/glyph/install.sh
```

It checks your machine and your connection, explains what will happen, and asks which setup you want:

- **Recommended**: the Lock greeter, Thunar (or Dolphin if that's already your file manager), Zen and the starter wallpapers.
- **Custom**: choose the login screen, file manager, browser and extras. Move with the arrow keys, tick with space.
- **Minimal**: only the desktop. Your login screen and browser stay.

All the questions come first. At the summary you can install, change your choices or cancel. After that it asks for your password once and runs to the end by itself, so you can walk away. The one exception is a real package conflict, which pacman has to ask you about. Files it replaces move to `~/.dots-backup-<date>/`. If a step fails it stops and says so, and running it again is safe.

| Flag | What it does |
|---|---|
| `--dry-run` | The same questions, prints what it would do, changes nothing |
| `--yes` | No questions, the Recommended setup |
| `--update` | Gets the newest version, adds any new packages, keeps your choices and settings. Also in System → About, and as `rice update` |
| `--fix-plasma` | Coming from KDE Plasma: copies Wi-Fi passwords out of KDE Wallet into their network profiles, so they connect at boot (it asks only for what the wallet doesn't have), and stops Plasma's `xwaylandvideobridge` starting under Hyprland. Plasma itself isn't touched |
| `--report` | Prints what's useful for fixing a problem. No passwords or network names, safe to paste |
| `--uninstall` | Removes the links, restores your old files and login screen. Packages stay. With `--yes` it doesn't ask first |
| `--links` | Symlinks only, on any distro. The packages are then your own, see below |
| `--file-manager` | A menu to change the file manager. Also in System → Apps |
| `--login-screen` | A menu to change the login screen. Also in System → About |
| `--lock-greeter` | Switches the login screen to the Lock greeter |
| `--dial-greeter` | Switches the login screen to the Dial greeter |
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
| `greeter/` | the Lock greeter, copied to `/var/lib/greetd`, set in `/etc/greetd/config.toml` (the old one is kept as `config.toml.bak`) |
| `greeter-dial/` | the Dial greeter, copied to `/var/lib/greetd/dial`, set in the same file |
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

### Changing your file manager

1. Open System with `Super` `I`, go to **Apps**, and pick **files**.
2. If the one you want is listed, click it. `Super` `E` opens it from then on.
3. If not, press **install or switch file manager**, pick Thunar, Dolphin or Strata in the terminal menu, and enter your password if it asks.

Or from a terminal: `~/.local/share/glyph/install.sh --file-manager`.

### Changing your login screen

The easy way, with nothing to type:

1. Open System with `Super` `I`, go down to **About**, and press **change login screen**. About also shows which one you have now.
2. A terminal opens with a menu. Move with **↑ ↓**, press **Enter** on the one you want.
3. Enter your password when it asks.
4. Reboot. Close the terminal first, and save anything open.

Or from a terminal: `~/.local/share/glyph/install.sh --login-screen`.

If the new one fails at boot, press `Ctrl` `Alt` `F2`, log in, and run `~/.local/share/glyph/install.sh --lock-greeter` to get back to a known one.

### Login screens

| Choice | Runs on | Look |
|---|---|---|
| **Lock greeter** | greetd | The lock screen: big dot clock and password field, with session, user and power lists on the left |
| **Dial greeter** | greetd | Nebelung's camera dial: ←→ turns the session wheel, ↑ reaches power, Tab changes user, and the tachometer revs as you type |
| **SDDM dial theme** | SDDM | The original theme with the same look |
| **Keep what I have** | | Changes nothing |

`--lock-greeter` and `--dial-greeter` switch straight to one without the menu. `--uninstall` brings back the login screen you had before, and also removes the rice's links.

### Coming from KDE Plasma

Plasma keeps Wi-Fi passwords in KDE Wallet, which Hyprland can't reach without Plasma's helper running. So after installing, run this once while connected:

```sh
~/.local/share/glyph/install.sh --fix-plasma
```

Networks found in the wallet are ticked already, so press Enter. The wallet may ask for its own password once. The passwords stay in the wallet and get copied into each network's profile, where anyone with admin access on that machine can read them, like any normally saved Wi-Fi password. Plasma stays installed and usable as a login session.

### Updating

The rice and your system update together:

- **Easiest:** System → About shows new system packages and new rice changes. Press **update everything**. A terminal opens, gets the rice first, then the system.
- **Only the rice:** run `rice update`.
- **If you update your system yourself** with `pacman` or `yay`: at the end it tells you when the rice has new changes. It only tells you, and then you run `rice update`.

An update keeps your settings, and it only asks for a password if a new package or the login screen needs it. Local edits to tracked files make it stop before changing anything, so keep yours in `hypr/user.lua`.

### Troubleshooting

**A drive doesn't show up.** If the system updated its kernel since you last restarted, restart: until then the USB storage driver can't load, and System → Drives says so. Otherwise update first, since the mounting tools were missing from earlier installs, then look in System → Drives. Phones need to be set to file transfer on the phone itself.

**Wi-Fi asks for its password at every boot, or has no internet until you reconnect.** Common after KDE Plasma, which keeps passwords in KDE Wallet, out of reach here. Run `install.sh --fix-plasma` and pick the networks. If it still happens, run `install.sh --report` and send the result.

**`xwaylandvideobridge` runs at every login.** It's a Plasma helper, and `install.sh --fix-plasma` stops it under Hyprland when it finds an autostart entry. If screen sharing from an X11 app then fails, delete the file it names to undo that.

**`sudo` says "Sorry, try again" with the right password.** After 3 failed attempts in a short time, the system locks your account for up to 10 minutes, and the lock rejects even the correct password. Abandoned password prompts count as failures. Wait it out, or check with `faillock --user $USER`. The update button tells you when this is the reason.

**Can't type on the lock screen.** Update first, since a safeguard was added for this. If it still happens, send the output of `install.sh --report`, and say whether it was right after locking or after sleep.

**Reporting a problem.** `install.sh --report` prints the useful details without passwords or network names. Run it while the problem is happening, before reconnecting or restarting anything.

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
| **System** | `networkmanager` · `bluez` · `pipewire` · `pipewire-pulse` · `pipewire-alsa` · `wireplumber` · `upower` · `power-profiles-daemon` · `polkit-gnome` · `gnome-keyring` · `geoclue` · `brightnessctl` · `playerctl` · `libnotify` · `python-dbus` · `python-gobject` · `pacman-contrib` · `xdg-utils` · `gtk3` · `pciutils` · `udisks2` · `gvfs` · `gvfs-mtp` · `gvfs-gphoto2` · `udiskie` · `ntfs-3g` · `exfatprogs` · `dosfstools` |
| **Capture** | `grim` · `slurp` · `imagemagick` · `libvips` · `gpu-screen-recorder` · `cliphist` · `wl-clipboard` |
| **Terminal** | `kitty` · `fish` · `starship` · `fastfetch` · `btop` · `eza` · `zoxide` · `direnv` |
| **Look** | `papirus-icon-theme` · `adw-gtk-theme` · JetBrains Mono Nerd Font · `noto-fonts-emoji` (Emoji 17) · `noto-fonts-cjk` · Bibata · `qtengine` · `darkly` |
| **Login** | `greetd` and `cage` for the Lock and Dial greeters, or `sddm` 0.21+ (Qt 6 greeter) for the theme |
| **Optional** | `thunar`, `dolphin` (with `kio-extras`, `ffmpegthumbs`, `kdegraphics-thumbnailers`, `archlinux-xdg-menu`, `kde-cli-tools`) or [Strata](https://github.com/lgse/strata) · `cava` · `ddcutil` · `ufw` · `tmux` · `python-pywalfox` · `clash-verge-rev` · `nvidia-utils` · `ydotool` · `hyprpicker` · `swappy` · `trash-cli` · `libteam` for team connections |

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
