# Changelog

The newest changes come first. To get them, press **update the rice** in System → About, or run `install.sh --update`.

## November 2026

### Login screens

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
- Better keyboard use: Tab starts on the page, the Apps page works with arrow keys, and holding a key no longer repeats an action.
- The keyboard shortcuts card opens straight away.

### Look and feel

- Esc from the rice settings goes back to System.
- Section dots use your accent color everywhere.
- Fixed clipped labels and a duplicate light switch.
- The date and status lines on home are readable over a wallpaper.
- The VPN panel says when Clash Verge isn't installed.
- Super+W and Super+E show a notification if no default app is set.

### Lock screen

- The lock takes the keyboard back if it ever loses it. This was added after typing failed on one laptop.
