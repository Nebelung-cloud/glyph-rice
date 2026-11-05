import QtQuick
import qs

// a Doto word that grows when selected (section lists in System, Prefs, the power menu). Drawn once at the large size and
// scaled: animating font.pixelSize would re-lay-out and re-rasterise the glyphs every frame, the heaviest frames in the shell.
// The footprint follows the scale, so the column around it lays out exactly as with a real font size
Item {
    id: root
    property string text
    property bool on
    property real big: 80
    property real small: 38
    property color color: on ? Theme.fg : Theme.mute
    property real s: on ? 1 : small / big
    Behavior on s { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }

    implicitWidth: num.implicitWidth * s
    implicitHeight: num.implicitHeight * s

    Num {
        id: num
        text: root.text
        font.pixelSize: root.big
        scale: root.s
        transformOrigin: Item.TopLeft
        color: root.color
        Behavior on color { ColorAnimation { duration: Theme.t } }
    }
}
