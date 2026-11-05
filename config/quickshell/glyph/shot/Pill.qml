import QtQuick
import qs

// a pill over the frame: Surface with a Raised outline, the content side by side in the center. A click on it doesn't go to the frame under it
Rectangle {
    default property alias content: row.data
    property alias spacing: row.spacing
    property real pad: 10

    width: row.width + pad * 2
    height: 56
    radius: height / 2
    color: Theme.s1
    border { width: 1; color: Theme.s2 }

    MouseArea { anchors.fill: parent }
    Row { id: row; anchors.centerIn: parent }
}
