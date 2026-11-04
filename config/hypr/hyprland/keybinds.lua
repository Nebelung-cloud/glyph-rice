local vars = require("variables")
local fn   = require("hyprland.functions")

-- shell globals — shell:<name>: registered by whichever shell is alive (demonshot, glyph); what it doesn't have stays silent
-- Launcher: tapping Super opens it on release. Without interrupts Super+1 would open the launcher too,
-- so every Super+<key> sends launcherInterrupt without consuming (bindin catchall is broken since 0.55)
hl.bind("SUPER + SUPER_L", hl.dsp.global("shell:launcher"), { release = true })
-- after Super+<key> the release bind above doesn't fire and the interrupt sticks — reset it on Super press
hl.bind("SUPER_L", hl.dsp.global("shell:launcherArm"), { ignore_mods = true, non_consuming = true })
for _, key in ipairs({
    -- secondary modifiers: cover every Super+Mod+key combo
    "Control_L", "Control_R", "Shift_L", "Shift_R", "Alt_L", "Alt_R",
    -- workspaces
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
    -- Super+<key> binds below
    "Q", "W", "E", "R", "T", "A", "D", "F", "G", "K", "L", "C", "V", "M", "N", "P",
    "Z", "X", "U", "S", "H", "I", "space", "Escape",
    "Comma", "Period", "Minus", "Equal", "Backslash",
    "left", "right", "up", "down",
    "Page_Up", "Page_Down", "F12", "Tab",
    "mouse:272", "mouse:273", "mouse:274", "mouse:275", "mouse:276", "mouse:277",
    "mouse_up", "mouse_down",
}) do
    hl.bind("SUPER + " .. key, hl.dsp.global("shell:launcherInterrupt"), { non_consuming = true })
end

-- Misc
hl.bind(vars.kbAltar, hl.dsp.global("shell:altar"))
hl.bind("SUPER + I", hl.dsp.global("shell:settings"))
hl.bind("SUPER + Tab", hl.dsp.global("shell:overview")) -- workspace overview
hl.bind("SUPER + N", hl.dsp.global("shell:ward"))
hl.bind("SUPER + P", hl.dsp.global("shell:pact"))
hl.bind("SUPER + A", hl.dsp.global("shell:quick")) -- glyph quick settings
hl.bind("SUPER + SHIFT + W", hl.dsp.global("shell:wall")) -- glyph wallpapers
hl.bind(vars.kbSession, hl.dsp.global("shell:power"))
hl.bind(vars.kbPower, hl.dsp.global("shell:power"))
hl.bind(vars.kbLock, hl.dsp.exec_cmd(vars.lockCmd))
hl.bind(vars.kbRestoreLock, hl.dsp.exec_cmd(vars.lockCmd), { locked = true }) -- the lock crashed — bring it back (the session is still locked → needs locked)

