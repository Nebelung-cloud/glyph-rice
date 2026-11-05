import QtQuick
import qs
import qs.services

// a gif as a grey dot matrix via the wallpaper shader — the home cat tile without the wave (thumbnails in settings)
Item {
    id: root

    property string path // like in Gifs.list: "" — the built-in cat
    property color bg: Theme.s1
    property real pitch: 3
    property bool playing: true

    // the texture source — the effect's sibling with opacity 0, see Wall
    AnimatedImage { id: img; anchors.fill: fx; opacity: 0; source: Gifs.url(root.path); playing: root.playing }
    ShaderEffect {
        // the wallpaper shader's effects stay off here
        readonly property real glass: 0
        readonly property real rib: 1
        readonly property real bend: 0
        readonly property real beat: 0
        id: fx
        anchors.fill: parent
        readonly property size size: Qt.size(width, height)
        readonly property point origin: Qt.point(0, 0)
        readonly property size cropA: Gifs.fit(img)
        readonly property size cropB: cropA
        readonly property color lo: Theme.light ? Theme.fg : Theme.bg
        readonly property color hi: Theme.light ? Theme.bg : Theme.fg
        readonly property color bg: root.bg
        readonly property real pitch: root.pitch
        readonly property real dots: 1
        readonly property real mono: 1
        readonly property real bright: 1
        readonly property real wave: 0
        readonly property real hasA: img.status === Image.Ready ? 1 : 0
        readonly property real hasB: 0
        readonly property var srcA: img
        readonly property var srcB: img
        fragmentShader: Qt.resolvedUrl("shaders/wall.frag.qsb")
    }
}
