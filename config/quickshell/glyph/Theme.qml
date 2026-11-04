pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.settings
import "schemes.js" as Schemes

// glyph: black, white dots, one red. Palette, fonts, motion, state (theme, quiet) and the hypr/kitty look — here
Singleton {
    id: root

    // the state survives a restart, the lock (a separate process) reads it too
    readonly property alias state: st
    // color — where from (launcher → style, settings → STYLE), like scheme in caelestia: nothing — black, white and red; wall —
    // from a wallpaper tone by variant, like dynamic in caelestia (tonal spot, fruit salad… — schemes.js); scheme — a ready palette, it has
    // its own theme. A palette — { light, c: greys by the roles below, accent, red, ansi: 16 kitty colors }
    readonly property var pal: make({})
    readonly property bool light: pal.light

    // light theme — the same layout, the greys reversed; red doesn't change
    readonly property var glyphDark: ["#000000", "#0E0E0E", "#1A1A1A", "#2A2A2A", "#4A4A4A", "#8C8C8C", "#F2F2F2"]
    readonly property var glyphLight: ["#E9E9E9", "#FFFFFF", "#F1F1F1", "#D9D9D9", "#B8B8B8", "#6E6E6E", "#0B0B0B"]
    readonly property var greys: pal.c
    // the colors glide to the palette: wallpaper, theme, look — no jump. apply() writes hypr and kitty from the targets (greys), not from halfway
    property color bg: greys[0]   // background, wallpaper
    property color s1: greys[1]   // bar, panels
    property color s2: greys[2]   // tiles, off
    property color s3: greys[3]   // lines, dimmed dots
    property color mute: greys[4] // inactive
    property color grey: greys[5] // labels, secondary
    property color fg: greys[6]   // text, on, focus
    property color ink: light ? greys[1] : greys[0] // text on a white tile
    property color accent: pal.accent // at most one thing on screen, and only «live»
    property color red: pal.red       // alarm: battery, critical, wrong password
    readonly property color nothingRed: "#D71921"
    Behavior on bg { ColorAnimation { duration: 600 } }
    Behavior on s1 { ColorAnimation { duration: 600 } }
    Behavior on s2 { ColorAnimation { duration: 600 } }
    Behavior on s3 { ColorAnimation { duration: 600 } }
    Behavior on mute { ColorAnimation { duration: 600 } }
    Behavior on grey { ColorAnimation { duration: 600 } }
    Behavior on fg { ColorAnimation { duration: 600 } }
    Behavior on ink { ColorAnimation { duration: 600 } }
    Behavior on accent { ColorAnimation { duration: 600 } }
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
        if (!sc) return 1;
        // orientation-agnostic: a rotated (portrait) first screen would give 0.56 and shrink everything
        return Math.min(Math.max(sc.width, sc.height) / 1920, Math.min(sc.width, sc.height) / 1080);
    }

    // glide: ease-out-quart, no overshoot — like bezier glide in hypr
    readonly property var glide: [0.25, 1, 0.5, 1, 1, 1]
    readonly property int t: 350

    // the wallpaper is drawn from a screen-sized copy (the picker makes it, magick): the original can be a 40 MB png, it would load for seconds.
    // ponytail: no copy (the cache was wiped, the path typed by hand) — empty, grid and orb, until the picker is opened
    readonly property string wallCache: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/glyph/walls"
    function wallSrc(p) { return p ? `${wallCache}/${p.slice(p.lastIndexOf("/") + 1)}.jpg` : ""; }
    function url(p) { return p ? "file://" + p.split("/").map(encodeURIComponent).join("/") : ""; }

    // ---- the wallpaper's tones: up to four to choose from, like in android. They live in glyph.json: the lock (a separate process) takes them ready and doesn't flash
    // red ----
    readonly property var tones: st.wall ? st.tones : []
    function hueName(c) {
        const h = Qt.color(c).hslHue * 360;
        return ["red", "orange", "yellow", "green", "teal", "blue", "violet", "pink", "red"][[15, 40, 65, 160, 195, 250, 290, 335, 361].findIndex(x => h < x)];
    }
    // the palette as it would be with st but o replaced ({ paint, scheme, at, variant, light }): the shell lives by it (o empty), the STYLE
    // swatches show it too. No tones (a grey wallpaper, no image) — nothing
    function make(o) {
        const k = Object.assign({ paint: st.paint, scheme: st.scheme, at: st.paintAt, variant: st.variant, light: st.light }, o);
        const dark = p => !p.light && st.extraDark ? Schemes.extraDark(p) : p;
        if (k.paint === "scheme") return dark(Schemes.ALL.find(p => p.id === k.scheme) ?? Schemes.ALL[0]);
        // 16 ANSI glyph: in light 0↔15 and 7↔8, so white doesn't get lost on white
        const base = { light: k.light, c: k.light ? glyphLight : glyphDark, accent: nothingRed, red: nothingRed,
                       ansi: k.light ? [15, 1, 2, 3, 4, 5, 6, 8, 7, 9, 10, 11, 12, 13, 14, 0].map(i => ansi[i]) : ansi };
        const src = tones[Math.min(k.at, tones.length - 1)];
        return dark(k.paint === "wall" && src ? Schemes.dynamic(src, k.variant, base, st.paintSat) : base);
    }
    // theme: a palette has itself or a pair from its group (mocha → latte, dawn → main); no pair (nord, dracula…) — the theme doesn't
    // change, otherwise st.light would drift from the screen and surface when the source changes
    function pair(l) { return st.paint !== "scheme" ? null : pal.light === l ? pal : Schemes.ALL.find(x => x.group === pal.group && x.light === l) ?? null; }
    function setLight(l) {
        const p = pair(l);
        if (st.paint === "scheme" && !p) return;
        if (p) st.scheme = p.id;
        st.light = l;
    }
    // the choice for the launcher (style) and settings (STYLE): blocks { head, items: [{ name, pal, fill, dot, now, run }] }; pal — the palette
    // if picked, fill — the swatch circle, dot — a smaller circle in it (the accent), now — set right now. First where color comes from, under it —
    // what that source has: the wallpaper's tones and variants, or palettes by group; the theme last
    readonly property var styles: {
        const set = (k, v) => () => st[k] = v, at = Math.min(st.paintAt, tones.length - 1);
        const it = (name, p, now, run, fill) => ({ name, pal: p, fill: fill ?? p.c[1], dot: p.accent, now, run });
        const own = st.paint === "wall" ? [
            { head: "tones", items: tones.map((t, i) => it(hueName(t), make({ at: i }), at === i, set("paintAt", i), t)) },
            // the circle — the variant's mute grey (shows where the greys went), the accent in it; amount — the share of color, in order
            { head: "variant", items: tones.length ? Schemes.VARIANTS.map((v, i) => {
                const p = make({ variant: v.id });
                return Object.assign(it(v.name, p, st.variant === v.id, set("variant", v.id), p.c[4]), { amount: i / (Schemes.VARIANTS.length - 1) });
            }) : [] }
        ] : st.paint === "scheme" ? Schemes.GROUPS.map(g => ({ head: g, items: Schemes.ALL.filter(p => p.group === g).map(p =>
            Object.assign(it(p.name, p, st.scheme === p.id, () => { st.scheme = p.id; st.light = p.light; }), { extra: g })) })) : [];
        return [{ head: "source", items: [
            it("nothing", make({ paint: "" }), !st.paint || st.paint === "wall" && !tones.length, set("paint", ""), nothingRed),
            it("wallpaper", make({ paint: "wall" }), st.paint === "wall" && !!tones.length, set("paint", "wall"), tones[0]),
            it("palette", make({ paint: "scheme" }), st.paint === "scheme", set("paint", "scheme"))
        ] }].concat(own.filter(b => b.items.length), [
            { head: "theme", items: [["dark", false], ["light", true]].map(([n, l]) => it(n, make({ light: l, scheme: pair(l)?.id ?? st.scheme }),
                light === l, () => setLight(l))) }
        ]);
    }
    // like score in material you, only simpler: the quantizer cuts the image into 16 pieces of equal area and gives each one's average
    // color. The juicy ones vote (chroma — max − min of the channels — above 0.12; below it big faded fills win, not the image's
    // color): the hue with the most (±15°) goes first, the juiciest among its own. Then up to three others, at least 30° from
    // each other. None juicy — no tones, red stays. The quantizer in shell.qml calls it (not here: the lock loads Theme too)
    function pick(cols) {
        const ch = c => c.hsvSaturation * c.hsvValue, d = (a, b) => Math.abs((a.hsvHue - b.hsvHue + 1.5) % 1 - 0.5);
        const all = Array.from(cols), live = all.filter(c => ch(c) > 0.12);
        const score = c => 0.7 * live.filter(o => d(o, c) < 1 / 24).length / all.length + 0.3 * ch(c);
        const out = [];
        for (const c of live.sort((a, b) => score(b) - score(a)))
            if (out.length < 4 && out.every(o => d(o, c) >= 1 / 12)) out.push(c);
        return out.map(c => c.toString());
    }
    // relative luminance, as in WCAG
    function lum(c) { c = Qt.lighter(c, 1); const f = v => v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b); }
    // what to write over color c: black or white, whichever has more contrast (the 0.18 luminance threshold — per WCAG)
    function on(c) { return lum(c) > 0.18 ? "#000000" : "#FFFFFF"; }

    function fade(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }
    // the corner radius of a panel, tile or pill — by the corners setting (prefs → WINDOWS → panels): 0 square, 100 as designed
    function corner(px) { return px * st.corners / 100; }
    // clock by the 12/24 setting: «09» or «9»
    function hh(d) { const h = d.getHours(); return st.clock24 ? String(h).padStart(2, "0") : String(h % 12 || 12); }
    function hex(c) { return c.toString().slice(1, 7).toUpperCase(); }

    readonly property string riceState: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/rice"
    readonly property bool barRight: st.barAt === "right"
    // like in Rules: apply() at startup has to see glyph.json, not the defaults. Then settings from before the Style page move over, once
    function migrate() {
        if (st.match) {
            st.paint = "wall";
            st.variant = ["neutral", "tonalspot", "vibrant", "rainbow", "expressive"][st.matchStyle] ?? "tonalspot";
            st.paintSat = st.matchSat;
            st.paintAt = st.matchSeed;
            st.match = false;
        }
        if (st.barRight) {
            st.barAt = "right";
            st.barRight = false;
        }
    }
    Component.onCompleted: {
        stateFile.waitForJob();
        migrate();
    }

    FileView {
        id: stateFile
        path: root.riceState + "/glyph.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        // write — once at the end of the turn: writeAdapter() on every field in a row mixes up neighbours
        onAdapterUpdated: Qt.callLater(stateFile.writeAdapter)
        onLoadFailed: err => { if (err === FileViewError.FileNotFound) writeAdapter(); }

        JsonAdapter {
            id: st
            property bool light: false
            property string paint: ""     // where color comes from: empty — nothing, wall — the wallpaper, scheme — a palette
            property string scheme: "mocha" // which palette, an id from schemes.js
            property int paintAt: 0       // which of the wallpaper's tones
            property var tones: []        // the wallpaper's tones, written by the quantizer; empty — a grey wallpaper or no image
            property string variant: "tonalspot" // how a wallpaper tone becomes a palette, an id from schemes.js (VARIANTS)
            property int paintSat: 100    // %, the amount of color taken from the wallpaper
            property bool dnd: false  // new ones aren't shown, critical ones — always
            property int unread: 0    // for the lock
            // ---- what the settings (prefs) change ----
            property var widgets: ["weather", "calendar", "cpu", "player", "buds", "system"] // the home bento in order, see kinds
            property bool clock24: true
            property bool blink: true      // the clock colon blinks
            property string name: ""       // in the greeting; empty — $USER
            property bool grid: true       // the dot grid on the wallpaper
            property bool orb: true        // the halftone orb
            // older color settings, moved to paint, variant, paintSat and paintAt by migrate()
            property bool match: false
            property int matchStyle: 0
            property int matchSat: 100
            property int matchSeed: 0
            property bool extraDark: false // dark: the background pure black, surfaces darker (Schemes.extraDark)
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
            property bool wallPulse: false // the wallpaper swells with the music's bass; starts cava, so it's off until asked for (wall picker → beat)
            property bool homeClock: true  // home shows the clock and date (prefs → LOOK → on home)
            property bool homeHello: true  // … the greeting and the line under it
            property bool homeBento: true  // … the widgets
            property bool lockHideLen: false // lock: three fixed dots while typing, the password's length doesn't show
            property bool lockOneScreen: false // lock: the full lock only on the screen in focus, the others go plain
            property bool autoGame: true   // a fullscreen game turns on game mode and do not disturb (services/Game)
            property var gameAuto: null    // services/Game — what game mode and dnd were before it, null when it's not holding them
            property string gif: ""        // the gif tile on home (services/Gifs), a path; empty — the first in the folder
            property string gifDir: ""     // empty — ~/Pictures/Gifs
            property int rounding: 20      // hypr windows
            property int corners: 100      // the shell's panel corners, % of their own; circles stay circles (Theme.corner)
            property bool edges: true      // Glyph bars along the edges (volume/brightness, flashes, progress)
            property int briSteps: 20      // brightness from keys: steps per scale, 40/20/10 — a step of 2.5/5/10 %
            property bool quickHover: true // quick settings on hovering the right edge
            property bool deckHover: true  // deck — the bottom-center panel, slides out on hovering the edge
            property var deck: ["clock", "weather", "perf", "net", "media"] // its sections in order, see decks
            property var bar: ["layout", "wifi", "bluetooth", "sound", "notes", "battery", "mode", "power"] // the bar's tray top to bottom, see bars
            property bool barTitle: true   // the window title along the bar
            // left, right or top; calendar, battery card, home, island and the Glyph flash follow it. On the right quick settings and
            // their hot edge move left, volume/brightness — into the island (the right edge is taken)
            property string barAt: "left"
            property var barHide: []       // screen names where the bar auto-hides (experimental), see bar/Bar.qml
            property bool barRight: false  // older setting, moved to barAt by migrate()
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
    readonly property var bars: ["layout", "wifi", "bluetooth", "sound", "notes", "battery", "mode", "power", "cat"]

    // ---- the look of everything outside the shell. Only shell.qml calls it: at startup and on a theme or color change ----
    // hypr inherits demonshot: monitor, input, idle, night light and motion are set by its Rules (shell.qml), animations — from the
    // hypr config. From here — gaps/border/blur/shadows from its rules.json, and glyph's own — border colors, shadows, groups, background and
    // rounding 20 (without them demonshot's red glow and groups from hypr/variables.lua would remain).
    // Back to demonshot: `rice switch` does hyprctl reload, its applyAll repaints
    function hypr(lua) { Quickshell.execDetached(["hyprctl", "eval", lua]); }

    // kitty includes this file after its own colors (include in kitty.conf); demonshot writes its palette to the same place
    FileView { id: kitty; path: Quickshell.env("HOME") + "/.config/demonshot/kitty.conf"; printErrors: false }
    // 16 ANSI from the concept: pastel only for the terminal. The light theme swaps them around (make)
    readonly property var ansi: ["#0E0E0E", "#D71921", "#9BB59A", "#D9C38A", "#8EA3C2", "#B79BC2", "#8FB8B8", "#C9C9C9",
                                 "#4A4A4A", "#F0434B", "#B5CCB4", "#E8D6A8", "#AABBD4", "#CDB6D6", "#ABCDCD", "#F2F2F2"]

    // strata: it doesn't read gtk.css, the theme is its own toml in ~/.config/strata/themes, reloaded live (open windows
    // are recolored at once). Pick it once: Settings → Appearance → glyph. Accent — fg, like glyph's «on and selected —
    // white»; red — only danger. Code highlighting — ANSI pastel, in dark; in light strata uses its own. No strata — nothing.
    // The temporary file isn't .toml: strata would pick it up as yet another theme
    function paintStrata() {
        const [bg, s1, s2, s3, , grey, fg] = greys, a = pal.ansi;
        const lines = [["name", "glyph"], ["background", bg], ["surface", s1], ["text", fg], ["accent", fg], ["danger", pal.red],
                       ["muted", s2], ["highlight", s3], ["border", s3], ["dim_text", grey]];
        if (!pal.light) lines.push(["syntax_keyword", a[5]], ["syntax_string", a[2]], ["syntax_constant", a[3]], ["syntax_type", a[4]], ["syntax_preprocessor", a[6]]);
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
        // colors — the target ones (greys), not the ones halfway through the animation
        const [bg, s1, s2, s3, mute, grey, fg] = greys, ink = pal.light ? s1 : bg;
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

        kitty.setText("# glyph: written by Theme.apply(), don't edit by hand\n" + [
            ["font_family", "Space Mono"], ["window_padding_width", "26 30"], ["cursor_trail", "0"],
            ["foreground", fg], ["background", s1], ["cursor", fg], ["cursor_text_color", s1],
            ["selection_foreground", fg], ["selection_background", s3], ["url_color", grey],
            ["active_border_color", fg], ["inactive_border_color", s3],
            ["active_tab_foreground", ink], ["active_tab_background", fg],
            ["inactive_tab_foreground", grey], ["inactive_tab_background", s1], ["tab_bar_background", bg]
        ].concat(pal.ansi.map((c, i) => ["color" + i, c])).map(([k, v]) => `${k} ${typeof v === "string" ? v : v.toString().slice(0, 7).toUpperCase()}`).join("\n") + "\n");
        Quickshell.execDetached(["pkill", "-USR1", "-x", "kitty"]);
    }
    // at login apps() waits a moment — the bar and home come first, re-theming the apps can be a couple of seconds late
    property bool warm: false
    property bool appsDue: false
    Timer {
        running: true
        interval: 2500
        onTriggered: {
            root.warm = true;
            if (root.appsDue) root.apps();
        }
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

    // apps follow the shell's color — only on a color change (shell.qml): apply() is also called on every step of the rounding ring.
    // The portal (browsers, libadwaita) and the gtk3 base under our gtk.css first. The templates are our own term/ (the dark glyph
    // palette): its colors become the same roles of the palette (greys, red, for qt also green/yellow/blue… from ansi), copies go to
    // riceState/glyph, the ~/.config/… links to the copies. Nothing to change — back to term/, as rice sets it. A real file (not a link)
    // is left alone, like rice. Swapped in two passes via @n@: a palette color can match a glyph color replaced next. gtk and qt take
    // colors on their next start: gtk reads its gtk.css once, poking the theme doesn't help (tested on gtk 3 and 4).
    // btop isn't themed — its folder is a link into the repo as a whole, the copy would have nowhere to go
    function apps() {
        if (!warm) {
            appsDue = true;
            return;
        }
        appsDue = false;
        // only when it differs: every write makes the portal tell all apps to re-theme
        const set = (k, v) => Quickshell.execDetached(["sh", "-c", '[ "$(gsettings get org.gnome.desktop.interface "$1")" = "\'$2\'" ] || gsettings set org.gnome.desktop.interface "$1" "$2"', "sh", k, v]);
        set("color-scheme", pal.light ? "prefer-light" : "prefer-dark");
        set("gtk-theme", pal.light ? "adw-gtk3" : "adw-gtk3-dark");
        paintStrata();
        const from = glyphDark.concat(ansi.slice(1, 7));
        const to = pal.c.concat([pal.red], pal.ansi.slice(2, 7));
        const pairs = from.map((c, i) => [c, "#" + hex(Qt.lighter(to[i], 1))]).filter(([a, b]) => a !== b);
        const sed = pairs.map(([a], i) => ["-e", `s/${a}/@${i}@/gI`]).concat(pairs.map(([, b], i) => ["-e", `s/@${i}@/${b}/g`])).reduce((x, y) => x.concat(y), []);
        Quickshell.execDetached(["bash", "-c", `t=$1 o=$2; shift 2
for f in gtk-3.0/gtk.css gtk-4.0/gtk.css qtengine.colors; do
    l=$HOME/.config/$f
    [ -L "$l" ] || [ ! -e "$l" ] || continue
    if [ $# -gt 0 ]; then mkdir -p "$(dirname "$o/$f")" && sed "$@" "$t/$f" > "$o/$f" && ln -sfn "$o/$f" "$l"; else ln -sfn "$t/$f" "$l"; fi
done`,
            "bash", Quickshell.shellPath("term"), riceState + "/glyph"].concat(sed));
    }
}
