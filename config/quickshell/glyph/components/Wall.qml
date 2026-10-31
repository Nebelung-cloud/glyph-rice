import QtQuick
import qs

// обои: картинка матрицей точек (look 0), серым фото в тон темы (1) или цветным (2), цветными точками (3) — см. shaders/wall.frag.
// Две картинки: та, что на экране, и приходящая. Пришла — волна от origin, в конце меняются ролями, старая выгружается.
// Пустой path — прозрачно: под обоями сетка и шар. opaque — картинка закрыла всё, то, что под ней, можно не рисовать
Item {
    id: root

    property string path
    property int look: Theme.state.wallLook
    property real pitch: Theme.state.wallPitch
    property real bright: Theme.state.wallBright / 100
    property point origin: Qt.point(width / 2, height / 2)
    property bool animate: true // false — смена сразу, без волны
    readonly property bool opaque: fx.hasA > 0 && !run.running

    property bool flip: false // кто на экране: false — ia, true — ib
    readonly property Image cur: flip ? ib : ia
    readonly property Image next: flip ? ia : ib

    function crop(img) {
        const ia = img.implicitWidth / Math.max(1, img.implicitHeight), sa = width / Math.max(1, height);
        return ia > sa ? Qt.size(sa / ia, 1) : Qt.size(1, ia / sa);
    }

    // ---- смена: shown — путь на экране, coming — в пути ----
    property string shown: ""
    property string coming: ""
    property bool pending: false
    readonly property bool sized: width > 0 && height > 0 // до размера не грузим: sourceSize 0 — декодировать целиком

    onSizedChanged: change()
    onPathChanged: change()
    function change() {
        if (!sized) return;
        if (run.running) { // листают быстрее волны — текущую досрочно в конец
            run.stop();
            swap();
        }
        if (path === shown) {
            pending = false;
            next.source = "";
            return;
        }
        coming = path;
        pending = true;
        next.source = Theme.url(path);
        check();
    }
    function check() {
        if (!pending || next.status === Image.Loading) return;
        pending = false; // Error — уйдёт в прозрачное, как пустой
        if (animate) run.restart();
        else swap();
    }
    function swap() {
        flip = !flip;
        shown = coming;
        fx.wave = 0;
        next.source = ""; // теперь это старая
    }

    NumberAnimation { id: run; target: fx; property: "wave"; from: 0; to: 1; duration: 1500; easing.type: Easing.InOutSine; onFinished: root.swap() }

    // источники текстур — соседи эффекта, не дети: эффект без картинок прячем, а невидимому Image сцена не обновляет
    // текстуру. Поэтому и opacity 0, а не visible: false. sourceSize — в логических пикселях: на DPR Qt умножает сам
    Image { id: ia; opacity: 0; asynchronous: true; cache: false; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(root.width, root.height); onStatusChanged: if (root.next === ia) root.check() }
    Image { id: ib; opacity: 0; asynchronous: true; cache: false; fillMode: Image.PreserveAspectCrop; sourceSize: ia.sourceSize; onStatusChanged: if (root.next === ib) root.check() }

    ShaderEffect {
        id: fx
        anchors.fill: parent
        visible: hasA > 0 || hasB > 0 || run.running // нечего рисовать — нет и полноэкранного прохода

        // ---- uniforms ----
        readonly property size size: Qt.size(width, height)
        readonly property point origin: root.origin
        readonly property var srcA: root.cur
        readonly property var srcB: root.next
        readonly property size cropA: root.crop(root.cur)
        readonly property size cropB: root.crop(root.next)
        readonly property real hasA: root.cur.status === Image.Ready ? 1 : 0
        readonly property real hasB: root.next.status === Image.Ready ? 1 : 0
        readonly property color lo: Theme.light ? Theme.fg : Theme.bg
        readonly property color hi: Theme.light ? Theme.bg : Theme.fg
        readonly property color bg: Theme.bg
        readonly property real pitch: root.pitch
        readonly property real bright: root.bright
        property real dots: root.look === 0 || root.look === 3 ? 1 : 0 // 3 — color dots
        property real mono: root.look < 2 ? 1 : 0
        property real wave: 0
        Behavior on dots { NumberAnimation { duration: 700; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
        Behavior on mono { NumberAnimation { duration: 700 } }

        fragmentShader: Qt.resolvedUrl("shaders/wall.frag.qsb")
    }
}
