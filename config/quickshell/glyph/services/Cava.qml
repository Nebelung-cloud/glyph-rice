pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs

// cava in the background while someone is watching (active): 8 mono bars 0…1, from bass to highs (the count — in cava.conf)
Singleton {
    id: root

    property bool active: false
    property var bars: Array(8).fill(0)

    // the wallpaper's beat — how far the bass jumps above its last ~second, fast rise, slow fall: rests near 0, kicks reach .5–.9. Runs only if
    // asked for (Theme.state.wallPulse, off by default) and music plays. From Isaqdn03/glyph-rice
    readonly property bool beatOn: Theme.state.wallPulse && !Theme.state.lite && Theme.state.wall !== "" && Media.playing
    property real bass: 0
    property real slow: 0.5
    onBarsChanged: {
        const b = Math.min(1, ((bars[0] ?? 0) + (bars[1] ?? 0)) / 2);
        // a cava that can't open its input prints no numbers: NaN would stick in slow for good and paint the wallpaper black
        if (!isFinite(b)) return;
        slow = slow * 0.95 + b * 0.05;
        const t = Math.max(0, Math.min(1, (b - slow) * 5));
        bass = t > bass ? t : bass * 0.8 + t * 0.2;
    }

    Process {
        running: root.active || root.beatOn
        command: ["cava", "-p", Qt.resolvedUrl("cava.conf").toString().replace("file://", "")]
        stdout: SplitParser {
            onRead: line => root.bars = line.split(";").filter(s => s !== "").map(v => v / 100)
        }
        onRunningChanged: if (!running) { root.bars = Array(8).fill(0); root.bass = 0; }
    }
}
