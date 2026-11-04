pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.settings
import "tint.js" as Tint

// glyph: black, white dots, one red. Palette, fonts, motion, state (theme, quiet) and the hypr/kitty look — here
Singleton {
    id: root

    // the state survives a restart, the lock (a separate process) reads it too
    readonly property alias state: st
    readonly property bool light: st.light

    // light theme — the same layout, the greys reversed; red doesn't change.
    // bg background, wallpaper · s1 bar, panels · s2 tiles, off · s3 lines, dimmed dots · mute inactive · grey labels, secondary ·
    // fg text, on, focus · ink text on a white tile · red — at most one thing on screen, and only «live»
    readonly property var darkMono: ({ bg: "#000000", s1: "#0E0E0E", s2: "#1A1A1A", s3: "#2A2A2A", mute: "#4A4A4A", grey: "#8C8C8C", fg: "#F2F2F2", ink: "#000000", red: "#D71921" })
    readonly property var lightMono: ({ bg: "#E9E9E9", s1: "#FFFFFF", s2: "#F1F1F1", s3: "#D9D9D9", mute: "#B8B8B8", grey: "#6E6E6E", fg: "#0B0B0B", ink: "#FFFFFF", red: "#D71921" })

    // color from the wallpaper (state.match, the COLOR section in prefs): seeds — the image's color buckets, tint.js computes the palette.
    // A grey wallpaper or turned off — mono. paletteFor(light) — for the dark gtk/qt files, they don't follow the light theme
    ColorQuantizer {
        id: quant
        source: st.match && st.wall ? "file://" + wallSrc(st.wall).split("/").map(encodeURIComponent).join("/") : ""
        depth: 4 // 16 buckets
        rescaleSize: 128
    }
    readonly property var styles: Tint.names
    readonly property var seeds: st.match ? Tint.seeds(quant.colors) : []
    readonly property bool matched: seeds.length > 0
    function paletteFor(l) {
        const m = l ? lightMono : darkMono;
        const q = matched ? Tint.paint(m, l, seeds, st.matchSeed, st.matchStyle, st.matchSat) : m;
        return !l && st.extraDark ? Tint.extraDark(q) : q;
    }
    // p — where we're heading (hex strings; apply writes hypr/kitty from it), the colors below glide to p: wallpaper, theme, look — no jump
    readonly property var p: paletteFor(light)
    property color bg: p.bg
    property color s1: p.s1
    property color s2: p.s2
    property color s3: p.s3
    property color mute: p.mute
    property color grey: p.grey
    property color fg: p.fg
    property color ink: p.ink
    property color red: p.red
    Behavior on bg { ColorAnimation { duration: 600 } }
    Behavior on s1 { ColorAnimation { duration: 600 } }
    Behavior on s2 { ColorAnimation { duration: 600 } }
    Behavior on s3 { ColorAnimation { duration: 600 } }
    Behavior on mute { ColorAnimation { duration: 600 } }
    Behavior on grey { ColorAnimation { duration: 600 } }
    Behavior on fg { ColorAnimation { duration: 600 } }
    Behavior on ink { ColorAnimation { duration: 600 } }
    Behavior on red { ColorAnimation { duration: 600 } }
    // not via fade(): at startup bindings are evaluated before the singleton's functions are available
    readonly property color glow: Qt.rgba(fg.r, fg.g, fg.b, light ? 0.3 : 0.6)
    readonly property color scrim: Qt.rgba(bg.r, bg.g, bg.b, light ? 0.8 : 0.74)
    // dimming under popups (calendar, quick settings): the dark end of the palette — background in dark, fg in light
    readonly property color dim: light ? fg : bg

    readonly property string dot: "Doto"                   // numbers and short words, no smaller than 26px
    readonly property string ui: "Space Grotesk"
    readonly property string mono: "Space Mono"            // labels in caps
    readonly property string nf: "JetBrainsMono Nerd Font" // icons

    // layout canvas 1920×1080 → screen. ponytail: by the first screen; monitors of different sizes — compute from the window's screen
    readonly property real s: {
        const sc = Quickshell.screens[0];
        return sc ? Math.min(sc.width / 1920, sc.height / 1080) : 1;
    }

    // glide: ease-out-quart, no overshoot — like bezier glide in hypr
    readonly property var glide: [0.25, 1, 0.5, 1, 1, 1]
    readonly property int t: 350

    // the wallpaper is drawn from a screen-sized copy (the picker makes it, magick): the original can be a 40 MB png, it would load for seconds.
    // ponytail: no copy (the cache was wiped, the path typed by hand) — empty, grid and orb, until the picker is opened
    readonly property string wallCache: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/glyph/walls"
    function wallSrc(p) { return p ? `${wallCache}/${p.slice(p.lastIndexOf("/") + 1)}.jpg` : ""; }

    function fade(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }
    // clock by the 12/24 setting: «09» or «9»
    function hh(d) { const h = d.getHours(); return st.clock24 ? String(h).padStart(2, "0") : String(h % 12 || 12); }
    function hex(c) { return c.toString().slice(1, 7).toUpperCase(); }

    // like in Rules: apply() at startup has to see glyph.json, not the defaults
    Component.onCompleted: stateFile.waitForJob()

    FileView {
        id: stateFile
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/rice/glyph.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        // write — once at the end of the turn: writeAdapter() on every field in a row mixes up neighbours
        onAdapterUpdated: Qt.callLater(stateFile.writeAdapter)
        onLoadFailed: err => { if (err === FileViewError.FileNotFound) writeAdapter(); }

        JsonAdapter {
            id: st
            property bool light: false
            property bool dnd: false  // new ones aren't shown, critical ones — always
            property int unread: 0    // for the lock
            // ---- what the settings (prefs) change ----
            property var widgets: ["weather", "calendar", "cpu", "player", "buds", "system"] // the home bento in order, see kinds
            property bool clock24: true
            property bool blink: true      // the clock colon blinks
            property string name: ""       // in the greeting; empty — $USER
            property bool grid: true       // the dot grid on the wallpaper
            property bool orb: true        // the halftone orb
            // color from the wallpaper: on, style (tint.js styles), saturation %, which seed
            property bool match: false
            property int matchStyle: 0
            property int matchSat: 100
            property int matchSeed: 0
            property bool extraDark: false // dark: the background pure black, surfaces darker (tint.js extraDark)
            // the home photo widget (services/Photos): folder (empty — ~/Pictures/glyph), circle or square, look like the wallpaper
            // (0 dots, 3 color dots, 2 color), changes every photoSecs
            property string photoDir: ""
            property bool photoRound: false
            property int photoLook: 2
            property int photoSecs: 8
            // wallpaper (the wall/Walls picker, drawn by components/Wall): the image path; empty — grid and orb. The picker's folder can be changed here
            property string wall: ""
            property string wallDir: ""    // empty — ~/Pictures/Wallpapers
            property int wallLook: 0       // 0 dots, 1 grey photo, 2 color, 3 color dots
            property int wallPitch: 10     // dot spacing, px
            property int wallBright: 85    // %, from the background to the image
            property bool wallGlass: false // ribbed glass over the look
            property bool atmosphere: false // lock: the wallpaper in a haze, clearing up on unlock
            property int wallRib: 28       // rib width, px
            property int wallBend: 50      // %, rib bend
            property int rounding: 20      // hypr windows
            property bool edges: true      // Glyph bars along the edges (volume/brightness, flashes, progress)
            property int briSteps: 20      // brightness from keys: steps per scale, 40/20/10 — a step of 2.5/5/10 %
            property bool quickHover: true // quick settings on hovering the right edge
            property bool deckHover: true  // deck — the bottom-center panel, slides out on hovering the edge
            property var deck: ["clock", "weather", "perf", "net", "media"] // its sections in order, see decks
            property var bar: ["layout", "wifi", "bluetooth", "sound", "notes", "battery", "mode", "power"] // the bar's tray top to bottom, see bars
            property bool barTitle: true   // the window title as a column in the bar
            // bar on the right: quick settings and their hot edge — on the left, volume/brightness — into the island (the right edge is taken)
            property bool barRight: false
            property int glyphLights: 0    // where volume/brightness and progress light up: 0 at the edges, 1 in the island at the top
            // workspaces (System → workspaces, the count — also in the overview): how many per group of ten, whether ±1 wraps,
            // bar: 0 — occupied and current, 1 — all; switch: slidevert · slide · fade; blur on special workspaces
            property int wsCount: 10
            property bool wsWrap: true
            property int wsBar: 0
            property string wsAnim: "slidevert"
            property bool wsBlurSpecial: false
            // Lite mode (System → power): fewer effects for slower machines. liteSet — the user (or the first-run RAM check) decided
            property bool lite: false
            property bool liteSet: false
            // recording (quick/Rec, Sys.recArgs)
            property int recArea: 0        // 0 the whole monitor, 1 a region (slurp)
            property int recAudio: 0       // 0 no sound, 1 system, 2 microphone, 3 both on one track
            property int recFps: 60
            property int recQuality: 2     // medium, high, very_high, ultra
            property bool recCursor: true
        }
    }

    // bento widgets: id → width in cells (a grid of 3 columns × 3 rows of 220). Doesn't fit — not shown
    readonly property var kinds: ({ weather: 1, calendar: 1, cpu: 1, ram: 1, gpu: 1, disk: 1, battery: 1, buds: 1, player: 2, system: 3, cat: 1, cava: 1, photo: 1 })
    // deck sections
    readonly property var decks: ["clock", "weather", "perf", "net", "media"]
    // bar tray
    readonly property var bars: ["layout", "wifi", "bluetooth", "sound", "notes", "battery", "mode", "power"]

    // ---- the look of everything outside the shell. Only shell.qml calls it: at startup and on a theme change ----
    // hypr inherits demonshot: monitor, input, idle, night light and motion are set by its Rules (shell.qml), animations — from the
    // hypr config. From here — gaps/border/blur/shadows from its rules.json, and glyph's own — border colors, shadows, groups, background and
    // rounding 20 (without them demonshot's red glow and groups from hypr/variables.lua would remain).
    // Back to demonshot: `rice switch` does hyprctl reload, its applyAll repaints
    function hypr(lua) { Quickshell.execDetached(["hyprctl", "eval", lua]); }

    // kitty includes this file after its own colors (include in kitty.conf); demonshot writes its palette to the same place
    FileView { id: kitty; path: Quickshell.env("HOME") + "/.config/demonshot/kitty.conf"; printErrors: false }
    // 16 ANSI from the concept: pastel only for the terminal. In the light theme 0↔15 and 7↔8, so white doesn't get lost on white
    readonly property var ansi: ["#0E0E0E", "#D71921", "#9BB59A", "#D9C38A", "#8EA3C2", "#B79BC2", "#8FB8B8", "#C9C9C9",
                                 "#4A4A4A", "#F0434B", "#B5CCB4", "#E8D6A8", "#AABBD4", "#CDB6D6", "#ABCDCD", "#F2F2F2"]

    // mono hex → palette q hex: that's how kitty ANSI and the template files are recolored (they have the same greys and red as Theme)
    function remap(mono, q) {
        const m = {};
        for (const k of ["bg", "s1", "s2", "s3", "mute", "grey", "fg", "ink", "red"]) if (!(mono[k] in m)) m[mono[k]] = q[k];
        return m;
    }

    // gtk and qt read their files at startup — we write copies of the templates from term/ with the colors swapped. The templates are dark: roles of the dark
    // mono palette → the current theme's palette, so the light theme flips them too (together with gsettings in apply). Dark without
    // color from the wallpaper — the copy as is. apply calls it on every palette change; without changes the file isn't rewritten.
    // btop isn't here: its ~/.config/btop is a link into term/, the copy would land on the template itself
    readonly property var files: [["term/gtk-3.0/gtk.css", ".config/gtk-3.0/gtk.css"], ["term/gtk-4.0/gtk.css", ".config/gtk-4.0/gtk.css"],
                                  ["term/qtengine.colors", ".config/qtengine.colors"]]
    function paintFiles() {
        const m = remap(darkMono, p);
        const sed = [].concat(...Object.keys(m).filter(k => k !== m[k]).map(k => ["-e", `s/${k}/${m[k]}/gI`]));
        // rewrite only if it changed; no destination directory — the program isn't installed; the destination is the template itself (a link) — leave it
        for (const [src, dst] of files)
            Quickshell.execDetached(["sh", "-c", 'src=$1 dst=$2; shift 2; [ -d "${dst%/*}" ] || exit 0; '
                + '[ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ] && exit 0; '
                + 'sed -e "" "$@" "$src" > "$dst.new" && { cmp -s "$dst.new" "$dst" && rm "$dst.new" || mv "$dst.new" "$dst"; }',
                "sh", Quickshell.shellPath(src), Quickshell.env("HOME") + "/" + dst].concat(sed));
    }

    // strata: it doesn't read gtk.css, the theme is its own toml in ~/.config/strata/themes, reloaded live (open windows
    // are recolored at once). Pick it once: Settings → Appearance → glyph. Accent — fg, like glyph's «on and selected —
    // white»; red — only danger. Code highlighting — ANSI pastel, in dark; in light strata uses its own. No strata — nothing.
    // The temporary file isn't .toml: strata would pick it up as yet another theme
    function paintStrata() {
        const lines = [["name", "glyph"], ["background", p.bg], ["surface", p.s1], ["text", p.fg], ["accent", p.fg], ["danger", p.red],
                       ["muted", p.s2], ["highlight", p.s3], ["border", p.s3], ["dim_text", p.grey]];
        if (!light) lines.push(["syntax_keyword", ansi[5]], ["syntax_string", ansi[2]], ["syntax_constant", ansi[3]], ["syntax_type", ansi[4]], ["syntax_preprocessor", ansi[6]]);
        const text = "# glyph: written by Theme.apply(), don't edit by hand\n" + lines.map(([k, v]) => `${k} = "${v}"`).join("\n") + "\n";
        Quickshell.execDetached(["sh", "-c", 'command -v strata >/dev/null || [ -x "$HOME/.local/bin/strata" ] || exit 0; '
            + 'd=$HOME/.config/strata/themes; mkdir -p "$d" && printf "%s" "$1" > "$d/.glyph.tmp" '
            + '&& { cmp -s "$d/.glyph.tmp" "$d/glyph.toml" && rm "$d/.glyph.tmp" || mv "$d/.glyph.tmp" "$d/glyph.toml"; }', "sh", text]);
    }

    // workspaces in hypr: the limit and wrap are read by the binds (functions.lua, glyph_ws_* globals). The swipe is hypr's own: empty workspaces
    // don't exist until you go to them, and without create_new there'd be nowhere to swipe — we leave it alone
    function workspaces() {
        hypr(`glyph_ws_limit = ${st.wsCount}; glyph_ws_wrap = ${st.wsWrap}; `
           + `hl.config({ decoration = { blur = { special = ${st.wsBlurSpecial} } } }); `
           + `hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "standard", style = "${st.wsAnim}" })`);
    }

    function apply() {
        // colors — the target ones (p), not the ones halfway through the animation
        const { bg, s1, s2, s3, mute, grey, fg, ink } = p;
        // game mode (Rules.store.game) — on top of the settings, like ultra: border 1, no gaps or rounding, tearing for
        // windows with immediate (games, hyprland/rules.lua). On leaving — your values come back, allow_tearing — false, as in general.lua
        const r = Rules.store, g = r.game;
        const c = x => `"rgb(${hex(x)})"`;
        // shadow: in dark — a barely visible white glow, in light — a soft dark one (fg: with the wallpaper — its deep tone)
        const shadow = light ? `rgba(${hex(fg)}2E)` : `rgba(${hex(fg)}1A)`;
        hypr(`hl.config({ general = { gaps_in = ${g ? 0 : r.gapsIn}, gaps_out = ${g ? 0 : r.gapsOut}, border_size = ${g ? 1 : r.border}, allow_tearing = ${g}, `
           + `col = { active_border = ${c(fg)}, inactive_border = ${c(s3)} } }, `
           + `decoration = { rounding = ${g ? 0 : st.rounding}, blur = { enabled = ${Rules.blurOn && !st.lite} }, shadow = { enabled = ${Rules.shadowOn && !st.lite}, color = "${shadow}" } }, `
           + `group = { col = { border_active = ${c(fg)}, border_inactive = ${c(s3)}, border_locked_active = ${c(fg)}, border_locked_inactive = ${c(mute)} }, `
           + `groupbar = { font_family = "${mono}", text_color = ${c(fg)}, col = { active = ${c(s3)}, inactive = ${c(s1)}, locked_active = ${c(s3)}, locked_inactive = ${c(s1)} } } }, `
           + `misc = { background_color = ${c(bg)} } })`);

        // ANSI: greys and red — from the palette (bright red 9 — the same accent), pastel as is
        const m = remap(darkMono, paletteFor(false));
        const tinted = ansi.map((x, i) => matched && i === 9 ? p.red : m[x] ?? x);
        const a = light ? [15, 1, 2, 3, 4, 5, 6, 8, 7, 9, 10, 11, 12, 13, 14, 0].map(i => tinted[i]) : tinted;
        kitty.setText("# glyph: written by Theme.apply(), don't edit by hand\n" + [
            ["font_family", "Space Mono"], ["window_padding_width", "26 30"], ["cursor_trail", "0"],
            ["foreground", fg], ["background", s1], ["cursor", fg], ["cursor_text_color", s1],
            ["selection_foreground", fg], ["selection_background", s3], ["url_color", grey],
            ["active_border_color", fg], ["inactive_border_color", s3],
            ["active_tab_foreground", ink], ["active_tab_background", fg],
            ["inactive_tab_foreground", grey], ["inactive_tab_background", s1], ["tab_bar_background", bg]
        ].concat(a.map((c, i) => ["color" + i, c])).map(([k, v]) => `${k} ${typeof v === "string" ? v : v.toString().slice(0, 7).toUpperCase()}`).join("\n") + "\n");
        Quickshell.execDetached(["pkill", "-USR1", "-x", "kitty"]);

        // apps follow the shell's theme: the portal (browsers, libadwaita) and the gtk3 base under our gtk.css, plus the gtk/qt files themselves
        if (warm) applyApps();
        else appsDue = true;
    }
    // apps follow the shell's theme: the portal (browsers, libadwaita) and the gtk3 base under our gtk.css, plus the gtk/qt files themselves.
    // At login this waits a moment — the bar and home come first, re-theming the apps can be a couple of seconds late
    property bool warm: false
    property bool appsDue: false
    Timer {
        running: true
        interval: 2500
        onTriggered: {
            root.warm = true;
            if (root.appsDue) root.applyApps();
        }
    }
    function applyApps() {
        appsDue = false;
        // only when it differs: every write makes the portal tell all apps to re-theme
        const set = (k, v) => Quickshell.execDetached(["sh", "-c", '[ "$(gsettings get org.gnome.desktop.interface "$1")" = "\'$2\'" ] || gsettings set org.gnome.desktop.interface "$1" "$2"', "sh", k, v]);
        set("color-scheme", light ? "prefer-light" : "prefer-dark");
        set("gtk-theme", light ? "adw-gtk3" : "adw-gtk3-dark");
        paintFiles();
        paintStrata();
    }

    // Lite mode turns itself on once on machines under ~7.5 GB of RAM; after that it's the user's switch
    Process {
        running: !st.liteSet
        command: ["sh", "-c", "awk '/MemTotal/ {print $2}' /proc/meminfo"]
        stdout: StdioCollector {
            onStreamFinished: {
                const kb = +text.trim();
                if (st.liteSet || !kb) return;
                st.lite = kb < 7500000;
                st.liteSet = true;
            }
        }
    }
    // a flag file for what runs outside the shell: hypr's execs.lua skips the background kitty when it's there
    function liteFlag() {
        Quickshell.execDetached(["sh", "-c", 'd="${XDG_STATE_HOME:-$HOME/.local/state}/rice"; mkdir -p "$d"; if [ "$1" = true ]; then touch "$d/lite"; else rm -f "$d/lite"; fi', "sh", String(st.lite)]);
    }
}
