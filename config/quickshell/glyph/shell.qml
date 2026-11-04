//@ pragma IconTheme Rice
// our own icon theme, not qtengine's: if it didn't load Qt looks only in hicolor, and kcalc and the like get empty circles (#11)
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.services
import "bar"
import "buds"
import "cal"
import "charms"
import "clip"
import "deck"
import "glyph"
import "home"
import "launcher"
import "overview"
import "power"
import "prefs"
import "quick"
import "settings"
import "shot"
import "system"
import "vpn"
import "wall"
import "welcome"

// glyph: a rice in the spirit of nothing os. Home on the wallpaper, bar, launcher, quick settings,
// Glyph bars along the edges instead of an OSD, the notification island, power menu, settings, deck (bottom dashboard), clipboard, charms (emoji and symbols), screenshots, vpn, wallpapers. The lock — a separate process (lock.qml).
// Switches from demonshot via `rice switch` / the Rice app — hypr binds are shared (shell:*), each shell takes its own
ShellRoot {
    id: shell

    // always built: the launcher and quick settings open instantly, the deck catches the bottom edge, the screenshot freezes the
    // screen at once, the vpn watches for sign-in pages in the background. The rest — Lazy: built when first opened, freed later
    Launcher { id: launcher }
    Quick { id: quick; onPowerRequested: power.get().open(); onSettingsRequested: system.get().open() }
    Agent {} // bluetooth and network ask for a code or password — a window (system/agent.py)
    Auth {} // polkit asks for your password (pkexec, firewall, battery, hostname) — above every panel
    Glyph {}
    Buds {}
    Deck { id: deck }
    Shot { id: shot }
    Vpn { id: vpn }
    LazyLoader { active: !Theme.state.welcomed; Welcome {} }
    Lazy { id: overview; component: Overview { onSettingsRequested: system.get().openAt("WORKSPACES") } } // Super+Tab: all workspaces and windows, drag a window onto a workspace
    Lazy { id: power; component: Power {} }
    Lazy { id: prefs; component: Prefs { onWallRequested: walls.get().open() } }
    Lazy { id: system; component: System { onCustomizeRequested: prefs.get().open() } } // the quick settings gear: network, bluetooth, sound, display
    Lazy { id: cal; component: Cal {} }
    Lazy { id: clip; component: Clip {} }
    Lazy { id: charms; component: Charms {} }
    Lazy { id: walls; component: Walls {} }
    readonly property bool gaming: Game.on // a singleton only lives once something touches it
    function togglePower() { const p = power.get(); p.visible ? p.close() : p.open(); }

    Variants {
        model: Quickshell.screens
        Scope {
            id: s
            required property var modelData
            Back { screen: s.modelData }
            Home { screen: s.modelData }
            Hot { screen: s.modelData; onTriggered: quick.peek() }
            Bar {
                screen: s.modelData
                onMarkClicked: launcher.toggle()
                onTrayClicked: quick.toggle()
                onPowerClicked: shell.togglePower()
                onClockClicked: cal.get().toggle()
            }
        }
    }

    // hypr like demonshot's: its Rules (settings/Rules.qml, the same ~/.config/demonshot/rules.json) sets the monitor, input,
    // motion, night light and hypridle; on top Theme.apply — its own border colors, rounding and kitty. We call it on a theme change too
    Component.onCompleted: {
        hypr();
        Theme.apps(); // rice start puts the links back on term/ — the color has to return; waits for the login to settle
        Rules.night();
        Rules.idle();
    }
    // what lives in the hypr config. It reloads it by itself: any hypr file saved (the links are live — both git pull and a branch
    // switch), hyprctl reload — and it returns the variables.lua defaults: demonshot borders, monitor, input, animations. We lay
    // ours on again. hyprctl eval doesn't send configreloaded — no loop. Night light and hypridle are their own processes, reload doesn't touch them
    function hypr() {
        Rules.monitor();
        Rules.input();
        Rules.motion();
        Theme.apply();
        Theme.workspaces();
    }
    Connections {
        target: Hyprland
        function onRawEvent(e) {
            if (e.name === "configreloaded") shell.hypr();
            else if (/^monitor(added|removed)/.test(e.name)) Rules.reread(); // a screen came or went — System → display shows it
        }
    }
    // the palette changed — theme, wallpaper, color from the wallpaper: repaint hypr, kitty and the apps. callLater — one repaint per turn
    Connections {
        target: Theme
        function onGreysChanged() { paint.restart(); }
    }
    // the theme or color changed (style, a new wallpaper) — windows, kitty, gtk and qt. After 300 ms: a new wallpaper's tones
    // don't arrive at once, and gtk shouldn't be poked twice
    Timer { id: paint; interval: 300; onTriggered: { Theme.apply(); Theme.apps(); } }
    // the wallpaper's tones (Theme.pick) — here, not in Theme: the lock loads it too, and the ready ones in glyph.json are enough
    // for it. Empty — the wallpaper copy didn't load (greys give 16 colors): the old tones stay. A new wallpaper starts on the first tone
    ColorQuantizer {
        source: Theme.url(Theme.wallSrc(Theme.state.wall))
        depth: 4
        rescaleSize: 64
        onColorsChanged: {
            if (!colors.length) return;
            const t = Theme.pick(colors);
            if (t.join() === Theme.state.tones.join()) return;
            Theme.state.tones = t;
            Theme.state.paintAt = 0;
        }
    }
    Connections {
        target: Theme.state
        function onRoundingChanged() { Theme.apply(); }
        function onWsCountChanged() { Theme.workspaces(); }
        function onWsWrapChanged() { Theme.workspaces(); }
        function onWsAnimChanged() { Theme.workspaces(); }
        function onWsBlurSpecialChanged() { Theme.workspaces(); }
        function onLiteChanged() { Theme.apply(); }
    }
    // ultra mode turns blur and shadows off/on over the settings — repaint the windows (Rules.setMode sets hertz and motion itself).
    // Game mode — the same plus animations
    Connections {
        target: Rules.store
        function onUltraChanged() { Theme.apply(); }
        function onGameChanged() { Rules.motion(); Theme.apply(); }
    }

    // tap Super — the launcher on release; any Super+<key> on the way sends an interrupt, and the launcher doesn't open
    property bool interrupted: false
    Shortcut {
        name: "launcher"
        description: "launcher (tap Super)"
        onReleased: {
            if (!shell.interrupted) launcher.toggle();
            shell.interrupted = false;
        }
    }
    Shortcut { name: "launcherArm"; description: "Super pressed — reset the interrupt"; onPressed: shell.interrupted = false }
    Shortcut { name: "launcherInterrupt"; description: "Super+<key> — don't open the launcher"; onPressed: shell.interrupted = true }
    // Super+Space (the altar in demonshot) — deck, the bottom dashboard: the launcher is on a Super tap anyway
    Shortcut { name: "altar"; description: "deck: bottom dashboard"; onPressed: deck.toggle() }
    Shortcut { name: "quick"; description: "quick settings"; onPressed: quick.toggle() }
    Shortcut { name: "ward"; description: "quick settings"; onPressed: quick.toggle() } // Super+N in demonshot — the same toggles
    // Super+I — system; the rice look (Prefs) — from there, «customize the rice»
    Shortcut { name: "settings"; description: "system: network, bluetooth, sound, display"; onPressed: system.get().toggle() }
    Shortcut { name: "power"; description: "power menu"; onPressed: shell.togglePower() }
    Shortcut { name: "shot"; description: "screenshot"; onPressed: shot.open() }
    Shortcut { name: "pact"; description: "vpn: clash verge"; onPressed: vpn.toggle() }
    Shortcut { name: "clip"; description: "clipboard"; onPressed: clip.get().toggle() }
    Shortcut { name: "charms"; description: "emoji, kaomoji, symbols"; onPressed: charms.get().toggle() }
    Shortcut { name: "wall"; description: "wallpapers"; onPressed: walls.get().toggle() }
    Shortcut { name: "overview"; description: "workspace overview"; onPressed: overview.get().toggle() }
    Shortcut { name: "game"; description: "game mode"; onPressed: Rules.store.game = !Rules.store.game }
    Shortcut { name: "lidClose"; description: "lid closed (System → idle)"; onPressed: Sys.lid(true) }
    Shortcut { name: "lidOpen"; description: "lid opened"; onPressed: Sys.lid(false) }

    component Shortcut: GlobalShortcut { appid: "shell" }
}
