import QtQuick
import qs
import qs.services

// гифка плитки-кота — Gifs.cur (services/Gifs: папка гифок, выбор здесь или в настройках → home). Серой матрицей точек
// через шейдер обоев, как и раньше. Клик — следующая, колесо — листать; новая приходит волной шейдера от клика (из центра,
// если выбрали в настройках)
Item {
    id: root

    property bool playing: true
    property color bg // цвет плитки: прозрачное в гифке — в него

    function step(d, at) {
        if (at) fx.origin = at;
        Gifs.step(d);
    }

    // как в components/Wall: одна на экране, другая в пути; волна дошла — меняются ролями, старая выгружается
    property bool flip: false
    readonly property AnimatedImage cur: flip ? b : a
    readonly property AnimatedImage next: flip ? a : b
    property string shown: "-" // ещё ничего
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
        next.source = Gifs.url(want); // локальные файлы грузятся синхронно
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

    // источники текстур — соседи эффекта с opacity 0, см. Wall
    AnimatedImage { id: a; anchors.fill: fx; opacity: 0; playing: root.playing && root.cur === a || run.running }
    AnimatedImage { id: b; anchors.fill: fx; opacity: 0; playing: root.playing && root.cur === b || run.running }

    ShaderEffect {
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
