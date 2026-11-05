import QtQuick
import qs
import qs.components

// a number as a ring of dots: a fraction lit clockwise from 12, the head larger, Doto in the center. Drag around the circle, the wheel, ←→ — a step.
// While turning — its own v (the preview lives on it too), moved(v) goes out once: on release or after 250 ms of quiet.
// live — on every step (brightness). Its own dots, not Ring: its 8 ms per dot wave under the finger looks like lag
Column {
    id: root

    property real value
    property real from: 0
    property real to: 100
    property real step: 1
    property int n: 40
    property real size: 150
    property string label
    property string text: Math.round(v)
    property bool live: false
    property real v: value
    signal moved(real v)

    readonly property real dot: Math.max(5, size / 26)
    readonly property int lit: Math.round(n * (v - from) / (to - from))
    function put(x) {
        x = Math.max(from, Math.min(to, from + Math.round((x - from) / step) * step));
        if (x === v) return;
        v = x;
        if (live) moved(x);
        else wait.restart();
    }
    onValueChanged: if (!area.pressed && !wait.running) v = value
    Timer { id: wait; interval: 250; onTriggered: if (!area.pressed && root.v !== root.value) root.moved(root.v) }

    spacing: 12
    activeFocusOnTab: true
    Keys.onPressed: e => {
        if (e.key === Qt.Key_Left) put(v - step);
        else if (e.key === Qt.Key_Right) put(v + step);
        else return;
        e.accepted = true;
    }

    Item {
        width: root.size
        height: root.size

        Repeater {
            model: root.n
            Rectangle {
                required property int index
                readonly property real a: index / root.n * 2 * Math.PI - Math.PI / 2
                readonly property real d: index === root.lit - 1 ? root.dot * 1.7 : root.dot
                x: root.size / 2 + (root.size / 2 - root.dot) * Math.cos(a) - d / 2
                y: root.size / 2 + (root.size / 2 - root.dot) * Math.sin(a) - d / 2
                width: d
                height: d
                radius: d / 2
                color: index < root.lit ? Theme.fg : Theme.s3
            }
        }
        Num { anchors.centerIn: parent; text: root.text; font.pixelSize: Math.max(26, root.size * 0.3) }

        MouseArea {
            id: area
            anchors.fill: parent
            preventStealing: true
            property real last: -1
            property real acc: 0
            function at(x, y) {
                if (Math.hypot(x - width / 2, y - height / 2) < width * 0.2) return; // the center — not an angle
                const f = (Math.atan2(x - width / 2, height / 2 - y) / (2 * Math.PI) + 1) % 1;
                if (last >= 0 && Math.abs(f - last) > 0.5) return root.put(last > 0.5 ? root.to : root.from); // don't jump across 12
                last = f;
                root.put(root.from + f * (root.to - root.from));
            }
            onPressed: e => { last = -1; root.forceActiveFocus(); at(e.x, e.y); }
            onPositionChanged: e => at(e.x, e.y)
            onReleased: {
                wait.stop();
                if (root.v !== root.value) root.moved(root.v);
            }
            // the touchpad sends small deltas — accumulate up to a wheel click
            onWheel: w => {
                acc += w.angleDelta.y;
                while (Math.abs(acc) >= 120) {
                    root.put(root.v + Math.sign(acc) * root.step);
                    acc -= Math.sign(acc) * 120;
                }
            }
        }
    }
    // the label; in focus — a white chip
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: lab.implicitWidth + 24
        height: lab.implicitHeight + 12
        radius: height / 2
        color: root.activeFocus ? Theme.fg : "transparent"
        Lb { id: lab; anchors.centerIn: parent; text: root.label; color: root.activeFocus ? Theme.ink : Theme.grey }
    }
}
