import QtQuick
import qs
import qs.components

// the section list on the left of Prefs and System, as a drum: the selected word always sits at the screen's vertical center beside a
// fixed dot, the list glides past it; further from the center — smaller and fainter. One animated `pos` drives every word, so
// they move together. The dot is red while the rail has the keys (↑↓ move here), grey once inside a page
Item {
    id: root

    property var model: []
    property int sel: 0
    property color dot: Theme.accent
    signal picked(int i)

    property real pos: sel
    Behavior on pos { NumberAnimation { duration: Theme.t * 1.5; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
    readonly property real gap: 62 // between word centers

    x: 72
    width: 320
    height: parent.height

    Rectangle {
        y: root.height / 2 - 6
        width: 12
        height: 12
        radius: 6
        color: root.dot
        Behavior on color { ColorAnimation { duration: Theme.t } }
    }

    Repeater {
        model: root.model
        Num {
            id: word
            required property string modelData
            required property int index
            readonly property real d: index - root.pos // rows from the center, fractional while gliding
            x: 30
            y: root.height / 2 + d * root.gap - height / 2
            text: modelData
            font.pixelSize: 44
            transformOrigin: Item.Left
            scale: Math.max(0.55, 1 - Math.abs(d) * 0.16)
            opacity: Math.max(0, 1 - Math.abs(d) * 0.18) // gone by ~5 rows out: clear of the hints at the bottom
            color: Math.abs(d) < 0.5 ? Theme.fg : Theme.mute
            Behavior on color { ColorAnimation { duration: Theme.t } }
            TapHandler { onTapped: root.picked(word.index) }
        }
    }
}
