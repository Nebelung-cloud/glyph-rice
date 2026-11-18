import QtQuick
import qs

// on/off as a small knob track, one size everywhere: never reads as a picked Pick segment (those are wide white pills with a word).
// Click, space, ↵ — flip; ← off, → on
Rectangle {
    id: root

    property bool on
    signal flip

    width: 56
    height: 30
    radius: Theme.corner(15)
    color: on ? Theme.fg : Theme.s2
    border { width: activeFocus || !on ? 1 : 0; color: activeFocus ? Theme.fg : Theme.s3 }
    Behavior on color { ColorAnimation { duration: Theme.t } }
    activeFocusOnTab: true
    Keys.onPressed: e => {
        if (e.key === Qt.Key_Space || e.key === Qt.Key_Return || e.key === Qt.Key_Enter) flip();
        else if (e.key === Qt.Key_Left || e.key === Qt.Key_Right) { if (on !== (e.key === Qt.Key_Right)) flip(); }
        else return;
        e.accepted = true;
    }

    Rectangle {
        x: root.on ? root.width - width - 5 : 5
        anchors.verticalCenter: parent.verticalCenter
        width: 20
        height: 20
        radius: 10
        color: root.on ? Theme.ink : Theme.mute
        Behavior on x { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
    }
    TapHandler { onTapped: root.flip() }
}
