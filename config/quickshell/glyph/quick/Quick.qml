import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Notifications
import Quickshell.Wayland
import qs
import qs.components
import qs.settings
import qs.services

// быстрые настройки: Super+A или клик по трею. Панель 470 у правого края, прижата к низу, выезжает справа: часы, пилюли Wi-Fi/Bluetooth,
// круглые плитки, слайдеры (залитое — белая пилюля, пустое — точки), мини-плеер, уведомления. Окна за ней гаснут на 35%
PanelWindow {
    id: root

    signal powerRequested
    signal settingsRequested

    property bool open: false
    // peeked — открыта наведением на правый край (Hot): клавиатуру не забирает, курсор ушёл с панели — закрывается сама
    property bool peeked: false
    function toggle() { peeked = false; open = !open; }
    function close() { open = false; }
    // клик внутри — панель приколота: дальше закрывается как обычно (esc, мимо), наведение её больше не решает
    function pin() { peeked = false; }
    function peek() {
        if (open) return;
        peeked = true;
        open = true;
    }
    // открытый список: "wifi" | "bt" — под пилюлями (Picker), "rec" — под плитками (Rec), "" — ничего
    property string pick: ""
    onOpenChanged: if (open) Sys.earRun([]); else pick = ""
    // курсор 500мс вне панели и полосы Hot — закрываем. seen: Hyprland не отдаёт курсор свежей поверхности, пока мышь не сдвинется —
    // до первого движения неизвестно, где он, и панель ждёт (иначе у неподвижного курсора открывалась и тут же закрывалась)
    Timer { interval: 500; running: root.open && root.peeked && seen.hovered && !keep.hovered && !edge.hovered; onTriggered: root.close() }

    property real t: open ? 1 : 0
    Behavior on t { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }

    visible: t > 0
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open && !peeked ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "glyph-quick"

    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var net: wifi?.networks.values.find(n => n.connected) ?? null
    readonly property var bt: Bluetooth.defaultAdapter
    readonly property var btDev: Bluetooth.devices.values.find(d => d.connected) ?? null
    SystemClock { id: clock; precision: SystemClock.Minutes }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.35 * root.t
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    Stage {
        id: stage
        HoverHandler { id: seen }
        // зона наведения: панель и полоса до края экрана — курсор у самого края не считается «ушёл», иначе она закрылась бы
        // и тут же открылась. Панель внутри зоны, а не соседом: HoverHandler кнопки (клетки режимов, строки Picker) гасит
        // наведение соседа под собой, а предка — нет
        Item {
            anchors { right: parent.right; bottom: parent.bottom }
            width: panel.width + panel.anchors.rightMargin
            height: panel.height + 14
            HoverHandler { id: keep }
            Rectangle {
                id: panel
                anchors { right: parent.right; rightMargin: 14 - 24 * (1 - root.t); bottom: parent.bottom; bottomMargin: 14 }
                width: 470
                height: col.height + 44
                opacity: root.t
                radius: Theme.corner(36)
                color: Theme.s1
                border { width: 1; color: Theme.s2 }
                focus: true
                Keys.onEscapePressed: root.close()
                MouseArea { anchors.fill: parent } // клик по панели не закрывает

                Column {
                    id: col
                    x: 22
                    y: 22
                    width: parent.width - 44
                    spacing: 16

                    Item {
                        width: parent.width
                        height: 54
                        Row {
                            x: 6
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 14
                            Num { anchors.verticalCenter: parent.verticalCenter; text: `${Theme.hh(clock.date)}:${Qt.formatTime(clock.date, "mm")}`; font.pixelSize: 44 }
                            Lb { anchors.verticalCenter: parent.verticalCenter; text: Qt.locale("en_US").toString(clock.date, "ddd d MMM") }
                        }
                        Row {
                            anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                            spacing: 14
                            Round { icon: "\u{F0493}"; onClicked: { root.close(); root.settingsRequested(); } } // настройки; шеллы — в их SHELL
                            Round { icon: "\u{F0425}"; onClicked: { root.close(); root.powerRequested(); } }
                        }
                    }

                    Column {
                        id: nets
                        width: parent.width
                        Row {
                            id: pills
                            width: parent.width
                            spacing: 12
                            Pill {
                                on: Networking.wifiEnabled
                                icon: on ? "\u{F05A9}" : "\u{F05AA}"
                                name: "Wi-Fi"
                                sub: !on ? "off" : (Networking.connectivity === NetworkConnectivity.Portal ? "sign in · " : "") + (root.net?.name ?? "no network")
                                picked: root.pick === "wifi"
                                onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                                onMenu: root.pick = picked ? "" : "wifi"
                            }
                            Pill {
                                on: root.bt?.enabled ?? false
                                icon: on ? "\u{F00AF}" : "\u{F00B2}"
                                name: "Bluetooth"
                                sub: !on ? "off" : root.btDev?.name ?? "on"
                                picked: root.pick === "bt"
                                onClicked: if (root.bt) root.bt.enabled = !root.bt.enabled
                                onMenu: root.pick = picked ? "" : "bt"
                            }
                        }
                        // список выезжает высотой, как уведомления. Отступ над ним — внутри: Column вставил бы свой рывком
                        Item {
                            width: parent.width
                            height: picker.open ? picker.height + 16 : 0
                            Behavior on height { enabled: Rules.moving; NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
                            visible: height > 0
                            clip: true
                            Picker {
                                id: picker
                                y: 16
                                width: parent.width
                                kind: root.pick
                                onTouched: root.pin()
                                // потолок — экран минус остальная панель (уведомления сожмутся до нуля): шесть сетей не выталкивают шапку за экран
                                max: stage.height - 28 - 44 - 16 - pills.height
                                    - col.children.filter(c => c.visible && c !== nets && c !== notes).reduce((s, c) => s + c.height + col.spacing, 0)
                            }
                        }
                    }

                    // наушники Nothing / CMF (Sys.ear): имя и заряд, под ними шумодав — клетки как у режимов питания
                    Column {
                        visible: !!Sys.ear
                        width: parent.width
                        spacing: 10
                        Item {
                            width: parent.width
                            height: 20
                            Lb { x: 6; text: Sys.buds?.name ?? "" }
                            Lb {
                                anchors.right: parent.right
                                rightPadding: 6
                                text: Sys.earBat.map(k => `${k} ${Sys.ear[k]}`).join(" · ")
                                color: Theme.fg
                            }
                        }
                        Rectangle {
                            id: anc
                            visible: Sys.ancModes.length > 0 // Ear (open), Ear (stick) — без шумодава
                            width: parent.width
                            height: 54
                            radius: Theme.corner(27)
                            color: Theme.s2
                            readonly property real cell: (width - 12) / Sys.ancModes.length
                            readonly property int at: Sys.ancModes.findIndex(m => m[0] === Sys.ear?.mode)
                            Rectangle {
                                visible: anc.at >= 0
                                x: 6 + anc.cell * anc.at
                                y: 6
                                width: anc.cell
                                height: parent.height - 12
                                radius: height / 2
                                color: Theme.fg
                                Behavior on x { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
                            }
                            Repeater {
                                model: Sys.ancModes
                                Item {
                                    id: am
                                    required property var modelData
                                    required property int index
                                    x: 6 + anc.cell * index
                                    width: anc.cell
                                    height: anc.height
                                    Lb { anchors.centerIn: parent; text: am.modelData[1]; color: anc.at === am.index ? Theme.ink : Theme.grey }
                                    TapHandler { onTapped: { root.pin(); Sys.setAnc(am.modelData[0]); } }
                                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                                }
                            }
                        }
                    }

                    Grid {
                        width: parent.width
                        columns: 4
                        rowSpacing: 14
                        Tile { icon: "\u{F009B}"; name: "dnd"; on: Theme.state.dnd; onClicked: Theme.state.dnd = !Theme.state.dnd }
                        Tile { icon: "\u{F0594}"; name: "night"; on: Sys.night; onClicked: Sys.toggleNight() }
                        Tile { icon: "\u{F001D}"; name: "airplane"; on: Sys.air; onClicked: Sys.toggleAir() }
                        Tile { icon: "\u{F0176}"; name: "caffeine"; on: Sys.caffeine; onClicked: Sys.caffeine = !Sys.caffeine }
                        Tile { icon: on ? "\u{F036C}" : "\u{F036D}"; name: "mic"; on: Sys.micOn; onClicked: Sys.toggleMic() }
                        Tile { icon: "\u{F044A}"; name: "record"; on: Sys.rec; picked: root.pick === "rec"; onClicked: { root.close(); Sys.toggleRec(); } onMenu: root.pick = picked ? "" : "rec" }
                        Tile { icon: "\u{F0483}"; name: "vpn"; on: Sys.vpn; onClicked: Sys.toggleVpn() }
                        Tile { icon: "\u{F050E}"; name: "dark"; on: !Theme.light; onClicked: Theme.setLight(!Theme.light) }
                    }

                    Rec { width: parent.width; visible: root.pick === "rec"; onTouched: root.pin(); onStart: { root.close(); Sys.toggleRec(); } }

                    Slider { icon: "\u{F00E0}"; visible: Sys.hasBri; value: Sys.bri; onMoved: v => Sys.setBri(v) }
                    Slider { icon: Sys.muted ? "\u{F075F}" : "\u{F057E}"; value: Sys.muted ? 0 : Sys.vol; onMoved: v => Sys.setVol(v) }

                    // режим питания, как в caelestia: четыре клетки, белая заливка переезжает к выбранной; засечки — сила.
                    // ultra — ещё 60 Гц и без анимаций, blur и теней (Rules.modes)
                    // справа — игровой режим, как в caelestia (Rules.store.game): без анимаций, blur, теней и зазоров, tearing
                    Row {
                        width: parent.width
                        spacing: 12
                        Rectangle {
                            id: modes
                            width: parent.width - game.width - 12
                            height: 54
                            radius: Theme.corner(27)
                            color: Theme.s2
                            readonly property real cell: (width - 12) / Rules.modeCount
                            Rectangle {
                                x: 6 + modes.cell * Rules.mode
                                y: 6
                                width: modes.cell
                                height: parent.height - 12
                                radius: height / 2
                                color: Theme.fg
                                Behavior on x { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
                            }
                            Repeater {
                                model: Rules.modeCount
                                Item {
                                    id: mc
                                    required property int index
                                    readonly property bool on: Rules.mode === index
                                    x: 6 + modes.cell * index
                                    width: modes.cell
                                    height: modes.height
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 10
                                        Row {
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 3
                                            Repeater {
                                                model: 4
                                                Rectangle {
                                                    required property int index
                                                    anchors.bottom: parent.bottom
                                                    width: 4
                                                    height: 6 + index * 4
                                                    radius: 2
                                                    color: index <= mc.index ? (mc.on ? Theme.ink : Theme.fg) : (mc.on ? Theme.mute : Theme.s3)
                                                }
                                            }
                                        }
                                        Lb { anchors.verticalCenter: parent.verticalCenter; text: Rules.modes[mc.index].short; color: mc.on ? Theme.ink : Theme.grey }
                                    }
                                    TapHandler { onTapped: { root.pin(); Rules.setMode(mc.index); } }
                                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                                }
                            }
                        }
                        Rectangle {
                            id: game
                            width: 54
                            height: 54
                            radius: 27
                            color: Rules.store.game ? Theme.fg : Theme.s2
                            Behavior on color { ColorAnimation { duration: Theme.t } }
                            Icon { anchors.centerIn: parent; text: "\u{F0297}"; font.pixelSize: 22; color: Rules.store.game ? Theme.ink : Theme.fg }
                            TapHandler { onTapped: { root.pin(); Rules.store.game = !Rules.store.game; } }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                        }
                    }

                    // мини-плеер
                    Rectangle {
                        visible: !!Media.player
                        width: parent.width
                        height: 86
                        radius: Theme.corner(30)
                        color: Theme.s2
                        Art { id: mart; x: 12; anchors.verticalCenter: parent.verticalCenter; width: 62; height: 62; step: 4; url: Media.player?.trackArtUrl ?? "" }
                        Column {
                            anchors { left: mart.right; leftMargin: 16; right: mctl.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
                            Text { textFormat: Text.PlainText; width: parent.width; elide: Text.ElideRight; text: Media.player?.trackTitle || "Nothing on"; font { family: Theme.ui; pixelSize: 16; weight: Font.DemiBold } color: Theme.fg }
                            Text { textFormat: Text.PlainText; width: parent.width; elide: Text.ElideRight; text: Media.player?.trackArtist ?? ""; font { family: Theme.ui; pixelSize: 13 } color: Theme.grey }
                        }
                        Controls { id: mctl; anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter } size: 20; play: 44 }
                    }

                    Item {
                        width: parent.width
                        height: 20
                        Lb { x: 6; text: `notifications · ${Notes.list.length}` }
                        Lb {
                            anchors.right: parent.right
                            rightPadding: 6
                            visible: Notes.list.length > 0
                            text: "clear all"
                            color: Theme.fg
                            TapHandler { onTapped: { root.pin(); Notes.clear(); } }
                        }
                    }

                    // карточки уведомлений, свежие сверху; не влезли — листаются
                    ListView {
                        id: notes
                        width: parent.width
                        height: Math.min(shown, stage.height - 28 - 44 - y)
                        // плавно — по контенту (clear all, dismiss); потолок сразу: Picker или плеер выше не выталкивают шапку за экран
                        property real shown: contentHeight
                        Behavior on shown { enabled: Rules.moving; NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
                        clip: true
                        spacing: 10
                        model: Notes.list.slice().reverse()
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            required property var modelData
                            readonly property var n: modelData
                            width: notes.width
                            height: body.height + 32
                            radius: Theme.corner(26)
                            color: Theme.s2
                            border { width: n.urgency === NotificationUrgency.Critical ? 1 : 0; color: Theme.red }

                            Rectangle {
                                x: 18
                                y: 16
                                width: 42
                                height: 42
                                radius: 21
                                color: Theme.s3
                                Icon { anchors.centerIn: parent; text: "\u{F009A}"; visible: !nicon.visible }
                                Image {
                                    id: nicon
                                    anchors.centerIn: parent
                                    width: 24
                                    height: 24
                                    visible: status === Image.Ready
                                    source: n.appIcon ? Quickshell.iconPath(n.appIcon, true) : ""
                                    sourceSize: Qt.size(24, 24)
                                    layer.enabled: true
                                    layer.effect: Dm { step: 2 }
                                }
                            }
                            Column {
                                id: body
                                x: 74
                                y: 16
                                width: parent.width - x - 18
                                Lb { width: parent.width; elide: Text.ElideRight; text: `${n.appName || "app"} · ${Notes.ago(n, clock.date.getTime())}`; px: 11 }
                                Text { textFormat: Text.PlainText; width: parent.width; elide: Text.ElideRight; text: n.summary; font { family: Theme.ui; pixelSize: 15; weight: Font.DemiBold } color: Theme.fg }
                                Text {
                                    width: parent.width
                                    visible: !!n.body
                                    topPadding: 2
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                    text: n.body
                                    font { family: Theme.ui; pixelSize: 14 }
                                    color: Theme.grey
                                }
                            }
                            // клик — действие по умолчанию (если есть) и убрать. invoke() сам закрывает уведомление, а с ним
                            // и эту карточку — дальше только через свою ссылку, и dismiss, лишь если ещё живо
                            TapHandler {
                                onTapped: {
                                    root.pin();
                                    const it = n;
                                    it.actions.find(a => a.identifier === "default")?.invoke();
                                    if (it.tracked) it.dismiss();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    // полоса Hot: панель ложится поверх неё, курсор на ней держит панель, как и сама панель
    Item {
        anchors { right: parent.right; bottom: parent.bottom }
        width: 2
        height: Math.round(parent.height * 0.8)
        HoverHandler { id: edge }
    }

    // круглая кнопка в шапке
    component Round: Rectangle {
        property string icon
        signal clicked
        width: 44
        height: 44
        radius: 22
        color: Theme.s2
        Icon { anchors.centerIn: parent; text: parent.icon }
        TapHandler { onTapped: { root.pin(); parent.clicked(); } }
    }
    // пилюля: вкл — белая, текст чёрный. Правый клик — список сетей/устройств, шеврон показывает, открыт ли
    component Pill: Rectangle {
        id: pill
        property bool on
        property bool picked
        signal menu
        property string icon
        property string name
        property string sub
        signal clicked
        width: (col.width - 12) / 2
        height: 76
        radius: Theme.corner(38)
        color: on ? Theme.fg : Theme.s2
        Behavior on color { ColorAnimation { duration: Theme.t } }
        Rectangle {
            id: pi
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 52
            height: 52
            radius: 26
            color: pill.on ? Theme.ink : Theme.s3
            Icon { anchors.centerIn: parent; text: pill.icon; font.pixelSize: 22 }
        }
        Column {
            anchors { left: pi.right; leftMargin: 12; right: chev.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
            Text { text: pill.name; font { family: Theme.ui; pixelSize: 16; weight: Font.DemiBold } color: pill.on ? Theme.ink : Theme.fg }
            Text {
                width: parent.width
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: pill.sub
                font { family: Theme.mono; pixelSize: 11; letterSpacing: 0.9; capitalization: Font.AllUppercase }
                color: pill.on ? Theme.ink : Theme.fg
                opacity: 0.6
            }
        }
        Icon {
            id: chev
            anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
            text: "\u{F0140}"
            font.pixelSize: 18
            color: pill.on ? Theme.ink : Theme.fg
            opacity: pill.picked ? 1 : 0.4
            rotation: pill.picked ? 180 : 0
            Behavior on rotation { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
        }
        TapHandler { onTapped: { root.pin(); pill.clicked(); } }
        TapHandler { acceptedButtons: Qt.RightButton; onTapped: { root.pin(); pill.menu(); } }
    }
    // круглая плитка 68: вкл — белый круг. Правый клик — menu (у record — настройки записи), открыто — подпись белая
    component Tile: Column {
        id: tile
        property bool on
        property bool picked
        signal menu
        property string icon
        property string name
        signal clicked
        width: col.width / 4
        spacing: 8
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 68
            height: 68
            radius: 34
            color: tile.on ? Theme.fg : Theme.s2
            Behavior on color { ColorAnimation { duration: Theme.t } }
            Icon { anchors.centerIn: parent; text: tile.icon; font.pixelSize: 24; color: tile.on ? Theme.ink : Theme.fg }
            TapHandler { onTapped: { root.pin(); tile.clicked(); } }
            TapHandler { acceptedButtons: Qt.RightButton; onTapped: { root.pin(); tile.menu(); } }
        }
        Lb { anchors.horizontalCenter: parent.horizontalCenter; text: tile.name; px: 10; color: tile.picked ? Theme.fg : Theme.grey }
    }
    // слайдер: залитая часть — белая пилюля с иконкой, пустая — ряд точек
    component Slider: Rectangle {
        id: sl
        property real value
        property string icon
        signal moved(real v)
        readonly property real shown: area.pressed ? area.v : value
        width: col.width
        height: 54
        radius: Theme.corner(27)
        color: Theme.s2
        // пустая часть — точки шагом 11. Не svg-плиткой: она растрируется в 11px и мылится масштабом холста
        Row {
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 11 - 2.8
            Repeater {
                model: Math.max(0, Math.floor((sl.width - 20) / 11) + 1)
                Rectangle { width: 2.8; height: 2.8; radius: 1.4; color: Theme.mute }
            }
        }
        Rectangle {
            width: Math.max(height, sl.width * sl.shown)
            height: parent.height
            radius: Theme.corner(27)
            color: Theme.fg
            Icon { x: 18; anchors.verticalCenter: parent.verticalCenter; text: sl.icon; font.pixelSize: 21; color: Theme.ink }
        }
        Rectangle {
            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            width: val.width + 16
            height: val.height + 8
            radius: Theme.corner(10)
            color: Theme.s2
            Lb { id: val; anchors.centerIn: parent; text: Math.round(sl.shown * 100) }
        }
        MouseArea {
            id: area
            property real v
            property real wacc: 0
            anchors.fill: parent
            preventStealing: true
            function set(x) { v = Math.max(0, Math.min(1, x / width)); sl.moved(v); }
            // pin на отпускании: в панели, открытой наведением, он отдаёт ей клавиатуру (None → Exclusive), и Hyprland на это
            // отпускает все кнопки мыши — первый drag после peek доезжал до точки клика и обрывался
            onPressed: e => set(e.x)
            onPositionChanged: e => set(e.x)
            onReleased: root.pin()
            // колесо: засечка — 5 %, тачпад (у него фаза жеста, у колеса нет) вчетверо медленнее, иначе свайп — полшкалы.
            // Копим до 2 %: мелкие шаги тачпада съедает округление подсветки, и каждый пускал бы brightnessctl.
            // Без pin: прокрутка — не клик, панель с края закрывается сама и клавиатуру не берёт. Направление — пальцев,
            // как у Slider в Qt: natural scroll (inverted) не разворачивает, вправо и от себя — больше
            onWheel: e => {
                wacc += (e.inverted ? -1 : 1) * (e.angleDelta.y || -e.angleDelta.x) / 120 * 0.05 * (e.phase === Qt.NoScrollPhase ? 1 : 0.25);
                if (Math.abs(wacc) < 0.02)
                    return;
                sl.moved(Math.max(0, Math.min(1, sl.shown + wacc)));
                wacc = 0;
            }
        }
    }
}
