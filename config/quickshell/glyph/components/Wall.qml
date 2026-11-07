import QtQuick
import qs

// обои: картинка матрицей точек (look 0), серым фото в тон темы (1) или цветным (2) — см. shaders/wall.frag.
// Под волнами — база: та картинка, что уже стоит. Каждая смена — свой слой-волна: круг от origin расходится поверх базы
// и несёт свою картинку. Волны не обрывают друг друга, поэтому сменили пять обоев подряд — пять кругов идут одновременно,
// сколько угодно. Дошла волна до края — её картинка становится базой, слой убирается.
// Пустой path — прозрачно: под обоями сетка и шар. opaque — картинка закрыла всё, то, что под ней, можно не рисовать
Item {
    id: root

    property string path
    property int look: Theme.state.wallLook
    property real pitch: Theme.state.wallPitch
    property real bright: Theme.state.wallBright / 100
    property point origin: Qt.point(width / 2, height / 2)
    property bool animate: true // false — смена сразу, без волны
    // картинка закрыла всё и волн нет — сетку и шар под обоями можно не рисовать
    readonly property bool opaque: base.status === Image.Ready && trans.count === 0

    property string target: "" // последний path, на который уже пустили волну (или поставили сразу)
    property string basePath: "" // что лежит в базе под волнами
    // очередь волн: { src, p, ox, oy }. Порядок — порядок появления: нулевая — самая старая
    ListModel { id: trans }

    readonly property bool sized: width > 0 && height > 0 // до размера не грузим: sourceSize 0 — декодировать целиком

    function crop(img) {
        const ia = img.implicitWidth / Math.max(1, img.implicitHeight), sa = width / Math.max(1, height);
        return ia > sa ? Qt.size(sa / ia, 1) : Qt.size(1, ia / sa);
    }

    onSizedChanged: change()
    onPathChanged: change()
    function change() {
        if (!sized) return;
        if (path === target) return; // ту же картинку второй раз не гоняем (в т.ч. при ресайзе)
        target = path;
        // NOTHING и режим без волны — сразу в базу, всё, что летело, вон. Пустую картинку волной не нарисовать:
        // слой-волна умеет только класть новое поверх базы, а стереть базу под собой не может
        if (path === "" || !animate) {
            trans.clear();
            basePath = path;
            base.source = Theme.url(path);
            return;
        }
        trans.append({ src: Theme.url(path), p: path, ox: origin.x, oy: origin.y });
    }

    // база готова — можно убрать досчитавшую волну и пустить следующую.
    // Готовность смотрим у самого делегата (itemAt(0)), а не в JS-объекте: так переживает и переиндексацию
    function pump() {
        while (trans.count > 0) {
            const w = waves.itemAt(0);
            if (!w || !w.finished) return;
            const t = trans.get(0);
            const src = Theme.url(t.p);
            if (String(base.source) !== src) { // грузим в базу под волной; как будет готово — onStatusChanged вернётся сюда
                base.source = src;
                return;
            }
            if (base.status === Image.Loading) return;
            basePath = t.p;
            trans.remove(0);
        }
    }

    Image {
        id: base
        opacity: 0
        asynchronous: true
        cache: false
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(root.width, root.height)
        onStatusChanged: root.pump()
    }

    // база: одна картинка, без волны
    ShaderEffect {
        id: baseFx
        anchors.fill: parent
        visible: hasA > 0

        // ---- uniforms ----
        readonly property size size: Qt.size(width, height)
        readonly property point origin: Qt.point(width / 2, height / 2)
        readonly property var srcA: base
        readonly property var srcB: base
        readonly property size cropA: root.crop(base)
        readonly property size cropB: root.crop(base)
        readonly property real hasA: base.status === Image.Ready ? 1 : 0
        readonly property real hasB: 0
        readonly property color lo: Theme.light ? Theme.fg : Theme.bg
        readonly property color hi: Theme.light ? Theme.bg : Theme.fg
        readonly property color bg: Theme.bg
        readonly property real pitch: root.pitch
        readonly property real bright: root.bright
        property real dots: root.look === 0 ? 1 : 0
        property real mono: root.look < 2 ? 1 : 0
        property real wave: 0
        property real overlay: 0
        Behavior on dots { NumberAnimation { duration: 700; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
        Behavior on mono { NumberAnimation { duration: 700 } }

        fragmentShader: Qt.resolvedUrl("shaders/wall.frag.qsb")
    }

    // волны: каждая поверх предыдущих, поэтому новая картинка в круге перекрывает старые
    Repeater {
        id: waves
        model: trans
        delegate: Item {
            id: wv
            required property int index
            required property string src
            required property real ox
            required property real oy
            anchors.fill: parent

            property real progress: 0
            property bool started: false
            property bool finished: false

            function maybeStart() {
                if (started) return;
                if (im.status === Image.Ready || im.status === Image.Error || wv.src === "") {
                    started = true;
                    run.start();
                }
            }
            Component.onCompleted: maybeStart()

            Image {
                id: im
                opacity: 0
                asynchronous: true
                cache: false
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(root.width, root.height)
                source: wv.src
                onStatusChanged: wv.maybeStart()
            }

            NumberAnimation {
                id: run
                target: wv
                property: "progress"
                from: 0
                to: 1
                duration: 1500
                easing.type: Easing.InOutSine
                onFinished: { wv.finished = true; root.pump() }
            }

            ShaderEffect {
                anchors.fill: parent
                visible: wv.progress > 0 && hasB > 0

                // ---- uniforms ----
                readonly property size size: Qt.size(width, height)
                readonly property point origin: Qt.point(wv.ox, wv.oy)
                readonly property var srcA: im
                readonly property var srcB: im
                readonly property size cropA: root.crop(im)
                readonly property size cropB: root.crop(im)
                readonly property real hasA: 0
                readonly property real hasB: im.status === Image.Ready ? 1 : 0
                readonly property color lo: Theme.light ? Theme.fg : Theme.bg
                readonly property color hi: Theme.light ? Theme.bg : Theme.fg
                readonly property color bg: Theme.bg
                readonly property real pitch: root.pitch
                readonly property real bright: root.bright
                property real dots: root.look === 0 ? 1 : 0
                property real mono: root.look < 2 ? 1 : 0
                property real wave: wv.progress
                property real overlay: 1

                fragmentShader: Qt.resolvedUrl("shaders/wall.frag.qsb")
            }
        }
    }
}