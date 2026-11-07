import QtQuick
import qs
import qs.services

// гифка серой матрицей точек через шейдер обоев — плитка-кот дома без волны (миниатюры в настройках)
Item {
    id: root

    property string path // как в Gifs.list: "" — встроенный кот
    property color bg: Theme.s1
    property real pitch: 3
    property bool playing: true

    // источник текстуры — сосед эффекта с opacity 0, см. Wall
    AnimatedImage { id: img; anchors.fill: fx; opacity: 0; source: Gifs.url(root.path); playing: root.playing }
    ShaderEffect {
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
