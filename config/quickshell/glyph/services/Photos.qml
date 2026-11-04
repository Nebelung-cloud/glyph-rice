pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs

// shots for the home photo widget: the first five images of the folder (by name), like the five photos in Nothing's widget. The folder —
// Theme.state.photoDir, empty — ~/Pictures/glyph. You drop files in with a file manager — the list updates on refresh()
// (home calls it when it shows) and once a minute while someone holds active
Singleton {
    id: root

    readonly property string dir: Theme.state.photoDir || Quickshell.env("HOME") + "/Pictures/glyph"
    readonly property int most: 5
    property var list: []
    property bool active: false

    function refresh() { if (!ls.running) ls.running = true; }
    onDirChanged: refresh()
    Component.onCompleted: refresh()
    Timer { running: root.active; interval: 60000; repeat: true; onTriggered: root.refresh() }

    Process {
        id: ls
        command: ["bash", "-c", 'shopt -s nullglob nocaseglob; printf "%s\\n" "$1"/*.{jpg,jpeg,png,webp} | sort | head -n "$2"', "bash", root.dir, String(root.most)]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n").filter(Boolean);
                if (l.join("\n") !== root.list.join("\n")) root.list = l; // unchanged — leave it: the widget would start over
            }
        }
    }
}
