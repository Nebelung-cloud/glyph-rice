import QtQuick
import qs
import qs.components

// the section list on the left of Prefs and System: Doto words, all one size so nothing jumps; the selected one white with a dot.
// The dot is red while the rail has the keys (↑↓ move here), grey once inside a page
Column {
    id: root

    property var model: []
    property int sel: 0
    property color dot: Theme.accent
    signal picked(int i)

    x: 72
    y: 120
    spacing: 16
    Repeater {
        model: root.model
        Row {
            id: word
            required property string modelData
            required property int index
            readonly property bool on: root.sel === index
            spacing: 14
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 12
                height: 12
                radius: 6
                color: word.on ? root.dot : "transparent"
            }
            Num {
                text: word.modelData
                font.pixelSize: 30
                color: word.on ? Theme.fg : Theme.mute
                Behavior on color { ColorAnimation { duration: Theme.t } }
            }
            TapHandler { onTapped: root.picked(word.index) }
        }
    }
}
