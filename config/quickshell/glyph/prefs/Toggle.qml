import QtQuick
import qs
import qs.components

// a toggle: a pill, off — a grey dot on the left, the label to its right; on — the white slides out the full length, a dot at the right
// edge, the label moves left and turns black. Click, space, ↵ — toggle; ← off, → on
Rectangle {
    id: root

    property bool on
    property string text
    signal flip

    width: Math.max(170, lab.implicitWidth + 96)
    height: 64
    radius: Theme.corner(32)
    color: Theme.s2
    border { width: activeFocus ? 1 : 0; color: Theme.fg }
    activeFocusOnTab: true
    Keys.onPressed: e => {
        if (e.key === Qt.Key_Space || e.key === Qt.Key_Return || e.key === Qt.Key_Enter) flip();
        else if (e.key === Qt.Key_Left || e.key === Qt.Key_Right) { if (on !== (e.key === Qt.Key_Right)) flip(); }
        else return;
        e.accepted = true;
    }

    Rectangle {
        x: 6
        y: 6
        width: root.on ? root.width - 12 : height
        height: root.height - 12
        radius: Theme.corner(height / 2)
        color: root.on ? Theme.fg : Theme.mute
        Behavior on width { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
        Behavior on color { ColorAnimation { duration: Theme.t } }
        Rectangle {
            anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
            width: 12
            height: 12
            radius: 6
            color: root.on ? Theme.ink : Theme.s2
        }
    }
    Lb {
        id: lab
        x: root.on ? 30 : 76 // on — the dot on the right, the label makes room for it
        Behavior on x { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        color: root.on ? Theme.ink : root.activeFocus ? Theme.fg : Theme.grey
        Behavior on color { ColorAnimation { duration: Theme.t } }
    }
    TapHandler { onTapped: root.flip() }
}
