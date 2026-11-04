import QtQuick
import qs
import qs.components

// the overview's round −/+ button: a 54 pill, disabled — faded
Rectangle {
    id: st
    property string icon
    property bool on: true
    signal hit
    anchors.verticalCenter: parent.verticalCenter
    width: 54
    height: 54
    radius: 27
    color: Theme.s2
    opacity: on ? 1 : 0.35
    Icon { anchors.centerIn: parent; text: st.icon; font.pixelSize: 22 }
    TapHandler { onTapped: if (st.on) st.hit() }
    HoverHandler { cursorShape: st.on ? Qt.PointingHandCursor : Qt.ArrowCursor }
}
