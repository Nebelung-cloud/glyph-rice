local vars = require("variables")

-- workspace limit within a group of ten and wrap-around: set by the shell (Theme.workspaces → glyph_ws_limit, glyph_ws_wrap), without the shell — 10 and wrapping
local function ws_limit() return glyph_ws_limit or 10 end

local function wsaction(action, range, i)
    return function()
        local activews = hl.get_active_workspace()
        if activews then
            local id = activews.id
            -- Super+N past the limit — ignored (groups, Ctrl+Super+N, have no limit)
            if range ~= "group" and i > ws_limit() then return end
            local s  = (i - 1) * 10 + (id % 10)
            local t  = math.floor((id - 1) / 10) * 10 + i
            local z  = (range == "group") and s or t

            if action == "move" then
                return hl.dispatch(hl.dsp.window.move({ workspace = z }))
            else
                return hl.dispatch(hl.dsp.focus({ workspace = z }))
            end
        end
    end
end

-- neighbouring workspace ±1 within the group of ten: past the last — the first (and back), if glyph_ws_wrap; otherwise stay.
-- move — move the window there, otherwise go there
local function wsstep(d, move)
    return function()
        local a = hl.get_active_workspace()
        if not a or a.id < 1 then return end
        local base, n = math.floor((a.id - 1) / 10) * 10, ws_limit()
        local slot = a.id - base
        local t = slot + d
        if slot > n then t = (d > 0) and 1 or n -- we're past the limit (it was lowered) — back inside it
        elseif t > n then t = (glyph_ws_wrap == false) and n or 1
        elseif t < 1 then t = (glyph_ws_wrap == false) and 1 or n end
        if base + t == a.id then return end
        if move then
            return hl.dispatch(hl.dsp.window.move({ workspace = base + t }))
        end
        return hl.dispatch(hl.dsp.focus({ workspace = base + t }))
    end
end

local function resize_by_screen(x, y)
    local screen = hl.get_active_monitor()
    if screen and type(screen.width) == "number" and type(screen.height) == "number" then
        if not (x == 0 and y == 0) then
            local w = (x and x > 0) and math.floor(screen.width * x / 100) or screen.width
            local h = (y and y > 0) and math.floor(screen.height * y / 100) or screen.height
            return { x = w, y = h, relative = false }
        end
    end
end

local function resize_active_window(x, y)
    local win = hl.get_active_window()
    if win and win.size then
        local w = (win.size.x * (x / 100)) or 800
        local h = (win.size.y * (y / 100)) or 600

        return { x = w, y = h, relative = true }
    end
end

local function resizer(window, pattern, x_percent, y_percent, actions, exact)
    if (window and window.title) and string.find(window.title, pattern, 1, exact) then
        local disp = (type(actions) == "table") and actions or { actions }
        for _, x in ipairs(disp) do
            hl.dispatch(x)
        end

        hl.dispatch(hl.dsp.window.resize(resize_by_screen(x_percent, y_percent)))
        hl.dispatch(hl.dsp.window.set_prop({ prop = "keep_aspect_ratio", value = "true" }))
    end
end

local function move_actions(win)
    local screen = hl.get_active_monitor()

    if screen and screen.width and screen.height and win and win.size then
        local monitor_height = screen.height / screen.scale
        local monitor_width  = screen.width / screen.scale

        local scale_factor   = (monitor_height / 4) / win.size.y

        local target_width   = win.size.x * scale_factor
        local target_height  = win.size.y * scale_factor

        local x_resize       = math.floor(math.max(200, target_width))
        local y_resize       = math.floor(math.max(150, target_height))

        local offset         = math.min(monitor_width, monitor_height) * 0.03

        local move_x         = math.floor(screen.x + monitor_width - x_resize - offset)
        local move_y         = math.floor(screen.y + monitor_height - y_resize - offset)

        return {
            hl.dsp.window.resize({ x = x_resize, y = y_resize, window = win }),
            hl.dsp.window.move({ x = move_x, y = move_y, relative = false, window = win }),
        }
    end
end

-- special ws: open/close, and if it's empty — launch its program from vars.apps (replaces caelestia toggle).
-- apps are read on keypress, not at load: user.lua loads after the binds and changes them there
local function toggle_special(name)
    return function()
        local cmd = vars.apps[name]
        for _, ws in ipairs(hl.get_workspaces()) do
            if ws.name == "special:" .. name and ws.windows > 0 then cmd = nil end
        end
        -- show first, then launch: hypr opens the window where focus was at launch time,
        -- and in the reverse order it would hide the workspace as soon as the window appeared
        hl.dispatch(hl.dsp.workspace.toggle_special(name))
        if cmd then hl.exec_cmd(cmd) end
    end
end

-- gpu-screen-recorder screen recording: the same bind again — stop
local function record(region, sound)
    return function()
        local mon = hl.get_active_monitor()
        local w   = region and '-w region -region "$(slurp -f %wx%h+%x+%y)"' or "-w " .. (mon and mon.name or "region")
        hl.exec_cmd("pkill -INT -f '^gpu-screen-recorder' || gpu-screen-recorder " .. w ..
            (sound and " -a default_output" or "") .. ' -o "$(xdg-user-dir VIDEOS)/rec-$(date +%F_%H-%M-%S).mp4"')
    end
end

return {
    toggle_special       = toggle_special,
    record               = record,
    resizer              = resizer,
    resize_by_screen     = resize_by_screen,
    resize_active_window = resize_active_window,
    wsaction             = wsaction,
    wsstep               = wsstep,
    move_actions         = move_actions,
}
