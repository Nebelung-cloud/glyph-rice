import QtQuick
import qs
import qs.components

// a tray of kinds: a circle for each. White — placed, grey — placed but doesn't fit (dim), dark — absent. Click or ↵ — place/remove;
// ←→ — the cursor (a ring around), while the tray is in focus. widths — the width in cells, as dots under the name.
// Doesn't fit in 1100 (the page starts at x 800) — wraps, rows evenly: 12 kinds — 6 + 6, not 11 + 1
Grid {
    id: root

    columns: Math.ceil(ids.length / Math.ceil(ids.length * 100 / 1100))
    rowSpacing: 20

    property var ids: []
    property var icons: ({})
    property var used: []
    property var dim: []
    property var widths: null
    property int cur: 0
    signal toggled(string key)

    activeFocusOnTab: true
    Keys.onPressed: e => {
        const n = ids.length;
        if (e.key === Qt.Key_Left) cur = (cur + n - 1) % n;
        else if (e.key === Qt.Key_Right) cur = (cur + 1) % n;
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) toggled(ids[cur]);
        else return;
        e.accepted = true;
    }

    Repeater {
        model: root.ids

        Column {
            id: it
            required property string modelData
            required property int index
            readonly property bool on: root.used.includes(modelData)
            width: 100
            spacing: 8

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 78
                height: 78
                radius: 39
                color: "transparent"
                border { width: root.activeFocus && root.cur === it.index ? 1 : 0; color: Theme.fg }
                Rectangle {
                    anchors.centerIn: parent
                    width: 64
                    height: 64
                    radius: 32
                    color: !it.on ? Theme.s2 : root.dim.includes(it.modelData) ? Theme.grey : Theme.fg
                    Behavior on color { ColorAnimation { duration: Theme.t } }
                    Icon { anchors.centerIn: parent; text: root.icons[it.modelData] ?? ""; font.pixelSize: 26; color: it.on ? Theme.ink : Theme.grey }
                }
                TapHandler {
                    onTapped: {
                        root.cur = it.index;
                        root.toggled(it.modelData);
                    }
                }
            }
            Lb { anchors.horizontalCenter: parent.horizontalCenter; text: it.modelData; px: 10; color: it.on ? Theme.fg : Theme.grey }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4
                Repeater {
                    model: root.widths?.[it.modelData] ?? 0
                    Rectangle { width: 5; height: 5; radius: 2.5; color: Theme.mute }
                }
            }
        }
    }
}
