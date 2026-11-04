pragma Singleton

import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import qs
import qs.settings

// automatic game mode. A fullscreen game window (steam_app_*, gamescope, or a window that says its content is a game) turns on game
// mode (Rules.store.game) and do not disturb. Gone for 5 s — alt-enter, a loading screen — both go back to what they were. What they
// were is kept in Theme.state.gameAuto, so a shell restart mid-game still puts them back. Theme.state.autoGame false — off.
// From Isaqdn03/glyph-rice
Singleton {
    id: root

    property bool playing: false // a game is fullscreen right now
    readonly property bool on: Theme.state.gameAuto !== null && Theme.state.gameAuto !== undefined

    function isGame(c) {
        return (c.fullscreen ?? 0) > 0 && (/^(steam_app_(default|\d+)|gamescope)$/.test(c.class ?? "") || c.contentType === "game");
    }

    Process {
        id: scan
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let list;
                try { list = JSON.parse(text); } catch (e) { return; }
                root.playing = list.some(c => root.isGame(c));
            }
        }
    }
    Timer { id: soon; interval: 400; onTriggered: scan.running = true }
    Connections {
        target: Hyprland
        function onRawEvent(e) {
            if (["fullscreen", "openwindow", "closewindow", "movewindowv2", "changefloatingmode"].includes(e.name)) soon.restart();
        }
    }
    Component.onCompleted: scan.running = true

    // in: at once. Out: after 5 s still without a game
    onPlayingChanged: playing ? enter() : leave.restart()
    Timer { id: leave; interval: 5000; onTriggered: if (!root.playing) root.exit() }

    function enter() {
        leave.stop();
        const s = Theme.state;
        if (s.autoGame === false || root.on) return;
        s.gameAuto = { game: Rules.store.game, dnd: s.dnd };
        Rules.store.game = true;
        if (Rules.store.gameDnd) s.dnd = true;
    }
    function exit() {
        const s = Theme.state, was = s.gameAuto;
        if (!was) return;
        s.gameAuto = null;
        Rules.store.game = was.game;
        s.dnd = was.dnd;
    }
}
