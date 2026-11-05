import QtQuick
import qs
import qs.components

// a list row: a circle with an icon (on — white, connecting — breathes), a name, a label. The selected one — an s2 underlay.
// Click, ↵, space — hit
Rectangle {
    id: root
    property string icon
    property string title
    property string sub
    property bool on
    property bool picked
    property bool busy
    signal hit

    width: parent.width
    height: 64
    radius: Theme.corner(32)
    color: picked ? Theme.s2 : hov.hovered ? Theme.s1 : "transparent"
    border { width: activeFocus ? 1 : 0; color: Theme.fg }
    activeFocusOnTab: true
    Keys.onPressed: e => {
        if (e.key !== Qt.Key_Return && e.key !== Qt.Key_Enter && e.key !== Qt.Key_Space) return;
        if (!e.isAutoRepeat) root.hit(); // holding the key mustn't repeat the action
        e.accepted = true;
    }

    Rectangle {
        id: ic
        x: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 48
        height: 48
        radius: 24
        color: root.on ? Theme.fg : Theme.s3
        Icon {
            anchors.centerIn: parent
            text: root.icon
            font.pixelSize: 20
            color: root.on ? Theme.ink : Theme.fg
            SequentialAnimation on opacity {
                running: root.busy
                loops: Animation.Infinite
                onRunningChanged: if (!running) parent.opacity = 1
                NumberAnimation { to: 0.25; duration: 450 }
                NumberAnimation { to: 1; duration: 450 }
            }
        }
    }
    Column {
        anchors { left: ic.right; leftMargin: 16; right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
        Text { width: parent.width; elide: Text.ElideRight; text: root.title; font { family: Theme.ui; pixelSize: 17; weight: Font.DemiBold } color: Theme.fg }
        Lb { width: parent.width; elide: Text.ElideRight; px: 10; text: root.sub; visible: !!text }
    }
    HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: { root.forceActiveFocus(); root.hit(); } }
}
