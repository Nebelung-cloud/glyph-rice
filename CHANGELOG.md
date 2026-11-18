# Changelog

The newest changes come first. To get them, press **update everything** in System → About, or run `install.sh --update`.

## November 2026

### Bluetooth

- Fixed: earbuds paired from Quick could connect and drop at once, then show as unpaired again. Pairing now turns the adapter's pairable setting on for the attempt so the bond is kept, a paired device is only connected (never paired again), and after a first pairing Quick waits a moment and connects only if the buds didn't connect by themselves. Paired devices now sit in their own group above nearby ones. From #31 by rawnullbyte.

### Bar

- New: auto-hide can hide the bar only while the workspace has windows, so an empty desktop keeps it. Turn on **only over windows** under the hide toggles in Prefs → BAR. A panel opened by clicking the bar (launcher, quick settings, power, calendar) now keeps a hidden bar on screen until it closes. From #32 by malievo.
- Fixed: with more than one monitor, each bar's workspace dots now show that monitor's own workspace instead of the focused one, and clicking a dot switches workspaces on that monitor. On workspaces 11 and up, the dots and the wheel follow that group of ten. From #21 by malievo.

### Keyboard

- New: switching the keyboard layout shows it for a moment in the island at the top: the layout's name and its short code, such as RUSSIAN · RU or ARABIC · AR. It shows there even when volume uses the screen edge, and it turns off with the Glyph lights. Requested in #27.
- Fixed: restarting the typing tool (ydotool) made the bar and the lock screen show EN while you were typing in another layout.

### Terminals

- New: Ghostty follows your theme like kitty does: colors, the 16 terminal colors, font, padding and cursor. Open windows recolor when you change the theme. Pick Ghostty under extras in the installer, or add `config-file = ?glyph.conf` to `~/.config/ghostty/config`. Kitty stays the default terminal. Requested in #30.

### Installer

- Fixed: `install.sh --update` moved starship, fastfetch, btop, cava and the fish progress file into a backup folder and linked them again, though they already pointed at the rice through `~/.config/quickshell/glyph`. Uninstall left those same links behind, pointing at nothing.
- `install.sh --dry-run` now shows the step that adds the udev rule for typing tools.

### Screenshots and recording

- Fixed: the shell crashed when you took a screenshot over a full-screen game such as Sober. The game held so much graphics memory that the screenshot overlay couldn't be created, and Quickshell crashed instead of failing. The overlay is now created once at startup, so a shot needs nothing new.
- New: if the shell ever crashes, it comes back by itself and tells you. After more than 3 crashes in a minute it stops and asks you to run `rice restart`.
- Fixed: recordings made with `Ctrl` `Alt` `R` had no sound and ignored the recording settings. Every record key now uses the same settings as quick settings.
- New: the screenshot tool's record mode lets you choose the area (screen or region) and the sound (off, system, mic or both). `F` and `A` switch them. Full screen starts on a click.
- Sound defaults to system on new installs. If yours was off, pick it once in record mode.
- `Super` `Alt` `R` records the whole screen and `Super` `Shift` `Alt` `R` a region. Both stop with the same key.
- The screenshot timer waits the 3 or 13 seconds it shows. From the original repository.

### Special workspaces

- `Super` `Alt` `S` now takes a window out of any special workspace, back to the workspace you're on. On a normal workspace it still sends the window into the special one.
- The overview shows the five special workspaces in a row under the others. Drag windows in and out of them.

### From the original repository

