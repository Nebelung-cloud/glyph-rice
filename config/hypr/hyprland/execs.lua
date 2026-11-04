local vars = require("variables")
local fn   = require("hyprland.functions")

hl.on("hyprland.start", function()
    -- Shell: whichever one is picked in rice
    hl.exec_cmd(vars.rice .. " start")

    -- in a nested session the system daemons already run outside
    if vars.nested then return end

    -- Keyring and auth
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    -- the password prompt: glyph has its own (system/Auth.qml, above its panels), other shells — polkit-gnome.
    -- glyph starts polkit-gnome itself if its agent can't register
    hl.exec_cmd("sh -c '[ \"$(cat \"${XDG_STATE_HOME:-$HOME/.local/state}/rice/shell\" 2>/dev/null)\" = glyph ] || exec /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1'")

    -- Clipboard history
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    -- Auto delete trash 30 days old
    hl.exec_cmd("trash-empty 30")

    -- Cursors
    hl.exec_cmd("hyprctl setcursor " .. vars.cursorTheme .. " " .. vars.cursorSize)
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme " .. vars.cursorTheme)
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-size " .. vars.cursorSize)

    -- Location provider
    hl.exec_cmd("/usr/lib/geoclue-2.0/demos/agent")

    -- Forward bluetooth media commands to MPRIS
    hl.exec_cmd("mpris-proxy")

    -- the shell starts hypridle (Rules.idle): timings from house rules → ~/.config/demonshot/hypridle.conf

    -- a background kitty with no window: the first Super+Q opens instantly too. A few seconds after login, so it doesn't
    -- compete with the shell starting; skipped in glyph's Lite mode (the shell keeps the flag file)
    hl.exec_cmd("sh -c 'sleep 4; [ -e \"${XDG_STATE_HOME:-$HOME/.local/state}/rice/lite\" ] || exec " .. vars.terminal .. " --start-as=hidden'")
end)

-- Resizer listener
hl.on("window.title", function(win)
    local d = {
        hl.dsp.window.float({ action = "on", window = win }),
        hl.dsp.window.center({ window = win }),
    }
    local pip = fn.move_actions(win) or {}

    fn.resizer(win, "Bitwarden", 20, 54, d, true)
    fn.resizer(win, "Picture[- ]in[- ][Pp]icture", 0, 0, pip, false)
end)

hl.on("window.open", function(win)
    local d = {
        hl.dsp.window.float({ action = "on", window = win }),
        hl.dsp.window.center({ window = win }),
    }
    local pip = fn.move_actions(win) or {}

    fn.resizer(win, "Bitwarden", 20, 54, d, true)
    fn.resizer(win, "Picture[- ]in[- ][Pp]icture", 0, 0, pip, false)
end)
