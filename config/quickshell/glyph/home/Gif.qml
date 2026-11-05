import QtQuick
import qs
import qs.services

// the home cat tile's gif — Gifs.cur (services/Gifs: a folder of gifs, picked here or in settings → home). A grey dot matrix
// via the wallpaper shader, as before. A click — the next one, the wheel — pages through; the new one arrives in a shader wave from the click (from the center
// if picked in settings)
Item {
    id: root

    property bool playing: true
    property color bg // the tile's color: the gif's transparent parts go to it

    function step(d, at) {
        if (at) fx.origin = at;
        Gifs.step(d);
    }

    // like in components/Wall: one on screen, another on the way; the wave arrives — they swap roles, the old one unloads
    property bool flip: false
    readonly property AnimatedImage cur: flip ? b : a
    readonly property AnimatedImage next: flip ? a : b
    property string shown: "-" // nothing yet
    property string coming

    readonly property string want: Gifs.cur
    onWantChanged: change()
    readonly property bool ready: Gifs.ready
    onReadyChanged: change()
    Component.onCompleted: change()
    function change() {
        if (!ready) return;
        if (run.running) {
            run.stop();
            swap();
        }
        if (want === shown) return;
        coming = want;
        next.source = Gifs.url(want); // local files load synchronously
        if (shown === "-") swap();
        else run.restart();
    }
    function swap() {
        flip = !flip;
        shown = coming;
        fx.wave = 0;
        next.source = "";
    }
    NumberAnimation {
        id: run
        target: fx
        property: "wave"
        from: 0
        to: 1
        duration: 900
        easing.type: Easing.InOutSine
        onFinished: {
            root.swap();
            fx.origin = Qt.point(fx.width / 2, fx.height / 2);
        }
    }

    // the texture sources — the effect's siblings with opacity 0, see Wall
    AnimatedImage { id: a; anchors.fill: fx; opacity: 0; playing: root.playing && root.cur === a || run.running }
    AnimatedImage { id: b; anchors.fill: fx; opacity: 0; playing: root.playing && root.cur === b || run.running }

    ShaderEffect {
        // the wallpaper shader's effects stay off here
        readonly property real glass: 0
        readonly property real rib: 1
        readonly property real bend: 0
        readonly property real beat: 0
        id: fx
        anchors { fill: parent; margins: 12 }
        readonly property size size: Qt.size(width, height)
        property point origin: Qt.point(width / 2, height / 2)
        readonly property size cropA: Gifs.fit(root.cur)
        readonly property size cropB: Gifs.fit(root.next)
        readonly property color lo: Theme.light ? Theme.fg : Theme.bg
        readonly property color hi: Theme.light ? Theme.bg : Theme.fg
        readonly property color bg: root.bg
        readonly property real pitch: 6
        readonly property real dots: 1
        readonly property real mono: 1
        readonly property real bright: 1
        property real wave: 0
        readonly property real hasA: root.cur.status === Image.Ready ? 1 : 0
        readonly property real hasB: root.next.status === Image.Ready ? 1 : 0
        readonly property var srcA: root.cur
        readonly property var srcB: root.next
        fragmentShader: Qt.resolvedUrl("../components/shaders/wall.frag.qsb")
    }

    TapHandler { onTapped: p => root.step(1, root.mapToItem(fx, p.position)) }
    WheelHandler {
        property real acc: 0
        onWheel: w => {
            acc += w.angleDelta.y || w.angleDelta.x;
            while (Math.abs(acc) >= 120) {
                root.step(acc > 0 ? -1 : 1);
                acc -= Math.sign(acc) * 120;
            }
        }
    }
    HoverHandler { cursorShape: Gifs.list.length > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor }
}
