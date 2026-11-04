import QtQuick
import qs
import qs.components

// a chip, like the modes in the launcher: on — a white pill and black text, off — grey text
Rectangle {
    property alias text: lb.text
    property bool on
    signal clicked

    width: lb.width + 32
    height: 36
    radius: Theme.corner(18)
    color: on ? Theme.fg : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.t } }

    Lb { id: lb; anchors.centerIn: parent; px: 11; color: parent.on ? Theme.ink : Theme.grey }
    TapHandler { onTapped: parent.clicked() }
    HoverHandler { cursorShape: Qt.PointingHandCursor }
}
