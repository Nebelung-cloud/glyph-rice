import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Networking
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs
import qs.components
import qs.services
import qs.settings

// бар: пилюля у левого края или сверху — Theme.state.barAt. Первым знак (кольцо из 16 точек) — лаунчер, центр краснеет,
// пока запись или микрофон. Воркспейсы точками, заголовок окна, часы Doto по центру, трей последним — клик открывает быстрые настройки.
// Сбоку всё столбиком, сверху — строкой. Что в трее и в каком порядке, есть ли заголовок — Theme.state (настройки, раздел BAR)
PanelWindow {
    id: root

    signal markClicked
    signal trayClicked
    signal powerClicked
    signal clockClicked

    readonly property bool vert: Theme.state.barAt !== "top" // всё, кроме top (и неизвестное), — слева
    anchors { left: true; right: !vert; top: true; bottom: vert }
    implicitWidth: Math.ceil(78 * Theme.s)  // сбоку
    implicitHeight: Math.ceil(78 * Theme.s) // сверху
    color: "transparent"
    WlrLayershell.namespace: "glyph-bar"

    readonly property int active: Hyprland.focusedWorkspace?.id ?? 0
    // шесть точек, больше — если занят или открыт дальний
    readonly property int count: Math.min(10, Math.max(6, active, ...Hyprland.workspaces.values.filter(w => w.toplevels.values.length).map(w => w.id)))
    readonly property var top: ToplevelManager.activeToplevel
    readonly property var bat: UPower.displayDevice
    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null

    // hyprland 0.56 с lua: dispatch принимает lua-выражение
    function go(ws) { Hyprland.dispatch(`hl.dsp.focus({ workspace = "${ws}" })`); }

    // скролл воркспейсов: навёл на точки — крутишь колесо, идёшь по столам. Одна засечка колеса = один стол;
    // копим дельту и гасим накоп за 300 мс без событий, чтобы тачпад и высокоточные колёса (много мелких
    // событий за свайп) не пролетали через несколько столов разом. WheelHandler на layer-shell поверхности
    // колесо не получает, поэтому MouseArea у точек
    property real wheelAcc: 0
    Timer { id: wheelIdle; interval: 300; onTriggered: root.wheelAcc = 0 }
    function nudge(d) {
        if (!d)
            return;
        wheelAcc += d;
        wheelIdle.restart();
        if (Math.abs(wheelAcc) >= 120) {
            const dir = wheelAcc > 0 ? "-1" : "+1";
            wheelAcc = 0;
            wheelIdle.stop();
            root.go(dir);
        }
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Stage {
        Rectangle {
            id: pill
            x: 14 // от краёв экрана
            y: 14
            width: root.vert ? 64 : parent.width - 28
            height: root.vert ? parent.height - 28 : 64
            radius: Theme.corner(32)
            color: Theme.s1
            border { width: 1; color: Theme.s2 }

            // знак: кольцо из точек, центр — красный, пока что-то пишет
            Item {
                id: mark
                x: root.vert ? (parent.width - width) / 2 : 18
                y: root.vert ? 18 : (parent.height - height) / 2
                width: 34
                height: 34
                Ring { anchors.fill: parent; n: 16; dot: 3 }
                Rectangle {
                    anchors.centerIn: parent
                    width: 9
                    height: 9
                    radius: 4.5
                    color: !Sys.live ? Theme.fg : Qt.colorEqual(Theme.accent, Theme.fg) ? Theme.red : Theme.accent // monochrome: акцент = fg
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.markClicked() }
            }

            // воркспейсы: текущий вытягивается в белую пилюлю, занятые серые, пустые — линия
            Pile {
                id: ws
                x: root.vert ? (parent.width - width) / 2 : mark.x + mark.width + 24
                y: root.vert ? mark.y + mark.height + 24 : (parent.height - height) / 2
                spacing: 8

                Repeater {
                    model: root.count

                    Rectangle {
                        required property int index
                        readonly property int n: index + 1
                        readonly property bool occ: (Hyprland.workspaces.values.find(w => w.id === n)?.toplevels.values.length ?? 0) > 0
                        readonly property bool on: root.active === n
                        property real len: on ? 28 : 8
                        width: root.vert ? 8 : len
                        height: root.vert ? len : 8
                        radius: 4
                        color: on ? Theme.fg : occ ? Theme.grey : Theme.s3
                        Behavior on len { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
                        Behavior on color { ColorAnimation { duration: Theme.t } }
                        MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: root.go(parent.n) }
                    }
                }
            }

            // колесо над точками — ход по столам. Область — sibling стопки (в positioner якорить детей нельзя,
            // ломает раскладку точек). Засечка колеса — угол ±120, один стол; тачпад шлёт pixelDelta по нескольку
            // пикселей за событие — множим на 0,4, иначе один свайп щёлкает по три стола
            MouseArea {
                anchors {
                    left: ws.left; right: ws.right; top: ws.top; bottom: ws.bottom
                    margins: -12
                }
                acceptedButtons: Qt.NoButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onWheel: wheel => {
                    const a = wheel.angleDelta.y || wheel.angleDelta.x;
                    if (a)
                        root.nudge(a);
                    else
                        root.nudge((wheel.pixelDelta.y || wheel.pixelDelta.x) * 0.4);
                }
            }

            // заголовок окна: от воркспейсов до часов, сбоку — повёрнутый
            Item {
                id: title
                x: root.vert ? (parent.width - width) / 2 : ws.x + ws.width + 24
                y: root.vert ? ws.y + ws.height + 24 : (parent.height - height) / 2
                width: root.vert ? 20 : Math.max(0, clk.x - 24 - x)
                height: root.vert ? Math.max(0, clk.y - 24 - y) : 20
                clip: true
                visible: Theme.state.barTitle
                Lb {
                    x: (parent.width - width) / 2
                    y: (parent.height - height) / 2
                    width: root.vert ? parent.height : parent.width
                    rotation: root.vert ? 90 : 0
                    elide: Text.ElideRight
                    visible: (Hyprland.focusedWorkspace?.toplevels.values.length ?? 0) > 0
                    text: root.top ? `${root.top.appId.split(".").pop()} · ${root.top.title}` : ""
                    px: 11
                }
            }

            // часы: сбоку столбиком 14 над 32 и день, сверху строкой. Клик — календарь и фокус-таймер (cal/Cal)
            Pile {
                id: clk
                anchors.centerIn: parent
                TapHandler { onTapped: root.clockClicked() }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                Num { text: Theme.hh(clock.date); font.pixelSize: 30 }
                Num { visible: !root.vert; text: ":"; font.pixelSize: 30 }
                Num { text: Qt.formatTime(clock.date, "mm"); font.pixelSize: 30 }
                Lb {
                    topPadding: root.vert ? 8 : 0
                    leftPadding: root.vert ? 0 : 12
                    text: Qt.locale("en_US").toString(clock.date, "ddd d")
                    px: 10
                }
            }

            // трей — Theme.state.bar по порядку (настройки, раздел BAR). Раскладка, сеть, bluetooth, звук (колесо — громкость),
            // уведомления, батарея, бегущий кот: клик открывает быстрые настройки. Режим питания и питание — свои клики
            Pile {
                x: root.vert ? (parent.width - width) / 2 : parent.width - width - 22
                y: root.vert ? parent.height - height - 22 : (parent.height - height) / 2
                spacing: 20

                Repeater {
                    model: Theme.state.bar
                    Loader {
                        id: part
                        required property string modelData
                        readonly property bool quick: modelData !== "mode" && modelData !== "power"
                        sourceComponent: root.parts[modelData] ?? null
                        visible: !!sourceComponent && (modelData !== "battery" || root.bat.isLaptopBattery)
                        TapHandler { enabled: part.quick; onTapped: root.trayClicked() }
                        HoverHandler { enabled: part.quick; cursorShape: Qt.PointingHandCursor }
                    }
                }
            }
        }
    }
    readonly property var parts: ({ layout: layoutC, wifi: wifiC, bluetooth: btC, sound: soundC, notes: notesC, battery: batC, mode: modeC, power: powerC, cat: catC })
    Component { id: layoutC; Lb { text: Sys.layout; px: 10 } }
    // кот RunCat: чем больше cpu, тем быстрее бежит (250 мс на кадр в простое, 50 на полной). cpu опрашивается, пока он в трее;
    // Binding не в делегате — уничтоженный значение не возвращает. Серый как есть, в светлой теме на белом теряется — чёрный, как buds
    Component {
        id: catC
        AnimatedImage {
            width: 44
            height: 26
            source: "runcat.gif"
            mipmap: true
            speed: 1 + 4 * SysStats.cpu
            layer.enabled: Theme.light
            layer.effect: MultiEffect { brightness: -1 }
        }
    }
    Binding { target: SysStats; property: "cat"; value: Theme.state.bar.includes("cat") }
    // сеть: две дуги и точка, концы круглые, как у батареи; выключен — косая черта
    Component {
        id: wifiC
        Shape {
            id: wf
            width: 20
            height: 18
            preferredRendererType: Shape.CurveRenderer
            readonly property color ink: root.wifi?.connected ? Theme.fg : Theme.grey
            ShapePath {
                strokeColor: wf.ink; strokeWidth: 2.2; capStyle: ShapePath.RoundCap; fillColor: "transparent"
                PathAngleArc { centerX: 10; centerY: 15; radiusX: 5.5; radiusY: 5.5; startAngle: 220; sweepAngle: 100 }
                PathAngleArc { centerX: 10; centerY: 15; radiusX: 10.5; radiusY: 10.5; startAngle: 220; sweepAngle: 100 }
            }
            ShapePath {
                strokeColor: Networking.wifiEnabled ? "transparent" : wf.ink; strokeWidth: 2.2; capStyle: ShapePath.RoundCap
                startX: 3; startY: 2
                PathLine { x: 17; y: 17 }
            }
            ShapePath {
                strokeWidth: -1; fillColor: wf.ink
                PathAngleArc { centerX: 10; centerY: 15; radiusX: 1.9; radiusY: 1.9; startAngle: 0; sweepAngle: 360 }
            }
        }
    }
    Component {
        id: btC
        Icon {
            text: Bluetooth.defaultAdapter?.enabled ? "\u{F00AF}" : "\u{F00B2}"
            color: Bluetooth.devices.values.some(d => d.connected) ? Theme.fg : Theme.grey
        }
    }
    Component {
        id: soundC
        Icon {
            text: Sys.muted ? "\u{F075F}" : "\u{F057E}"
            WheelHandler { onWheel: e => Sys.setVol(Sys.vol + (e.angleDelta.y > 0 ? 0.05 : -0.05)) }
        }
    }
    Component {
        id: notesC
        Icon {
            text: Theme.state.dnd ? "\u{F009B}" : "\u{F009A}"
            color: Notes.list.length ? Theme.fg : Theme.grey
        }
    }
    // слева батарея стоит, заряд растёт снизу; сверху — лежит, растёт слева. На зарядке — молния первой, заливка дышит, пока заряжается
    Component {
        id: batC
        Pile {
            id: batc
            HoverHandler { onHoveredChanged: { root.batHot = hovered; root.peek(batc); } Component.onDestruction: root.batHot = false }
            spacing: 8
            readonly property bool ac: !UPower.onBattery
            readonly property bool charging: root.bat.state === UPowerDeviceState.Charging
            // дыхание шагом 20 кадров/с, как шар в home/Back: анимация гнала бы бар на каждом vsync (120 Гц) все часы
            // зарядки. Косинус с периодом 2,2 с — те же два InOutSine по 1,1 с
            property real phase: 0
            readonly property real pulse: charging ? 0.675 + 0.325 * Math.cos(phase * Math.PI / 1.1) : 1
            Timer { running: batc.charging; interval: 50; repeat: true; onTriggered: batc.phase = (batc.phase + 0.05) % 2.2; onRunningChanged: batc.phase = 0 }
            Icon { visible: batc.ac; text: "\u{F140B}"; font.pixelSize: 14 }
            Rectangle {
                width: root.vert ? 14 : 26
                height: root.vert ? 26 : 14
                radius: 7
                color: "transparent"
                border { width: 1.5; color: Theme.grey }
                Rectangle {
                    x: 3
                    y: parent.height - 3 - height
                    width: root.vert ? parent.width - 6 : (parent.width - 6) * root.bat.percentage
                    height: root.vert ? (parent.height - 6) * root.bat.percentage : parent.height - 6
                    radius: 4
                    color: root.batLow ? Theme.red : Theme.fg
                    opacity: batc.pulse
                }
            }
            // ширина — под «100»: сверху трей прижат вправо, 99 → 100 сдвигал бы всё левее
            Lb { width: full.implicitWidth; horizontalAlignment: Text.AlignHCenter; text: Math.round(root.bat.percentage * 100); px: 10 }
            Lb { id: full; visible: false; text: "100"; px: 10 }
        }
    }
    // режим питания засечками (Rules.modes): ultra — одна, performance — все; клик — следующий,
    // наведение (и на батарею) — карточка с выбором
    Component {
        id: modeC
        Item {
            id: ticks
            width: 40
            height: 22
            Row {
                anchors.centerIn: parent
                spacing: 2
                Repeater {
                    model: Rules.modeCount
                    Rectangle {
                        required property int index
                        anchors.bottom: parent.bottom
                        width: 3
                        height: 5 + index * 3
                        radius: 1.5
                        color: index <= Rules.mode ? Theme.fg : Theme.s3
                    }
                }
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor; onHoveredChanged: { root.tickHot = hovered; root.peek(ticks); } Component.onDestruction: root.tickHot = false }
            TapHandler { onTapped: Rules.setMode((Rules.mode + 1) % Rules.modeCount) }
        }
    }
    Component {
        id: powerC
        Icon {
            text: "\u{F0425}"
            color: pwr.hovered ? Theme.fg : Theme.grey
            HoverHandler { id: pwr; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.powerClicked() }
        }
    }

    // ---- батарея и режим питания: навёл на батарею или засечки — карточка сбоку от бара (со стороны экрана), как поповер caelestia.
    // Заряд Doto, статус, шкала; ниже режимы кругами с засечками — клик выбирает, под курсором — что он делает.
    // Ушёл и с бара, и с карточки — гаснет ----
    property bool batHot: false
    property bool tickHot: false
    readonly property bool powHot: batHot || tickHot || popHov.hovered
    readonly property bool batLow: UPower.onBattery && root.bat.percentage < 0.15
    // карточка встаёт по тому, на что навели (батарея или засечки): сбоку — низом к его низу, сверху — правым краем к его правому;
    // пока видна — не прыгает
    property point popAt
    function peek(it) { if (!pop.visible) popAt = it.mapToItem(pill, it.width, it.height); }
    property bool powOpen: false
    property int powPeek: -1
    onPowHotChanged: powHot ? powOpenT.restart() : powCloseT.restart()
    Timer { id: powOpenT; interval: 180; onTriggered: if (root.powHot) root.powOpen = true }
    Timer { id: powCloseT; interval: 300; onTriggered: if (!root.powHot) root.powOpen = false }
    function hm(sec) { const m = Math.round(sec / 60); return m >= 60 ? `${Math.floor(m / 60)} h ${m % 60} m` : `${m} m`; }
    readonly property string batState: root.bat.state === UPowerDeviceState.Charging
        ? "charging" + (root.bat.timeToFull ? ` · full in ${hm(root.bat.timeToFull)}` : "")
        : !UPower.onBattery ? "on ac · full"
        : "on battery" + (root.bat.timeToEmpty ? ` · ${hm(root.bat.timeToEmpty)} left` : "")

    PopupWindow {
        id: pop
        property real t: root.powOpen ? 1 : 0
        Behavior on t { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
        visible: t > 0
        // от внутреннего края пилюли бара с зазором 14; сбоку растёт вверх от popAt, сверху — вниз и влево
        anchor.item: pill
        anchor.rect: root.vert ? Qt.rect(pill.width + 14, root.popAt.y, 1, 1) : Qt.rect(root.popAt.x, pill.height + 14, 1, 1)
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: root.vert ? Edges.Top | Edges.Right : Edges.Bottom | Edges.Left
        implicitWidth: Math.ceil(440 * Theme.s)
        implicitHeight: Math.ceil(card.height * Theme.s)
        color: "transparent"

        Stage {
            Rectangle {
                id: card
                width: 440
                height: body.height + 52
                radius: Theme.corner(36)
                color: Theme.s1
                border { width: 1; color: Theme.s2 }
                opacity: pop.t
                transform: Translate { x: root.vert ? -16 * (1 - pop.t) : 0; y: root.vert ? 0 : -16 * (1 - pop.t) }
                HoverHandler { id: popHov }

                Column {
                    id: body
                    x: 26
                    y: 26
                    width: parent.width - 52
                    spacing: 18

                    Row {
                        spacing: 14
                        Num { text: Math.round(root.bat.percentage * 100); font.pixelSize: 72 }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            Lb { text: "% battery"; color: Theme.fg }
                            Lb { text: root.batState }
                        }
                    }
                    Seg { width: parent.width; height: 6; n: 24; f: root.bat.percentage; on: root.batLow ? Theme.red : Theme.fg }

                    Lb { topPadding: 6; text: "power mode" }
                    Row {
                        spacing: (body.width - Rules.modeCount * 80) / Math.max(1, Rules.modeCount - 1)
                        Repeater {
                            model: Rules.modeCount
                            Column {
                                id: mo
                                required property int index
                                readonly property bool on: Rules.mode === index
                                spacing: 10
                                Rectangle {
                                    width: 80
                                    height: 80
                                    radius: 40
                                    color: mo.on ? Theme.fg : moHov.hovered ? Theme.s3 : Theme.s2
                                    Behavior on color { ColorAnimation { duration: Theme.t } }
                                    // засечки: сколько горит — такая сила
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        Repeater {
                                            model: 4
                                            Rectangle {
                                                required property int index
                                                anchors.bottom: parent.bottom
                                                width: 5
                                                height: 8 + index * 6
                                                radius: 2.5
                                                color: index <= mo.index ? (mo.on ? Theme.ink : Theme.fg) : (mo.on ? Theme.mute : Theme.s3)
                                            }
                                        }
                                    }
                                    HoverHandler {
                                        id: moHov
                                        cursorShape: Qt.PointingHandCursor
                                        onHoveredChanged: if (hovered) root.powPeek = mo.index; else if (root.powPeek === mo.index) root.powPeek = -1
                                    }
                                    TapHandler { onTapped: Rules.setMode(mo.index) }
                                }
                                Lb { anchors.horizontalCenter: parent.horizontalCenter; text: mo.index === 3 ? "max" : Rules.modes[mo.index].name; color: mo.on ? Theme.fg : Theme.grey }
                            }
                        }
                    }
                    Lb {
                        readonly property int i: root.powPeek >= 0 ? root.powPeek : Rules.mode
                        width: parent.width
                        elide: Text.ElideRight
                        text: `${Rules.modes[i].what} · ${i === 0 ? Rules.rates[0] : Rules.refreshHz} hz`
                    }
                }
            }
        }
    }
}
