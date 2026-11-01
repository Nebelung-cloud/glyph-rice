import QtQuick
import qs
import qs.components

// выбор одного из нескольких: пилюля, слева подпись, белый сегмент переезжает на выбранное. ←→ или клик.
// cur -1 (значения нет среди opts) — сегмента нет
Rectangle {
    id: root

    property string label
    property var opts: []
    property int cur: -1
    signal picked(int i)

    property real seg: 104
    width: head.width + opts.length * seg + 8
    height: 64
    radius: Theme.corner(32)
    color: Theme.s2
    border { width: activeFocus ? 1 : 0; color: Theme.fg }
    activeFocusOnTab: true
    Keys.onPressed: e => {
        const n = opts.length;
        if (e.key === Qt.Key_Left) picked((Math.max(cur, 0) + n - 1) % n);
        else if (e.key === Qt.Key_Right || e.key === Qt.Key_Space) picked((cur + 1) % n);
        else return;
        e.accepted = true;
    }

    Lb {
        id: head
        anchors.verticalCenter: parent.verticalCenter
        leftPadding: 28
        rightPadding: 14
        text: root.label
        color: root.activeFocus ? Theme.fg : Theme.grey
    }
    Rectangle {
        visible: root.cur >= 0
        x: head.width + 4 + root.cur * root.seg
        y: 6
        width: root.seg
        height: root.height - 12
        radius: height / 2
        color: Theme.fg
        Behavior on x { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
    }
    Repeater {
        model: root.opts
        Lb {
            required property string modelData
            required property int index
            x: head.width + 4 + index * root.seg
            width: root.seg
            height: root.height
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: modelData
            color: index === root.cur ? Theme.ink : Theme.grey
            TapHandler { onTapped: root.picked(parent.index) }
        }
    }
}
