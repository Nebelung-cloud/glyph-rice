import QtQuick
import qs

// a segmented scale — Glyph strips: a fraction f is lit. vertical — bottom to top. from — the segment it lights from (a running light
// for tasks without a percentage)
Grid {
    id: root

    property int n: 12
    property real f: 0
    property int from: 0
    property bool vertical: false
    property color on: Theme.fg
    property color off: Theme.s3
    readonly property int lit: Math.round(n * Math.max(0, Math.min(1, f)))

    columns: vertical ? 1 : n
    spacing: 4

    Repeater {
        model: root.n

        Rectangle {
            required property int index
            readonly property int k: root.vertical ? root.n - 1 - index : index
            width: root.vertical ? root.width : (root.width - (root.n - 1) * root.spacing) / root.n
            height: root.vertical ? (root.height - (root.n - 1) * root.spacing) / root.n : root.height
            radius: Math.min(width, height) / 2
            color: k >= root.from && k < root.from + root.lit ? root.on : root.off
        }
    }
}
