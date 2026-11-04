import QtQuick
import QtQuick.Shapes
import qs

// the track cover as dots in a circle; no cover — a conic gradient from the concept
Item {
    id: root

    property string url
    property real step: 6

    // the gradient — along the palette's ladder from the dark end to the light one (the stops — as in the concept: #FFF #444 #DDD #111 #BBB),
    // so it follows the theme and the color from the wallpaper
    readonly property color lo: Theme.light ? Theme.fg : Theme.bg
    readonly property color hi: Theme.light ? Theme.s1 : Theme.fg
    function at(k) { return Qt.rgba(lo.r + (hi.r - lo.r) * k, lo.g + (hi.g - lo.g) * k, lo.b + (hi.b - lo.b) * k, 1); }

    layer.enabled: true
    layer.effect: Dm { step: root.step; circle: true }

    Shape {
        anchors.fill: parent
        visible: img.status !== Image.Ready
        ShapePath {
            strokeWidth: -1
            fillGradient: ConicalGradient {
                centerX: root.width / 2; centerY: root.height / 2; angle: 50
                GradientStop { position: 0; color: root.at(1) }
                GradientStop { position: 0.2; color: root.at(0.27) }
                GradientStop { position: 0.4; color: root.at(0.87) }
                GradientStop { position: 0.6; color: root.at(0.07) }
                GradientStop { position: 0.8; color: root.at(0.73) }
                GradientStop { position: 1; color: root.at(1) }
            }
            PathRectangle { width: root.width; height: root.height }
        }
    }
    Image {
        id: img
        anchors.fill: parent
        source: root.url
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(256, 256)
        asynchronous: true
    }
}
