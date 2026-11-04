import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs
import qs.components

// Glyph: края экрана как светодиоды на спинке, вместо OSD и попапов посреди экрана.
// Сверху — вспышка на уведомление (у критических красная) и «остров» с ним, справа — громкость/яркость снизу вверх,
// снизу — прогресс долгих задач (уведомления с hint value) или фокус-таймера (Focus). Гаснут через 3 с
Scope {
    id: root

    // вспышка и остров — под баром, если он сверху и есть на экране в фокусе (там они и встают)
    readonly property bool underBar: Theme.state.barAt === "top" && Theme.scr(Hyprland.focusedMonitor?.name, "bar")

    // ---- справа: громкость и яркость ----
    property string kind: "vol"
    property real value: 0
    property bool armed: false // первые значения при старте не показываем
    Timer { running: true; interval: 1500; onTriggered: root.armed = true }
    function level(k, v) {
        if (!armed || !Theme.state.edges) return;
        kind = k;
        value = v;
        side.shown = true;
        sideT.restart();
    }
    Connections {
        target: Sys.sink?.audio ?? null
        function onVolumeChanged() { root.level("vol", Sys.muted ? 0 : Sys.vol); }
        function onMutedChanged() { root.level("vol", Sys.muted ? 0 : Sys.vol); }
    }
    Connections {
        target: Sys
        function onBriChanged() { root.level("bri", Sys.bri); }
    }
    Timer { id: sideT; interval: 3000; onTriggered: side.shown = false }

    // ---- сверху: новое уведомление — вспышка полосы и плашка в стопку острова ----
    property var note: null // последнее, для вспышки
    // стопка: снимки полей (уведомление могут закрыть, пока плашка уходит — объекта уже не будет), сам объект — в refs ради действия
    ListModel { id: stack }
    property var refs: ({})
    property int seq: 0
    readonly property int most: 4
    // плашка в стопку: c — { app, summary, body, icon (тема иконок), glyph (nerd font), crit }; ref — уведомление, ради действия
    function push(c, ref) {
        root.note = { urgency: c.crit ? NotificationUrgency.Critical : NotificationUrgency.Normal };
        noteT.restart();
        const key = String(++root.seq);
        if (ref) root.refs[key] = ref;
        stack.insert(0, Object.assign({ key, app: "", summary: "", body: "", icon: "", glyph: "", crit: false, leaving: false }, c));
        // больше most — старейшая из живых уходит
        let live = 0;
        for (let i = 0; i < stack.count; i++) if (!stack.get(i).leaving && ++live > root.most) stack.setProperty(i, "leaving", true);
    }
    Connections {
        target: Notes
        function onArrived(n) {
            root.push({ app: n.appName || "app", summary: n.summary ?? "", body: n.body ?? "", icon: n.appIcon ?? "",
                        crit: n.urgency === NotificationUrgency.Critical }, n);
        }
    }

    // ---- питание: зарядку включили/выдернули, зарядилась, садится (15% — предупредить, 5% — красным). Плашкой в остров,
    // мимо истории уведомлений. armed — не на старте ----
    readonly property var bat: UPower.displayDevice
    readonly property int pct: Math.round((bat?.percentage ?? 0) * 100)
    property int warned: 100
    function hm(s) { const m = Math.round(s / 60); return m >= 60 ? `${Math.floor(m / 60)} h ${m % 60} m` : `${m} m`; }
    function power(summary, glyph, crit, time) {
        if (root.armed && root.bat?.isLaptopBattery) root.push({ app: "power", summary, body: `${root.pct}%` + (time ? ` · ${time}` : ""), glyph, crit: !!crit });
    }
    Connections {
        target: UPower
        function onOnBatteryChanged() {
            root.warned = 100;
            if (UPower.onBattery) root.power("On battery", "\u{F0079}", false, root.bat.timeToEmpty ? `${root.hm(root.bat.timeToEmpty)} left` : "");
            else root.power("Charging", "\u{F0084}", false, root.bat.timeToFull ? `full in ${root.hm(root.bat.timeToFull)}` : "");
        }
    }
    Connections {
        target: root.bat
        function onStateChanged() { if (root.bat.state === UPowerDeviceState.FullyCharged && !UPower.onBattery) root.power("Fully charged", "\u{F0079}"); }
        function onPercentageChanged() {
            if (!UPower.onBattery) return;
            if (root.pct <= 5 && root.warned > 5) { root.warned = 5; root.power("Battery critical", "\u{F0083}", true, "plug in now"); }
            else if (root.pct <= 15 && root.warned > 15) { root.warned = 15; root.power("Battery low", "\u{F0083}", false, "plug in soon"); }
        }
    }
    function dismiss(key) { for (let i = 0; i < stack.count; i++) if (stack.get(i).key === key) return stack.setProperty(i, "leaving", true); }
    function forget(key) {
        delete refs[key];
        for (let i = 0; i < stack.count; i++) if (stack.get(i).key === key) return stack.remove(i);
    }
    Timer { id: noteT; interval: 3000; onTriggered: root.note = null }
    readonly property bool crit: note?.urgency === NotificationUrgency.Critical

    Edge {
        id: top
        shown: !!root.note && Theme.state.edges
        anchors.top: true
        margins.top: root.underBar ? Math.ceil(78 * Theme.s) : 0
        implicitWidth: Math.ceil(640 * Theme.s)
        implicitHeight: Math.ceil(30 * Theme.s)
        Seg {
            x: 20
            y: 4
            width: 600
            height: 4
            n: 12
            f: 1
            on: root.crit ? Theme.red : Theme.fg
            layer.enabled: true
            layer.effect: Glow {}
            SequentialAnimation on opacity {
                running: top.shown
                loops: Animation.Infinite
                NumberAnimation { from: 0.15; to: 1; duration: 720; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1; to: 0.15; duration: 1680; easing.type: Easing.InOutSine }
            }
        }
    }

    // остров: стопка плашек сверху по центру, новые сверху. Белая обводка (критическое — красная), иконка в круге, красная точка.
    // Каждая — как dynamic island: падает пилюлей, расплывается в плашку, текст проявляется последним; уходит обратно, и её место
    // схлопывается — нижние подтягиваются. Своя жизнь у каждой 4 с, наведение на стопку держит все.
    // Окно постоянного размера (под most плашек), мышь ловит только сама стопка
    PanelWindow {
        visible: stack.count > 0
        anchors.top: true
        margins.top: root.underBar ? Math.ceil(78 * Theme.s) : 0
        implicitWidth: Math.ceil(600 * Theme.s)
        implicitHeight: Math.ceil((24 + root.most * 132) * Theme.s)
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region { item: col }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "glyph-island"

        Stage {
            Column {
                id: col
                y: 24
                width: 600
                HoverHandler { id: hov }

                Repeater {
                    model: stack

                    Item {
                        id: c
                        required property int index
                        required property string key
                        required property string app
                        required property string summary
                        required property string body
                        required property string icon
                        required property string glyph
                        required property bool crit
                        required property bool leaving

                        // p 0…1 линейно, у каждой фазы своё ease-out-quart (как glide)
                        property real p: 0
                        Component.onCompleted: p = Qt.binding(() => leaving ? 0 : 1)
                        Behavior on p { NumberAnimation { duration: c.leaving ? 450 : 700 } }
                        onPChanged: if (leaving && p <= 0) Qt.callLater(root.forget, key)
                        function ph(a, b) { const x = Math.max(0, Math.min(1, (p - a) / (b - a))); return 1 - Math.pow(1 - x, 4); }
                        readonly property real drop: ph(0, 0.3)   // пилюля падает
                        readonly property real grow: ph(0.25, 0.8) // и расплывается в плашку
                        readonly property real full: Math.max(86, txt.height + 32)

                        width: 600
                        height: (40 + (full - 40) * grow + 12) * drop // место в стопке растёт и схлопывается вместе с плашкой
                        Timer { running: !c.leaving && !hov.hovered; interval: 4000; onTriggered: root.dismiss(c.key) }

                        Rectangle {
                            width: 140 + (600 - 140) * c.grow
                            height: 40 + (c.full - 40) * c.grow
                            x: (600 - width) / 2
                            y: -24 * (1 - c.drop)
                            opacity: c.drop
                            radius: Theme.corner(Math.min(34, height / 2))
                            clip: true
                            color: Theme.s1
                            border { width: 1; color: c.crit ? Theme.red : Theme.fg }

                            // содержимое — в полный размер по центру: ширина текста не меняется, пока плашка растёт
                            Item {
                                anchors.centerIn: parent
                                width: 600
                                height: c.full
                                opacity: c.ph(0.7, 1)

                                Rectangle {
                                    id: ic
                                    x: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 54
                                    height: 54
                                    radius: 27
                                    color: Theme.s2
                                    Icon { anchors.centerIn: parent; visible: !img.visible; text: c.glyph || "\u{F009A}"; font.pixelSize: 24 }
                                    Image {
                                        id: img
                                        anchors.centerIn: parent
                                        width: 28
                                        height: 28
                                        visible: status === Image.Ready
                                        source: c.icon ? Quickshell.iconPath(c.icon, true) : ""
                                        sourceSize: Qt.size(28, 28)
                                        layer.enabled: true
                                        layer.effect: Dm { step: 2 }
                                    }
                                }
                                Column {
                                    id: txt
                                    anchors { left: ic.right; leftMargin: 16; right: dot.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
                                    Lb { width: parent.width; elide: Text.ElideRight; text: `${c.app} · now` }
                                    Text {
                                        width: parent.width
                                        topPadding: 2
                                        elide: Text.ElideRight
                                        text: c.summary
                                        textFormat: Text.PlainText
                                        font { family: Theme.ui; pixelSize: 17; weight: Font.DemiBold }
                                        color: Theme.fg
                                    }
                                    Text {
                                        width: parent.width
                                        visible: !!c.body
                                        elide: Text.ElideRight
                                        maximumLineCount: 2
                                        wrapMode: Text.Wrap
                                        textFormat: Text.PlainText
                                        text: c.body
                                        font { family: Theme.ui; pixelSize: 14 }
                                        color: Theme.grey
                                    }
                                }
                                // красная точка — только у самой новой: красное на экране одно
                                Rectangle { id: dot; visible: c.index === 0; anchors { right: parent.right; rightMargin: 22; verticalCenter: parent.verticalCenter } width: 12; height: 12; radius: 6; color: Theme.accent }
                            }

                            // клик — действие по умолчанию; плашка уходит, в истории остаётся. Уведомление могли уже закрыть —
                            // от объекта остаётся пустая обёртка без actions
                            TapHandler {
                                onTapped: {
                                    root.refs[c.key]?.actions?.find(a => a.identifier === "default")?.invoke();
                                    root.dismiss(c.key);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- справа ----
    Edge {
        id: side
        anchors.right: true
        implicitWidth: Math.ceil(160 * Theme.s)
        implicitHeight: Math.ceil(520 * Theme.s)
        Lit {
            x: 160 - 5 - 5
            y: 10
            width: 5
            height: 500
            n: 20
            vertical: true
            f: root.value
        }
        Tag {
            vertical: true // у вертикальной полосы и капсула стоит: иконка над числом
            anchors { right: parent.right; rightMargin: 26; verticalCenter: parent.verticalCenter }
            Icon { text: root.kind === "bri" ? "\u{F00E0}" : Sys.muted ? "\u{F075F}" : "\u{F057E}" }
            Num { text: Math.round(root.value * 100); font.pixelSize: 30 }
        }
    }

    // ---- снизу: прогресс задачи, без неё — идущий фокус-таймер (одной полосой, без капсулы: висит десятки минут) ----
    readonly property var task: Notes.task
    readonly property real progress: task ? Math.max(0, Math.min(100, task.hints.value ?? 0)) / 100 : Focus.f
    Connections {
        target: Focus
        function onDone() { root.push({ app: "focus", summary: "Focus done", body: `${Focus.minutes} min`, glyph: "\u{F13AB}" }); }
    }
    Edge {
        shown: (!!root.task || Focus.running) && Theme.state.edges
        anchors.bottom: true
        implicitWidth: Math.ceil(1100 * Theme.s)
        implicitHeight: Math.ceil(110 * Theme.s)
        Lit {
            x: 10
            y: 110 - 5 - 5
            width: 1080
            height: 5
            n: 40
            f: root.progress
        }
        Tag {
            visible: !!root.task
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 26 }
            Icon { text: "\u{F01DA}" }
            Lb { text: root.task?.summary ?? ""; color: Theme.fg }
            Num { text: Math.round(root.progress * 100) + "%"; font.pixelSize: 26 }
        }
    }

    // полоса у края: сквозная для мыши, рисуется в пикселях макета
    component Edge: PanelWindow {
        property bool shown
        default property alias content: st.data
        visible: shown
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "glyph-edge"
        Stage { id: st }
    }
    // капсула-значение рядом с полосой; vertical — содержимое столбиком
    component Tag: Rectangle {
        default property alias content: box.data
        property bool vertical
        width: vertical ? Math.max(52, box.width + 24) : box.width + 32
        height: vertical ? box.height + 36 : 52
        radius: Theme.corner(Math.min(width, height) / 2)
        color: Theme.s1
        border { width: 1; color: Theme.s2 }
        Grid {
            id: box
            anchors.centerIn: parent
            columns: parent.vertical ? 1 : 99
            spacing: parent.vertical ? 10 : 12
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter
        }
    }
    // свечение горящих сегментов — единственная «тень» во всём шелле
    component Glow: MultiEffect {
        shadowEnabled: true
        shadowColor: Theme.glow
        shadowBlur: 0.7
        blurMax: 20
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
    }
}