- New: a TRAY tab in the launcher, for apps sitting in the system tray.
- New: every Nothing and CMF earbuds model, with the right noise-control options for each.
- Fixed: Bluetooth devices reconnect when Bluetooth is turned back on, and a device is trusted only after pairing succeeds.
- Fixed: the VPN no longer drops by itself behind a fake captive portal. It asks with a notification instead.
- Fixed: typing the clipboard (`Ctrl` `Shift` `Alt` `V`) works with text starting with `-`, and a negative calculator result copies.
- Security: `ydotool` gets its device through a udev rule instead of the `input` group, which let any app read every keyboard. `--update` adds the rule. If you're still in the `input` group, it says how to leave it.
- Security: a wallpaper is decoded by its extension, so a file pretending to be an image can't reach other decoders. Login screen installs refuse linked files.
- Quick settings: the Wi-Fi and Bluetooth lists have a height limit and scroll, and right-clicking Wi-Fi opens the network list again. The notification list shrinks smoothly when cleared, thanks to [@malievo](https://github.com/malievo).
- System → Sound scrolls past four devices.

### Lock screen

- New: sleep, reboot and power off on the lock screen, in the same list as the Lock greeter. Click them or press `F10` `F11` `F12`. Reboot and power off ask for a second press within 5 seconds, because the locked session can hold unsaved work.
- The lock takes the keyboard back if it ever loses it. This was added after typing failed on one laptop.

### File managers

- New: Dolphin is a choice alongside Thunar and Strata, in the installer's Custom setup, in System → Apps → files, and with `install.sh --file-manager`.
- Choosing Dolphin also adds thumbnails, phone and network support, the terminal setting, and the menu it needs outside Plasma so "Open With" isn't empty.
- If Dolphin is already your file manager, for example coming from Plasma, the installer keeps it.

### Drives

- Fixed: plugged-in drives did nothing. Hyprland has no automounter and the installer never added the tools, so `--update` adds them: `udisks2`, `gvfs`, `udiskie`, and support for NTFS, exFAT, FAT, phones and cameras.
- New: external drives mount by themselves and show a notification. Internal disks are left alone. You can turn this off in System → Drives.
- New: System → Drives and the update terminal say when a kernel update needs a restart. Until then, newly plugged USB drives don't appear at all.
- New: System → Drives lists plugged-in drives and spare disks, and can mount, open and safely remove them.

### Clearer messages

- The lock screen and both greeters now show the real reason when login is refused, such as a locked account and how long is left, instead of always saying the password is wrong.
- The lock screen and Lock greeter say when Caps Lock is on.
- Terminal progress no longer sits over a terminal you're typing in. It hides while that terminal is focused and comes back in other windows.

### Security, from the original repo

- Names from other people, like a Wi-Fi network, a Bluetooth device or a notification title, now always show as plain text. Before, a name containing an image tag made the shell download that image, so a neighbor's network name could reach out to a server. This also covers this fork's own System pages.
- The lyrics lookup is gone. Nothing showed them, but every track was sent to a website.
- `Ctrl` `Shift` `Alt` `V` no longer works on the lock screen, where it typed the last thing copied into the password field.

### Updates together

- System → About now has one **update everything** button: the rice first, then the system.
- `rice update` updates just the rice.
- Updating with `pacman` or `yay` yourself now ends with a notice if the rice has new changes.

### Login screens

- System → About shows your login screen, and **change login screen** opens a menu to pick another.
- New: the **Dial greeter**. Nebelung's camera dial and tachometer, ported from the SDDM theme to greetd, so that look no longer needs SDDM.
- The existing greeter is now called the **Lock greeter**, after the lock screen look it shares.
- Switch at any time with `install.sh --lock-greeter` or `install.sh --dial-greeter`.

### Coming from KDE Plasma

- New: `install.sh --fix-plasma`. Plasma keeps Wi-Fi passwords in KDE Wallet, out of reach under Hyprland, which caused a password prompt at every boot and no internet until reconnecting. It copies the passwords into their network profiles and makes those networks connect before login. Networks found in the wallet are ticked already, so one Enter does them all, and it only asks for a password the wallet can't give.
- It also stops Plasma's `xwaylandvideobridge` starting under Hyprland. Plasma itself isn't touched.
- A password typed into the Glyph network window now saves into the profile. NetworkManager didn't always keep it, so it could ask again at every boot.

### Updating

- New: System → About shows when the rice has new changes, with a button to update.
- New: `install.sh --update` gets the newest version, adds any new packages and keeps your choices and settings. It refreshes the login screen only if that changed.
- New: `install.sh --report` prints what's useful for fixing a problem, without passwords or network names.

### Installer

- All the questions come first. At the summary you can install, change your choices or cancel.
- After one password it runs to the end by itself. `sudo` stays active, and `pacman`, `yay` and the firewall no longer stop to ask. Only a real package conflict still asks.
- It checks for internet first, refreshes the package keyring, and replaces pulseaudio up front.
- Starter wallpapers became a choice.
- A step that fails stops with a plain message, and running it again is safe. A service that can't be enabled warns and carries on.
- Fixed: a repeat run backing up recolored theme files, a README copied into the wallpapers folder, `--uninstall --yes` doing nothing, and `pciutils` missing from the package list.

### System app

- Fixed: the update button opened its terminal hidden behind System, and each press opened another one. The abandoned password prompts could lock the account, so even the right `sudo` password was rejected. System now closes first, a second press goes to the open terminal, and the terminal explains a lock.
- Fixed: the default apps list showed apps of the wrong kind, like a code editor under web browsers. It now checks what kind of app each one is, and a pick only sets the file types that app handles.
- Fixed: About could stay half empty after leaving it while it loaded, and its update list said "aur" instead of package names.
- A hi-res mouse wheel moves the volume icon and the gif tile one step per notch, and the wheel on home's volume ring changes the volume.
- Better keyboard use: Tab starts on the page, the Apps page works with arrow keys, and holding a key no longer repeats an action.
- The keyboard shortcuts card opens straight away.

### Look and feel

- Esc from the rice settings goes back to System.
- Section dots use your accent color everywhere.
- Fixed clipped labels and a duplicate light switch.
- The date and status lines on home are readable over a wallpaper.
- The VPN panel says when Clash Verge isn't installed.
- Super+W and Super+E show a notification if no default app is set.
