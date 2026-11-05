pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// house rules: ~/.config/demonshot/rules.json — the single source of truth for the settings.
// An edit from Settings writes the file (writeAdapter) and calls the right apply itself. applyAll is called only by shell.qml at startup:
// the lock (lock.qml) reads Theme → Rules too, but applies nothing
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/.config/demonshot"
    readonly property alias store: adapter

    // eight colors in Theme's order: void crypt wine plum rose crimson ash bone
    readonly property var palettes: [
        { name: "Demon's Shot", what: "blood & bone", c: ["#0D0B0E", "#151116", "#2B1820", "#4A2236", "#B8487A", "#C7303D", "#7A6870", "#E9DFDD"] },
        { name: "Absinthe", what: "green fairy", c: ["#0B0D0B", "#121612", "#1E2A1F", "#2F4630", "#A9B85A", "#7CC24A", "#6E7A6C", "#E3E6D8"] },
        { name: "Nightshade", what: "poison bloom", c: ["#0C0B10", "#131119", "#221A30", "#3A2852", "#8E6BD8", "#B04BD6", "#706A80", "#E4DFEA"] },
        { name: "Holy Water", what: "cold blessing", c: ["#0A0C10", "#11151B", "#1A2433", "#263C57", "#5E9BD1", "#3F7FE0", "#687687", "#DDE4EA"] },
        { name: "Rust", what: "old iron", c: ["#0E0B09", "#17120F", "#2E1D14", "#4D2E1C", "#D08A3E", "#D1532A", "#7E6E62", "#EADFD3"] },
        { name: "Gilded", what: "altar gold", c: ["#0D0C0A", "#16140F", "#2E2716", "#4A3D1E", "#B88A4A", "#D9A43A", "#7A7262", "#EDE5D3"] },
        { name: "Ghost", what: "no color left", c: ["#0C0C0D", "#141416", "#26262A", "#3A3A40", "#9A9AA6", "#E9E9EE", "#6E6E76", "#E2E2E6"] }
    ]
    readonly property var pal: palettes[adapter.palette] ?? palettes[0]

    // wait for the file when the singleton is created: otherwise the first one to read store (glyph at startup) gets the defaults, not rules.json
    Component.onCompleted: file.waitForJob()

    FileView {
        id: file
        path: root.dir + "/rules.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: this.reload()
        // write — once at the end of the turn: writeAdapter() on every field in a row mixes up neighbours (a preset changes four at once)
        onAdapterUpdated: Qt.callLater(file.writeAdapter)
        onLoadFailed: err => { if (err === FileViewError.FileNotFound) this.writeAdapter(); } // first launch: a file with the defaults

        // defaults — as in the hypr config now, so the first launch doesn't shift anything
        JsonAdapter {
            id: adapter
            // Display
            property real monScale: 0      // 0 — auto, hypr decides
            property int refresh: 120
            property int vrr: 0           // misc.vrr: 0 off, 1 always, 2 fullscreen only
            property var screens: ({})    // other screens by output name: "left" · "right" · "up" · "down" · "mirror" · "off"
            property string newSide: "right" // where a screen without a choice goes: left · right · up · down
            property int brightness: 62
            property bool night: false
            property int warmth: 4300
            property int gapsIn: 6
            property int gapsOut: 14
            property int border: 2
            property int rounding: 0
            property bool blur: true
            property bool shadow: true
            property bool motion: true
            property bool ultra: false   // ultra mode (setMode 0): 60 Hz and no decorations over the settings
            property bool game: false    // game mode, like in caelestia: no animations, blur, shadows, gaps or rounding, tearing (Theme.apply)
            // what game mode leaves on (prefs → WINDOWS → in a game); tearing is always on in it
            property bool gameGaps: false   // gaps, border and rounding as set
            property bool gameMotion: false // animations
            property bool gameBlur: false
            property bool gameShadow: false
            property bool gameDnd: true     // auto game mode (services/Game) turns on do not disturb
            // Colors
            property int palette: 0
            property bool paintHypr: true
            property bool paintKitty: true
            // Input — as in hyprland/input.lua
            property int kbSwitch: 0      // an index into switches
            property int repeatDelay: 250
            property int repeatRate: 35
            property bool natural: true
            property bool tap: true
            property bool typingOff: false
            property int scroll: 30       // % — scroll_factor 0.3
            property int sens: 0          // -100…100 → sensitivity -1…1
            property bool flat: false
            // Idle: minutes, 0 — never
            property int lockAfter: 3
            property int dpmsAfter: 5
            property int sleepAfter: 10
            property bool hibernate: true // suspend-then-hibernate
            property string lid: "sleep"  // lid closed: sleep (logind decides) · lock · screen off · nothing
            // System
            property bool roman: true
            // Notices. Quiet (the wards set it too): ordinary notifications aren't shown, critical ones — always
            property bool dnd: false
            property int noteTime: 6      // s, if the app didn't set its own; 0 — they wait until swiped away
            property int noteDeck: 5      // how many are visible in the deck
        }
    }

    // kitty: an include file with the palette colors (kitty.conf includes it), SIGUSR1 — reload the config
    FileView { id: kitty; path: root.dir + "/kitty.conf"; printErrors: false }

    function hypr(lua) { Quickshell.execDetached(["hyprctl", "eval", lua]); }

    // the monitor isn't hard-coded, like in caelestia: from hyprctl monitors — the built-in (eDP), and without it — the first; the native mode — the
    // largest of its modes, rates — those of the native one. ponytail: settings for one screen, the rest — a line each in hyprland.lua
    property var mon: ({ name: "", w: 0, h: 0, scale: 1, rates: [] })
    property var screens: [] // every screen hypr knows: { name, desc, w, h, off }
    function reread() { monProc.running = true; }
    function setScreen(name, x) {
        store.screens = Object.assign({}, store.screens, { [name]: x });
        monitor();
        monReread.restart();
    }
    function setNewSide(x) {
        store.newSide = x;
        monitor();
    }
    property bool monWanted: false // monitor() was called before the hyprctl answer arrived
    Process {
        id: monProc
        running: true
        command: ["hyprctl", "monitors", "all", "-j"] // all: a screen turned off here still shows up to be turned back on
        stdout: StdioCollector {
            onStreamFinished: {
                const all = JSON.parse(text), m = all.find(x => x.name.startsWith("eDP")) ?? all[0];
                if (!m) return;
                root.screens = all.map(x => ({ name: x.name, desc: x.description ?? "", w: x.width, h: x.height, off: !!x.disabled }));
                const modes = m.availableModes.map(s => /(\d+)x(\d+)@([\d.]+)/.exec(s)).filter(Boolean).map(r => [+r[1], +r[2], Math.round(+r[3])]);
                const [w, h] = modes.reduce((a, b) => b[0] * b[1] > a[0] * a[1] ? b : a, [m.width, m.height]);
                const rates = [...new Set(modes.filter(r => r[0] === w && r[1] === h).map(r => r[2]))].sort((a, b) => a - b);
                root.mon = { name: m.name, w, h, scale: m.scale, rates: rates.length ? rates : [Math.round(m.refreshRate)] };
                if (root.monWanted) root.monitor();
            }
        }
    }
    // auto — hypr picks the scale; which one it chose, we learn by re-reading the monitors
    Timer { id: monReread; interval: 500; onTriggered: monProc.running = true }
    function monitor() {
        if (!mon.name) { monWanted = true; return; }
        monWanted = false;
        hypr(`hl.monitor({ output = "${mon.name}", mode = "${mon.w}x${mon.h}@${hz}", position = "auto", scale = ${store.monScale || '"auto"'} })`);
        hypr(`hl.config({ misc = { vrr = ${store.vrr} } })`);
        // other screens: each a saved side (left · right · up · down), mirror of this one, or off; any screen without a choice —
        // newSide, on the config's catch-all rule. The mouse crosses over at the edge they share. Hypr applies a saved rule
        // itself when that screen is plugged in
        const side = x => ["left", "right", "up", "down"].includes(x) ? x : "right";
        const rule = (o, x) => x === "off" ? `hl.monitor({ output = "${o}", disabled = true })`
            : x === "mirror" ? `hl.monitor({ output = "${o}", mode = "highres", position = "auto", scale = "auto", mirror = "${mon.name}" })`
            : `hl.monitor({ output = "${o}", mode = "highres", position = "auto-${side(x)}", scale = "auto" })`;
        const own = Object.keys(store.screens).filter(o => o !== mon.name && /^[\w-]+$/.test(o));
        hypr([rule("", side(store.newSide))].concat(own.map(o => rule(o, store.screens[o]))).join("; "));
        monReread.restart();
    }
    readonly property var rates: mon.rates.length ? mon.rates : [60, 120]
    readonly property int refreshHz: rates.reduce((a, b) => Math.abs(b - store.refresh) < Math.abs(a - store.refresh) ? b : a)
    readonly property real scale: store.monScale || mon.scale || 1 // what's actually set, at auto too
    readonly property var scales: ["auto", "1", "1.25", "1.5", "2"]
    readonly property int scaleIdx: store.monScale ? scales.indexOf(String(store.monScale)) : 0
    function setScale(i) { store.monScale = i ? +scales[i] : 0; monitor(); }
    function windows() {
        const s = store;
        hypr(`hl.config({ general = { gaps_in = ${s.gapsIn}, gaps_out = ${s.gapsOut}, border_size = ${s.border} }, `
           + `decoration = { rounding = ${s.rounding}, blur = { enabled = ${blurOn} }, shadow = { enabled = ${shadowOn} } } })`);
    }
    // ponytail: only on/off; slam/snap — override the curves from animations.lua
    function motion() { hypr(`hl.config({ animations = { enabled = ${moving} } })`); }
    readonly property var switches: [["alt+shift", "grp:alt_shift_toggle"], ["caps", "grp:caps_toggle"], ["ctrl+shift", "grp:ctrl_shift_toggle"]]
    function input() {
        const s = store;
        hypr(`hl.config({ input = { kb_options = "${switches[s.kbSwitch]?.[1] ?? switches[0][1]}", repeat_delay = ${s.repeatDelay}, repeat_rate = ${s.repeatRate}, `
           + `sensitivity = ${s.sens / 100}, accel_profile = "${s.flat ? "flat" : "adaptive"}", touchpad = { natural_scroll = ${s.natural}, `
           + `tap_to_click = ${s.tap}, disable_while_typing = ${s.typingOff}, scroll_factor = ${s.scroll / 100} } } })`);
    }
    // hibernation isn't everywhere (needs swap for resume, zram won't do) — we ask logind. None — plain sleep, the hibernation
    // items hide. The answer came after idle() — rewrite the config (the lock doesn't call idle(), it doesn't concern it)
    property bool canHibernate: false
    property bool idleDone: false
    readonly property bool hibernateOn: store.hibernate && canHibernate
    onCanHibernateChanged: if (idleDone) idle()
    Process {
        running: true
        command: ["busctl", "call", "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "CanSuspendThenHibernate"]
        stdout: StdioCollector { onStreamFinished: root.canHibernate = text.includes('"yes"') }
    }
    // hypridle doesn't reload its config on the fly: we write ours and restart it. Same text and hypridle alive — leave it,
    // so a shell reload doesn't reset the idle counter. inhibit_sleep = 3 — sleep waits until the lock is up (hypridle itself
    // only waits like that for hyprlock): otherwise the lock falls asleep half-started, and on wake the monitors blink — a monitor that
    // drops in the first ~0.5 s of the lock's life kills qs (#5)
    function idle() {
        idleDone = true;
        const s = store, dpms = a => `hyprctl dispatch 'hl.dsp.dpms({action = "${a}"})'`;
        const at = (min, on, back) => min ? `\nlistener {\n    timeout = ${min * 60}\n    on-timeout = ${on}${back ? `\n    on-resume = ${back}` : ""}\n}\n` : "";
        const conf = "# demonshot: written by Rules.idle() from rules.json, don't edit by hand\n"
            + "general {\n    lock_cmd = ~/.config/quickshell/rice/rice lock\n    inhibit_sleep = 3\n"
            + `    before_sleep_cmd = loginctl lock-session\n    after_sleep_cmd = ${dpms("on")}\n}\n`
            + at(s.lockAfter, "loginctl lock-session") + at(s.dpmsAfter, dpms("off"), dpms("on"))
            + at(s.sleepAfter, hibernateOn ? "systemctl suspend-then-hibernate" : "systemctl suspend");
        Quickshell.execDetached(["sh", "-c", 'f="$1/hypridle.conf"; printf %s "$2" | cmp -s - "$f" && pgrep -x hypridle >/dev/null && exit; '
                                       + 'printf %s "$2" > "$f"; pkill -x hypridle; exec hypridle -c "$f"', "sh", dir, conf]);
    }
    function brightness() { Quickshell.execDetached(["brightnessctl", "-q", "set", store.brightness + "%"]); }
    function night() {
        Quickshell.execDetached(["sh", "-c", store.night ? `pkill -x hyprsunset; exec hyprsunset -t ${store.warmth}` : "pkill -x hyprsunset"]);
    }

    // palette: Theme recolors itself (bindings on pal), here — what lives outside the shell
    function paint() {
        const c = pal.c;
        if (store.paintHypr) {
            const h = c.map(x => x.slice(1));
            hypr(`hl.config({ general = { col = { active_border = { colors = { "rgb(${h[5]})", "rgb(${h[4]})", "rgb(${h[5]})" }, angle = 135 }, `
               + `inactive_border = "rgb(${h[2]})" } }, decoration = { shadow = { color = "rgba(${h[5]}20)" } } })`);
        }
        if (store.paintKitty) {
            kitty.setText([
                ["foreground", c[7]], ["background", c[1]], ["cursor", c[7]], ["cursor_text_color", c[1]],
                ["selection_foreground", c[7]], ["selection_background", c[3]], ["url_color", c[4]],
                ["active_border_color", c[5]], ["inactive_border_color", c[2]],
                ["active_tab_foreground", c[7]], ["active_tab_background", c[5]],
                ["inactive_tab_foreground", c[6]], ["inactive_tab_background", c[1]], ["tab_bar_background", c[0]]
            ].map(([k, v]) => `${k} ${v}`).join("\n") + "\n");
            Quickshell.execDetached(["pkill", "-USR1", "-x", "kitty"]);
        }
    }

    // power modes, like in caelestia: the power-profiles-daemon profile. ultra on top — 60 Hz, no animations, blur or shadows,
    // over your settings, without touching them: left — they're back. 0 ultra · 1 saver · 2 balanced · 3 performance.
    // Windows (blur, shadows) are applied by the caller: demonshot — windows(), glyph — Theme.apply() (windows() would drop its rounding)
    readonly property var modes: [
        { name: "ultra", short: "ULT", what: `power saver · ${rates[0]} hz · still` },
        { name: "saver", short: "ECO", what: "power saver" },
        { name: "balanced", short: "BAL", what: "balanced" },
        { name: "performance", short: "MAX", what: "performance" }
    ]
    readonly property int mode: store.ultra ? 0 : PowerProfiles.profile + 1
    readonly property int modeCount: PowerProfiles.hasPerformanceProfile ? 4 : 3
    function setMode(i) {
        i = Math.max(0, Math.min(modeCount - 1, i));
        const hz0 = hz, moving0 = moving;
        store.ultra = i === 0;
        PowerProfiles.profile = i === 0 ? PowerProfile.PowerSaver : i - 1;
        // the monitor — only if the hertz really differ: reconfiguring the output flashes the screen and resets hover (panels fade)
        if (hz !== hz0) monitor();
        if (moving !== moving0) motion();
    }
    // what's actually set: ultra overrides the settings — the screen's lowest hertz, otherwise the closest to the chosen ones
    readonly property int hz: store.ultra ? rates[0] : refreshHz
    readonly property bool moving: store.motion && !store.ultra && (!store.game || store.gameMotion)
    readonly property bool blurOn: store.blur && !store.ultra && (!store.game || store.gameBlur)
    readonly property bool shadowOn: store.shadow && !store.ultra && (!store.game || store.gameShadow)

    // shell startup: everything except brightness (the keys and the OSD drive it, overwriting it on every launch isn't allowed)
    function applyAll() {
        monitor(); windows(); motion(); night(); paint(); input(); idle();
    }
}
