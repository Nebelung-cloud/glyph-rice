import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// deck: дашборд снизу по центру, как у caelestia, только из-под нижнего края. Курсор у края (полоса 2 px) 150 мс —
// панель выезжает, ушёл с неё — через 300 мс прячется. Секции — Theme.state.deck по порядку (id из Theme.decks), колонками.
// Без scrim и клавиатуры: подсмотреть и уйти. Окно на каждом экране, открыто не больше одного
Scope {
    id: root

    property var on: null // экран, где открыта
    function toggle() { on = on ? null : Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]; }

    readonly property var ids: Theme.state.deck.filter(id => Theme.decks.includes(id))
    readonly property int h: 232 // высота секций в пикселях макета

    // открыта — подробный опрос (detailed ставит Home по deckOpen) и процессы с частотой
    Binding { target: Sys; property: "deckOpen"; value: root.on !== null }
    Binding { target: SysStats; property: "perf"; value: root.on !== null }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property var en: Qt.locale("en_US")
    function hm(d) { return Qt.formatTime(d, Theme.state.clock24 ? "hh:mm" : "h:mm ap"); }
    function week(d) { // ISO-неделя, как в Home
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7));
        return Math.ceil(((t - Date.UTC(t.getUTCFullYear(), 0, 1)) / 86400000 + 1) / 7);
    }

    // сеть за 40 с — столбцы матрицы, [rx, tx]. Свой такт: SysStats пишет rx/tx раз в те же 2 с
    property var net: []
    Timer { running: root.on !== null; interval: 2000; repeat: true; onTriggered: root.net = root.net.concat([[SysStats.rx, SysStats.tx]]).slice(-20) }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData
            readonly property bool open: root.on === modelData
            property real t: open ? 1 : 0
            Behavior on t { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }

            screen: modelData
            visible: Theme.state.deckHover && root.ids.length > 0 || t > 0
            anchors.bottom: true
            implicitWidth: Math.ceil(panel.width * Theme.s)
            implicitHeight: Math.ceil((panel.height + 14) * Theme.s)
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            // ponytail: Top, не Overlay — под полноэкранным окном край не ловит; Glyph-полоса прогресса рисуется поверх
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "glyph-deck"
            // закрыта — мышь ловит только полоса у края (углы экрана свободны), открыта — всё окно вместе со щелью под панелью
            mask: Region { y: win.open ? 0 : win.height - 2; width: win.width; height: win.open ? win.height : 2 }

            Timer { id: dwell; interval: 150; onTriggered: root.on = win.modelData }
            Timer { id: leave; interval: 300; onTriggered: if (win.open) root.on = null }

            Stage {
                // полоса и панель — одно окно: курсор не перескакивает между поверхностями, hovered не мигает
                HoverHandler {
                    onHoveredChanged: {
                        if (hovered) {
                            leave.stop();
                            if (!win.open && Theme.state.deckHover) dwell.restart();
                        } else {
                            dwell.stop();
                            if (win.open) leave.restart();
                        }
                    }
                }

                Rectangle {
                    id: panel
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: (1 - win.t) * (height + 14) // выезжает из-под края
                    width: row.width + 52
                    height: root.h + 52
                    opacity: win.t // не visible: у скрытого Row ширина 0, а по ней меряется окно
                    radius: 40
                    color: Theme.s1
                    border { width: 1; color: Theme.s2 }

                    Row {
                        id: row
                        x: 26
                        y: 26
                        spacing: 16
                        Repeater {
                            model: root.ids
                            Row {
                                id: cell
                                required property string modelData
                                required property int index
                                spacing: 16
                                // между секциями — столбик точек
                                Image {
                                    visible: cell.index > 0
                                    width: 4
                                    height: root.h
                                    fillMode: Image.TileVertically
                                    source: "data:image/svg+xml," + encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="4" height="10"><circle cx="2" cy="5" r="1.5" fill="#${Theme.hex(Theme.s3)}"/></svg>`)
                                }
                                Loader { sourceComponent: ({ clock: clockC, weather: weatherC, perf: perfC, net: netC, media: mediaC })[cell.modelData] }
                            }
                        }
                    }
                }
            }

            // часы, дата, неделя; световой день сегментами от восхода до заката
            Component {
                id: clockC
                Column {
                    width: 216
                    Lb { text: root.en.dayName(clock.date.getDay()) + (Theme.state.clock24 ? "" : clock.date.getHours() < 12 ? " · am" : " · pm") }
                    Num {
                        topPadding: lead + 10
                        text: Theme.state.clock24 ? Qt.formatTime(clock.date, "hh:mm") : (clock.date.getHours() % 12 || 12) + Qt.formatTime(clock.date, ":mm")
                        font.pixelSize: 72
                    }
                    Lb { topPadding: 12; text: `${root.en.toString(clock.date, "d MMMM")} · week ${root.week(clock.date)}` }
                    Item { width: 1; height: 24 }
                    Seg { width: parent.width; height: 6; n: 24; f: Weather.sun ? (clock.date - Weather.sun.rise) / (Weather.sun.set - Weather.sun.rise) : 0 }
                    Item {
                        width: parent.width
                        height: 28
                        Meta { y: 12; icon: "\u{F059C}"; text: Weather.sun ? root.hm(Weather.sun.rise) : "--:--" }
                        Meta { y: 12; anchors.right: parent.right; icon: "\u{F059B}"; text: Weather.sun ? root.hm(Weather.sun.set) : "--:--" }
                    }
                }
            }

            // сейчас крупно и четыре дня вперёд, глифы через маску точек
            Component {
                id: weatherC
                Column {
                    width: 188
                    Lb { width: parent.width; elide: Text.ElideRight; text: Weather.ok ? Weather.name(Weather.now.code) : "no sky" }
                    Item { width: 1; height: 10 }
                    Row {
                        spacing: 8
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Weather.glyph(Weather.now?.code ?? 3, Weather.now?.day)
                            font.pixelSize: 48
                            layer.enabled: true
                            layer.effect: Dm { step: 3 }
                        }
                        Num { anchors.verticalCenter: parent.verticalCenter; text: Weather.ok ? Math.round(Weather.now.temp) + "°" : "--"; font.pixelSize: 54 }
                    }
                    Lb { topPadding: 8; visible: Weather.ok; text: `feels ${Math.round(Weather.now?.feels)}° · ${Math.round(Weather.now?.wind)} m/s`; px: 11 }
                    Item { width: 1; height: 18 }
                    Row {
                        spacing: 8
                        Repeater {
                            model: Weather.days.slice(1, 5)
                            Column {
                                required property var modelData
                                required property int index
                                width: 41
                                Lb { anchors.horizontalCenter: parent.horizontalCenter; text: root.en.dayName((clock.date.getDay() + index + 1) % 7, Locale.ShortFormat); px: 10 }
                                Icon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    topPadding: lead + 6
                                    text: Weather.glyph(modelData.code, true)
                                    font.pixelSize: 24
                                    layer.enabled: true
                                    layer.effect: Dm { step: 2 }
                                }
                                Lb { anchors.horizontalCenter: parent.horizontalCenter; topPadding: 6; text: Math.round(modelData.max) + "°"; px: 11; color: Theme.fg }
                                Lb { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(modelData.min) + "°"; px: 11 }
                            }
                        }
                    }
                }
            }

            // кольца cpu/mem/gpu с температурами, топ процессов сегментами, ядра матрицей
            Component {
                id: perfC
                Column {
                    width: 300
                    Row {
                        spacing: 18
                        Gauge { on: win.open; f: SysStats.cpu; label: `cpu · ${Math.round(SysStats.cpuTemp)}°` }
                        Gauge { on: win.open; f: SysStats.mem; label: `mem · ${SysStats.memUsed.toFixed(1)}g` }
                        Gauge { on: win.open; f: SysStats.gpu; label: `gpu · ${Math.round(SysStats.gpuTemp)}°` }
                    }
                    Item { width: 1; height: 18 }
                    Row {
                        spacing: 14
                        Column {
                            width: 160
                            spacing: 4
                            Lb { bottomPadding: 2; text: "processes"; px: 10 }
                            Repeater {
                                model: SysStats.procs
                                Row {
                                    required property var modelData
                                    spacing: 6
                                    Lb { width: 78; elide: Text.ElideRight; text: modelData[0]; px: 10; color: Theme.fg }
                                    Lb { width: 34; horizontalAlignment: Text.AlignRight; text: Math.round(modelData[1]) + "%"; px: 10 }
                                    Seg { anchors.verticalCenter: parent.verticalCenter; width: 36; height: 5; n: 6; spacing: 3; f: modelData[1] / 100 }
                                }
                            }
                        }
                        Column {
                            width: 126
                            spacing: 6
                            Lb { text: `cores · ${SysStats.cpuFreq.toFixed(1)} ghz`; px: 10 }
                            // столбец на ядро: верхняя точка белая, под ней серые — как график cpu в Home
                            Grid {
                                id: cores
                                readonly property int n: Math.max(1, SysStats.cores.length)
                                // высота в бюджете root.h=232: 109 кольца + 18 отступ + 19 подпись → сетке ≤86, иначе вылезает из панели
                                // d от ширины колонки (126, стабильна), а не своей — иначе петля d↔width и сетка схлопывается в 0
                                readonly property real d: Math.min((126 - (n - 1) * spacing) / n, (86 - 7 * spacing) / 8)
                                width: n * d + (n - 1) * spacing
                                // уже колонки — центрируем саму сетку: зазора справа нет, по бокам ровно
                                anchors.horizontalCenter: parent.horizontalCenter
                                columns: n
                                spacing: 3
                                Repeater {
                                    model: cores.n * 8
                                    Rectangle {
                                        required property int index
                                        readonly property int up: 8 - Math.floor(index / cores.n) // 8 сверху … 1 снизу
                                        readonly property int lvl: Math.round(1 + 7 * (SysStats.cores[index % cores.n] ?? 0))
                                        width: cores.d
                                        height: cores.d
                                        radius: cores.d / 2
                                        color: up === lvl ? Theme.fg : up < lvl ? Theme.grey : Theme.s2
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // приём/отдача Doto и 40 с матрицей: приём растёт вверх от середины, отдача (серая) — вниз
            Component {
                id: netC
                Column {
                    width: 176
                    Lb { width: parent.width; elide: Text.ElideRight; text: "net · " + (SysStats.iface || "offline") }
                    Item { width: 1; height: 10 }
                    Speed { icon: "\u{F0045}"; b: SysStats.rx }
                    Item { width: 1; height: 8 }
                    Speed { icon: "\u{F005D}"; b: SysStats.tx }
                    Item { width: 1; height: 18 }
                    Grid {
                        id: hist
                        // шкала — пик окна, но не меньше 10 kb/s: тишина не рисует шум
                        readonly property real peak: Math.max(10240, ...root.net.map(p => Math.max(p[0], p[1])))
                        readonly property real d: (width - 19 * spacing) / 20
                        width: parent.width
                        columns: 20
                        spacing: 3
                        Repeater {
                            model: 20 * 10
                            Rectangle {
                                required property int index
                                readonly property int r: Math.floor(index / 20) // 0…9 сверху вниз
                                readonly property bool tx: r >= 5
                                readonly property var p: root.net[index % 20 - 20 + root.net.length] ?? [0, 0]
                                readonly property bool lit: (tx ? r - 4 : 5 - r) <= Math.ceil(5 * (tx ? p[1] : p[0]) / hist.peak)
                                width: hist.d
                                height: hist.d
                                radius: hist.d / 2
                                color: lit ? (tx ? Theme.grey : Theme.fg) : Theme.s2
                            }
                        }
                    }
                }
            }

            // плеер: обложка точками крутится, пока играет и deck открыта
            Component {
                id: mediaC
                Column {
                    width: 240
                    Lb { width: parent.width; elide: Text.ElideRight; text: Media.player?.identity ?? "silence" }
                    Item { width: 1; height: 12 }
                    Row {
                        spacing: 14
                        Item {
                            id: art
                            width: 84
                            height: 84
                            property real turn: 0
                            Timer { running: win.open && Media.playing; interval: 33; repeat: true; onTriggered: art.turn = (art.turn + 360 / 14 / 30) % 360 }
                            Art { anchors.fill: parent; rotation: art.turn; url: Media.player?.trackArtUrl ?? ""; step: 5 }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 142
                            Text {
                                width: parent.width
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                text: Media.player?.trackTitle || "Nothing on"
                                font { family: Theme.ui; pixelSize: 17; weight: Font.DemiBold }
                                color: Theme.fg
                            }
                            Text { width: parent.width; elide: Text.ElideRight; text: Media.player?.trackArtist ?? ""; font { family: Theme.ui; pixelSize: 13 } color: Theme.grey }
                        }
                    }
                    Item { width: 1; height: 16 }
                    // firefox длину не шлёт
                    Seg { width: parent.width; height: 6; n: 20; f: Media.player?.lengthSupported && Media.player.length > 0 ? Media.position / Media.player.length : 0 }
                    Item {
                        width: parent.width
                        height: 26
                        visible: !!Media.player
                        Lb { y: 8; text: Media.time(Media.position); px: 11 }
                        Lb { y: 8; anchors.right: parent.right; visible: !!Media.player?.lengthSupported; text: Media.time(Media.player?.length); px: 11 }
                    }
                    Item { width: 1; height: 8 }
                    Controls { anchors.horizontalCenter: parent.horizontalCenter; size: 20; play: 48 }
                }
            }
        }
    }

    // кольцо с числом внутри и подписью; on — точки загораются волной при открытии
    component Gauge: Column {
        id: g
        property real f
        property bool on
        property string label
        spacing: 8
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 88
            height: 88
            Ring { anchors.fill: parent; n: 32; dot: 4; f: g.on ? g.f : 0 }
            Num { anchors.centerIn: parent; text: Math.round(g.f * 100); font.pixelSize: 30 }
        }
        Lb { anchors.horizontalCenter: parent.horizontalCenter; text: g.label; px: 10 }
    }
    // скорость: стрелка, число Doto, единица меткой
    component Speed: Row {
        id: sp
        property string icon
        property real b
        readonly property var v: SysStats.rate(b).split(" ")
        spacing: 8
        Icon { anchors.verticalCenter: parent.verticalCenter; text: sp.icon; font.pixelSize: 18 }
        Num { anchors.verticalCenter: parent.verticalCenter; text: sp.v[0]; font.pixelSize: 44 }
        Lb { anchors.verticalCenter: parent.verticalCenter; text: sp.v[1]; px: 11 }
    }
    component Meta: Row {
        id: m
        property string icon
        property string text
        spacing: 8
        Icon { anchors.verticalCenter: parent.verticalCenter; text: m.icon; font.pixelSize: 16 }
        Lb { anchors.verticalCenter: parent.verticalCenter; text: m.text; px: 11 }
    }
}