-- Brightness: set by the shell (services/Backlight) — the OSD moves at once, brightnessctl catches up
hl.bind("XF86MonBrightnessUp", hl.dsp.global("shell:briUp"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.global("shell:briDown"), { locked = true, repeating = true })

-- Media
hl.bind("CTRL + SUPER + Space", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("CTRL + SUPER + Equal", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("CTRL + SUPER + Minus", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("XF86AudioStop", hl.dsp.exec_cmd("playerctl stop"), { locked = true })

-- Kill/restart
hl.bind("CTRL + SUPER + SHIFT + R", hl.dsp.exec_cmd(vars.rice .. " kill"), { release = true })
hl.bind("CTRL + SUPER + ALT + R", hl.dsp.exec_cmd(vars.rice .. " restart"), { release = true })

for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(vars.kbGoToWs .. " + " .. key, fn.wsaction("focus", "", i))
    hl.bind(vars.kbMoveWinToWs .. " + " .. key, fn.wsaction("move", "", i))
    hl.bind(vars.kbGoToWsGroup .. " + " .. key, fn.wsaction("focus", "group", i))
    hl.bind(vars.kbMoveWinToWsGroup .. " + " .. key, fn.wsaction("move", "group", i))
end

-- Go to workspace -1/+1 (within the workspace count, wrapping — System → workspaces)
hl.bind("SUPER + mouse_down", fn.wsstep(-1))
hl.bind("SUPER + mouse_up", fn.wsstep(1))
hl.bind(vars.kbPrevWs, fn.wsstep(-1), { repeating = true })
hl.bind(vars.kbNextWs, fn.wsstep(1), { repeating = true })
hl.bind("SUPER + Page_Up", fn.wsstep(-1), { repeating = true })
hl.bind("SUPER + Page_down", fn.wsstep(1), { repeating = true })

-- Go to workspace group -1/+1
hl.bind("CTRL + SUPER + mouse_down", hl.dsp.focus({ workspace = "-10" }))
hl.bind("CTRL + SUPER + mouse_up", hl.dsp.focus({ workspace = "+10" }))

-- Move window to workspace -1/+1
hl.bind("SUPER + ALT + Page_Up", fn.wsstep(-1, true), { repeating = true })
hl.bind("SUPER + ALT + Page_Down", fn.wsstep(1, true), { repeating = true })
hl.bind("SUPER + ALT + mouse_down", fn.wsstep(-1, true))
hl.bind("SUPER + ALT + mouse_up", fn.wsstep(1, true))
hl.bind("CTRL + SUPER + SHIFT + right", fn.wsstep(1, true), { repeating = true })
hl.bind("CTRL + SUPER + SHIFT + left", fn.wsstep(-1, true), { repeating = true })

-- Move window to/from special workspace
hl.bind("CTRL + SUPER + SHIFT + up", hl.dsp.window.move({ workspace = "special:special" }))
hl.bind("CTRL + SUPER + SHIFT + down", hl.dsp.window.move({ workspace = "e+0" }))
hl.bind("SUPER + ALT + S", hl.dsp.window.move({ workspace = "special:special" }))

-- Window groups
hl.bind(vars.kbWindowGroupCycleNext, hl.dsp.window.cycle_next(), { repeating = true })
hl.bind(vars.kbWindowGroupCyclePrev, hl.dsp.window.cycle_next({ next = false }), { repeating = true })
hl.bind("CTRL + ALT + Tab", hl.dsp.group.next(), { repeating = true })
hl.bind("CTRL + SHIFT + ALT + Tab", hl.dsp.group.prev(), { repeating = true })
hl.bind(vars.kbToggleGroup, hl.dsp.group.toggle())
hl.bind(vars.kbUngroup, hl.dsp.window.move({ out_of_group = true }))
-- group.lock() only took over lock_active()'s meaning in 0.57; on 0.56 lock() is the all-groups lock
local kbLockGroup = hl.version():match("^0%.5[0-6]%.") and hl.dsp.group.lock_active() or hl.dsp.group.lock()
hl.bind("SUPER + SHIFT + Comma", kbLockGroup)

-- Window actions
hl.bind("SUPER + left", hl.dsp.focus({ direction = "left" }))
hl.bind("SUPER + right", hl.dsp.focus({ direction = "right" }))
hl.bind("SUPER + up", hl.dsp.focus({ direction = "up" }))
hl.bind("SUPER + down", hl.dsp.focus({ direction = "down" }))
hl.bind("SUPER + SHIFT + left", hl.dsp.window.move({ direction = "left" }))
hl.bind("SUPER + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind("SUPER + SHIFT + up", hl.dsp.window.move({ direction = "up" }))
hl.bind("SUPER + SHIFT + down", hl.dsp.window.move({ direction = "down" }))
hl.bind("SUPER + Minus", hl.dsp.window.resize(fn.resize_active_window(-10, 0)), { repeating = true })
hl.bind("SUPER + Equal", hl.dsp.window.resize(fn.resize_active_window(10, 0)), { repeating = true })
hl.bind("SUPER + SHIFT + Minus", hl.dsp.window.resize(fn.resize_active_window(0, -10)), { repeating = true })
hl.bind("SUPER + SHIFT + Equal", hl.dsp.window.resize(fn.resize_active_window(0, 10)), { repeating = true })
hl.bind("SUPER + ALT + left", hl.dsp.window.resize(fn.resize_active_window(-10, 0)), { repeating = true })
hl.bind("SUPER + ALT + right", hl.dsp.window.resize(fn.resize_active_window(10, 0)), { repeating = true })
hl.bind("SUPER + ALT + up", hl.dsp.window.resize(fn.resize_active_window(0, -10)), { repeating = true })
hl.bind("SUPER + ALT + down", hl.dsp.window.resize(fn.resize_active_window(0, 10)), { repeating = true })

-- mouse: Super + drag — move the window (tiled and floating alike), hold Super+X and move — resize
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(vars.kbResizeWindow, hl.dsp.window.resize(), { mouse = true })
hl.bind("CTRL + SUPER + Backslash", hl.dsp.window.center())
hl.bind("CTRL + SUPER + ALT + Backslash", hl.dsp.window.resize(fn.resize_by_screen(55, 70)))
hl.bind("CTRL + SUPER + ALT + Backslash", hl.dsp.window.center())
hl.bind(vars.kbWindowPip, function()
    local a = hl.get_active_window()
    if a then
        local pip = fn.move_actions(a) or {}
        if not a.floating then table.insert(pip, 1, hl.dsp.window.float()) end
        table.insert(pip, hl.dsp.window.pin({ action = "on", window = "address:" .. a.address }))

        for _, x in ipairs(pip) do
            hl.dispatch(x)
        end
    end
end)
hl.bind(vars.kbPinWindow, hl.dsp.window.pin())
hl.bind(vars.kbWindowFullscreen, hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(vars.kbWindowBorderedFullscreen, hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(vars.kbToggleWindowFloating, hl.dsp.window.float())
hl.bind(vars.kbCloseWindow, hl.dsp.window.close())

-- Special workspace toggles
hl.bind(vars.kbSpecialWs, fn.toggle_special("special"))
hl.bind(vars.kbSystemMonitorWs, fn.toggle_special("sysmon"))
hl.bind(vars.kbMusicWs, fn.toggle_special("music"))
hl.bind(vars.kbCommunicationWs, fn.toggle_special("communication"))
hl.bind(vars.kbTodoWs, fn.toggle_special("todo"))

-- Apps
hl.bind(vars.kbTerminal, hl.dsp.exec_cmd(vars.terminal))
hl.bind(vars.kbBrowser, hl.dsp.exec_cmd(vars.browser))
hl.bind(vars.kbEditor, function() if vars.apps.editor then hl.exec_cmd(vars.apps.editor) end end)
hl.bind(vars.kbFileExplorer, hl.dsp.exec_cmd(vars.fileExplorer))
hl.bind("CTRL + ALT + V", hl.dsp.exec_cmd(vars.audioSettings))

-- Utilities
hl.bind("Print", hl.dsp.global("shell:shot"))
hl.bind("SUPER + SHIFT + S", hl.dsp.global("shell:shot"))
hl.bind("SUPER + ALT + R", fn.record(false, true))
hl.bind("CTRL + ALT + R", fn.record(false, false))
hl.bind("SUPER + SHIFT + ALT + R", fn.record(true, false))
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd("hyprpicker -a"))
hl.bind("SUPER + SHIFT + U", hl.dsp.exec_cmd("hyprctl kill"))
-- Volume
-- lid: what to do is decided by the shell (System → idle → lid closed); on «sleep» logind suspends by itself
hl.bind("switch:on:Lid Switch", hl.dsp.global("shell:lidClose"), { locked = true })
hl.bind("switch:off:Lid Switch", hl.dsp.global("shell:lidOpen"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("SUPER + SHIFT + M", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind(
    "XF86AudioRaiseVolume",
    hl.dsp.exec_cmd(
        "wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume -l " ..
        (vars.volumeMax / 100) .. " @DEFAULT_AUDIO_SINK@ " .. vars.volumeStep .. "%+"
    ),
    { locked = true, repeating = true }
)
hl.bind(
    "XF86AudioLowerVolume",
    hl.dsp.exec_cmd(
        "wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume @DEFAULT_AUDIO_SINK@ " .. vars.volumeStep .. "%-"
    ),
    { locked = true, repeating = true }
)

-- Sleep
hl.bind("SUPER + SHIFT + L", hl.dsp.exec_cmd(vars.sleepGestureCmd), { locked = true })

-- Clipboard
hl.bind("SUPER + V", hl.dsp.global("shell:clip"))
hl.bind("SUPER + Period", hl.dsp.global("shell:charms"))
hl.bind(
    "CTRL + SHIFT + ALT + V",
    hl.dsp.exec_cmd('sleep 0.5s && ydotool type -d 1 "$(cliphist list | head -1 | cliphist decode)"')
    -- not locked: on the lock screen it would type the last thing copied into the password field, for anyone at the laptop
)

-- Testing
hl.bind(
    "SUPER + ALT + F12",
    hl.dsp.exec_cmd(
        "notify-send -u low -i dialog-information-symbolic 'Test notification' " ..
        [["Here's a really long message to test truncation and wrapping\nYou can middle click or flick this notification to dismiss it!"]] ..
        " -a 'Shell' -A 'Test1=I got it!' -A 'Test2=Another action'"
    )
)
