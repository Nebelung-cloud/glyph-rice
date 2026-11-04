import QtQuick
import qs

// a ring of n LED dots, a fraction f lights up clockwise from 12. They light in a wave around the circle, 8 ms per dot
Item {
    id: root

    property int n: 44
    property real f: 1
    property real dot: 6
    property color on: Theme.fg
    property color off: Theme.s3
    readonly property int lit: Math.round(n * Math.max(0, Math.min(1, f)))

    Repeater {
        model: root.n

        Rectangle {
            required property int index
            readonly property real a: index / root.n * 2 * Math.PI - Math.PI / 2
            x: root.width / 2 * (1 + Math.cos(a)) - width / 2
            y: root.height / 2 * (1 + Math.sin(a)) - height / 2
            width: root.dot
            height: root.dot
            radius: root.dot / 2
            color: index < root.lit ? root.on : root.off
            Behavior on color { SequentialAnimation { PauseAnimation { duration: index * 8 } ColorAnimation { duration: 120 } } }
        }
    }
}
