import QtQuick
import qs
import qs.components

// a slider like in quick settings: the filled part — a white pill with an icon, the empty part — dots. A click on the icon — iconHit (sound: mute).
// ←→ — a 5% step. fmt — the label on the right
Rectangle {
    id: sl
    property real value
    property string icon
    property bool muted
    property var fmt: v => Math.round(v * 100)
    signal moved(real v)
    signal iconHit
    readonly property real shown: area.pressed ? area.v : value

    width: 480
    height: 54
    radius: Theme.corner(27)
    color: Theme.s2
    border { width: activeFocus ? 1 : 0; color: Theme.fg }
    activeFocusOnTab: true
    Keys.onPressed: e => {
        const d = e.key === Qt.Key_Left ? -0.05 : e.key === Qt.Key_Right ? 0.05 : 0;
        if (!d) return;
        sl.moved(Math.max(0, Math.min(1, sl.value + d)));
        e.accepted = true;
    }

    Row {
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 11 - 2.8
        Repeater {
            model: Math.max(0, Math.floor((sl.width - 20) / 11) + 1)
            Rectangle { width: 2.8; height: 2.8; radius: 1.4; color: Theme.mute }
        }
    }
    Rectangle {
        width: Math.max(height, sl.width * sl.shown)
        height: parent.height
        radius: Theme.corner(27)
        color: sl.muted ? Theme.mute : Theme.fg
        Behavior on color { ColorAnimation { duration: Theme.t } }
        Icon { x: 18; anchors.verticalCenter: parent.verticalCenter; text: sl.icon; font.pixelSize: 21; color: Theme.ink }
    }
    Rectangle {
        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
        width: val.width + 16
        height: val.height + 8
        radius: Theme.corner(10)
        color: Theme.s2
        Lb { id: val; anchors.centerIn: parent; text: sl.fmt(sl.shown) }
    }
    MouseArea {
        id: area
        property real v
        anchors.fill: parent
        preventStealing: true
        function set(x) { v = Math.max(0, Math.min(1, x / width)); sl.moved(v); }
        onPressed: e => { sl.forceActiveFocus(); set(e.x); }
        onPositionChanged: e => set(e.x)
    }
    // the icon on top — its own button
    MouseArea { width: 54; height: parent.height; cursorShape: Qt.PointingHandCursor; onClicked: sl.iconHit() }
}
