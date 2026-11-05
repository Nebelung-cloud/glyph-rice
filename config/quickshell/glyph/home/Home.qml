import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// the «home screen» on the bottom layer, transparent: a Doto clock, the greeting and a bento of widgets. The grid, orb and wallpaper — under it, in Back.
// A window opened — everything goes under it by itself. System polling and animations — only while the workspace is empty
PanelWindow {
    id: root

    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "glyph-home"

    readonly property bool home: (Hyprland.focusedWorkspace?.toplevels.values.length ?? 0) === 0
    Binding { target: SysStats; property: "detailed"; value: root.home || Sys.deckOpen }
    // not in the delegate: a destroyed Binding doesn't restore the value — the widget removed, and cava would run forever
    Binding { target: Cava; property: "active"; value: root.home && !Theme.state.lite && Theme.state.homeBento && bento.model.some(w => w.id === "cava") }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property var en: Qt.locale("en_US")

    // the blinking colon — two frames a second, not an animation on every vsync
    property bool dim: false
    Timer { running: root.home && Theme.state.blink; interval: 500; repeat: true; onTriggered: root.dim = !root.dim }

    readonly property var player: Media.player
    readonly property var buds: Bluetooth.devices.values.find(d => d.connected && d.batteryAvailable) ?? null
    property var hist: [] // cpu over a minute: 34 matrix columns
    Connections {
        target: SysStats
        function onCpuChanged() { root.hist = root.hist.concat([SysStats.cpu]).slice(-34); }
    }

    function week(d) { // ISO week
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7));
        return Math.ceil(((t - Date.UTC(t.getUTCFullYear(), 0, 1)) / 86400000 + 1) / 7);
    }
    readonly property string hello: { const h = clock.date.getHours(); return h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"; }

    Stage {
        id: stage
        x: Theme.state.barAt === "top" ? -39 * Theme.s : 0 // the layout is for a bar on the left; a bar on top — half its width to the left, centered

        // the clock and date, the greeting and its line can each be hidden (prefs → LOOK → on home); they fade
        Item {
            opacity: Theme.state.homeClock ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
            Row {
                x: 182
                y: 150
                Num { text: Theme.hh(clock.date); font.pixelSize: 300 }
                Num { text: ":"; font.pixelSize: 300; opacity: Theme.state.blink && root.dim ? 0.2 : 1 }
                Num { text: Qt.formatTime(clock.date, "mm"); font.pixelSize: 300 }
            }
            Lb {
                x: 190
                y: 448
                text: `${root.en.toString(clock.date, "dddd · d MMMM")} · week ${root.week(clock.date)}`
                px: 14
                color: Theme.state.wall ? Theme.fg : Theme.grey
            }
        }
        Item {
            opacity: Theme.state.homeHello ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
            Text {
                x: 188
                y: 560
                textFormat: Text.StyledText
                text: `${root.hello},<br><font color="${Theme.grey}">${Theme.state.name || Quickshell.env("USER")}.</font>`
                font { family: Theme.ui; pixelSize: 54; weight: Font.Light; letterSpacing: -1 }
                lineHeight: 1.1
                color: Theme.fg
            }
            Row {
                x: 190
                y: 700
                spacing: 28
                Meta { icon: "\u{F009A}"; text: `${Notes.list.length} notifications` }
                Meta { visible: Weather.ok; icon: Weather.glyph(Weather.now?.code ?? 0, Weather.now?.day); text: `${Math.round(Weather.now?.temp ?? 0)}° ${Weather.name(Weather.now?.code)}` }
                Meta { visible: !!root.buds; icon: "\u{F02CB}"; text: `${root.buds?.name ?? ""} · ${Math.round((root.buds?.battery ?? 0) * 100)}%` }
            }
        }

        // bento: 220 cells, a 20 gap, a 3×3 grid. Which widgets and in what order — Theme.state.widgets (settings), widths —
        // Theme.kinds. Laid out left to right: doesn't fit in a row — from the next one, doesn't fit in three rows — not shown.
        // A square with 40 rounding or a circle — no other shapes
        Repeater {
            id: bento
            model: {
                const out = [];
                let r = 0, c = 0;
                for (const id of Theme.state.widgets ?? []) {
                    const w = Theme.kinds[id];
                    if (!w) continue;
                    if (c + w > 3) { r++; c = 0; }
                    if (r > 2) break;
                    // bar on the right — the grid moves left by the bar's width, otherwise the right column would go under it
                    out.push({ id, x: (Theme.barRight ? 1060 : 1140) + c * 240, y: 150 + r * 240 });
                    c += w;
                }
                return out;
            }
            Loader {
                // hidden (prefs → LOOK → on home) — fades, then unloads
                opacity: Theme.state.homeBento ? 1 : 0
                visible: opacity > 0
                active: visible
                Behavior on opacity { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
                required property var modelData
                x: modelData.x
                y: modelData.y
                sourceComponent: ({ weather: weatherW, calendar: calendarW, cpu: cpuW, ram: ramW, gpu: gpuW, disk: diskW,
                                    battery: batteryW, buds: budsW, player: playerW, system: systemW, cat: catW, cava: cavaW,
                                    photo: photoW })[modelData.id] ?? null
            }
        }

        // weather
        Component {
            id: weatherW
            W {
                round: true
                Column {
                    anchors.centerIn: parent
                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Weather.glyph(Weather.now?.code ?? 3, Weather.now?.day)
                        font.pixelSize: 78
                        layer.enabled: true
                        layer.effect: Dm { step: 4 }
                    }
                    Num { anchors.horizontalCenter: parent.horizontalCenter; topPadding: lead + 6; text: Weather.ok ? Math.round(Weather.now.temp) + "°" : "--"; font.pixelSize: 66 }
                    Lb {
                        anchors.horizontalCenter: parent.horizontalCenter
                        topPadding: 8
                        width: Math.min(implicitWidth, 160) // the circle's chord at this height
                        elide: Text.ElideRight
                        text: Weather.ok ? `${Weather.name(Weather.now.code)} · ${Math.round(Weather.days[0]?.min)}°/${Math.round(Weather.days[0]?.max)}°` : "no sky"
                    }
                }
            }
        }

        // calendar
        Component {
            id: calendarW
            W {
                Column {
                    x: 24
                    y: 24
                    width: parent.width - 48
                    Lb { text: root.en.monthName(clock.date.getMonth()) }
                    Num { topPadding: lead + 8; text: clock.date.getDate(); font.pixelSize: 118 }
                    Row {
                        width: parent.width
                        topPadding: 14
                        Repeater {
                            model: ["M", "T", "W", "T", "F", "S", "S"]
                            Text {
                                required property string modelData
                                required property int index
                                readonly property bool today: (clock.date.getDay() + 6) % 7 === index
                                width: parent.width / 7
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData
                                font { family: Theme.mono; pixelSize: 11 }
                                color: today ? Theme.fg : Theme.grey
                                Rectangle { visible: parent.today; anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter } width: 10; height: 2; color: Theme.fg }
                            }
                        }
                    }
                }
            }
        }

        // rings: cpu, memory, gpu, disk, battery
        Component { id: cpuW; RingW { f: SysStats.cpu; value: Math.round(SysStats.cpu * 100); label: "cpu %" } }
        Component { id: ramW; RingW { f: SysStats.mem; value: Math.round(SysStats.mem * 100); label: "ram %" } }
        Component { id: gpuW; RingW { f: SysStats.gpu; value: Math.round(SysStats.gpu * 100); label: `gpu · ${Math.round(SysStats.gpuTemp)}°` } }
        Component { id: diskW; RingW { f: SysStats.disks[0]?.used ?? 0; value: Math.round((SysStats.disks[0]?.used ?? 0) * 100); label: "disk %" } }
        Component {
            id: batteryW
            RingW {
                readonly property var bat: UPower.displayDevice
                f: bat.percentage
                value: Math.round(bat.percentage * 100)
                label: bat.state === UPowerDeviceState.Charging ? "charging" : "battery"
                on: bat.state !== UPowerDeviceState.Charging && bat.percentage < 0.15 ? Theme.red : Theme.fg
            }
        }

        // player: the dot cover spins while playing
        Component {
            id: playerW
            W {
                span: 2
                Item {
                    id: art
                    x: 28
                    anchors.verticalCenter: parent.verticalCenter
                    width: 164
                    height: 164
                    property real turn: 0
                    Timer { running: root.home && Media.playing && !Theme.state.lite; interval: 33; repeat: true; onTriggered: art.turn = (art.turn + 360 / 14 / 30) % 360 }
                    Art { anchors.fill: parent; rotation: art.turn; url: root.player?.trackArtUrl ?? ""; step: 6 }
                }
                Column {
                    anchors { left: art.right; leftMargin: 26; right: parent.right; rightMargin: 28; verticalCenter: parent.verticalCenter }
                    Lb { text: `now playing · ${root.player?.identity ?? "silence"}`; width: parent.width; elide: Text.ElideRight }
                    Text {
                        width: parent.width
                        topPadding: 10
                        elide: Text.ElideRight
                        text: root.player?.trackTitle || "Nothing on"
                        font { family: Theme.ui; pixelSize: 26; weight: Font.DemiBold }
                        color: Theme.fg
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: root.player?.trackArtist ?? ""
                        font { family: Theme.ui; pixelSize: 15 }
                        color: Theme.grey
                    }
                    Item { width: 1; height: 18 }
                    Seg { width: parent.width; height: 6; n: 24; f: root.player?.lengthSupported && root.player.length > 0 ? Media.position / root.player.length : 0 } // firefox doesn't send the length
                    Item { width: 1; height: 16 }
                    Controls { size: 22; play: 52 }
                }
            }
        }

        // earbuds as a ring; none — the volume
        Component {
            id: budsW
            W {
                round: true
                Ring { anchors { fill: parent; margins: 12 } f: root.buds ? root.buds.battery : Sys.vol }
                Column {
                    anchors.centerIn: parent
                    Icon { anchors.horizontalCenter: parent.horizontalCenter; text: root.buds ? "\u{F02CB}" : "\u{F057E}"; font.pixelSize: 30 }
                    Num { anchors.horizontalCenter: parent.horizontalCenter; topPadding: lead + 8; text: Math.round((root.buds ? root.buds.battery : Sys.vol) * 100); font.pixelSize: 54 }
                    Lb {
                        anchors.horizontalCenter: parent.horizontalCenter
                        topPadding: 6
                        width: 130
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: root.buds?.name ?? "volume"
                    }
                }
            }
        }

        // the cat: a gif as a matrix in the theme's tone via the wallpaper shader (like Wall in look 0), which one — services/Gifs, the tile itself — Gif.
        // Dances only while home is visible
        Component {
            id: catW
            W {
                id: cw
                Gif { anchors.fill: parent; playing: root.home && !Theme.state.lite; bg: cw.color }
            }
        }

        // photo: up to five shots from a folder (services/Photos), like Nothing's photo widget. They change with a wave of dots via the same Wall as
        // the wallpaper, hence its own look (dots / color dots / color). Circle or square — a mask in the tile's shape. Pages through only
        // while home is visible; an empty folder — a hint where to put them
        Component {
            id: photoW
            W {
                id: pw
                round: Theme.state.photoRound
                property int at: 0
                readonly property var list: Photos.list
                onListChanged: at = 0
                Component.onCompleted: { Photos.active = true; Photos.refresh(); }
                Component.onDestruction: Photos.active = false
                Connections { target: root; function onHomeChanged() { if (root.home) Photos.refresh(); } }
                Timer {
                    running: root.home && pw.list.length > 1
                    interval: Math.max(3, Theme.state.photoSecs) * 1000
                    repeat: true
                    onTriggered: pw.at = (pw.at + 1) % pw.list.length
                }
                Rectangle { id: shape; anchors.fill: parent; radius: pw.radius; visible: false; layer.enabled: true }
                Wall {
                    anchors { fill: parent; margins: 1 } // the tile's border stays visible
                    path: pw.list[pw.at] ?? ""
                    look: Theme.state.photoLook
                    pitch: 5
                    bright: 1
                    glass: false
                    layer.enabled: true
                    layer.effect: MultiEffect { maskEnabled: true; maskSource: shape }
                }
                Column {
                    visible: !pw.list.length
                    anchors.centerIn: parent
                    spacing: 10
                    Icon { anchors.horizontalCenter: parent.horizontalCenter; text: "\u{F02E9}"; font.pixelSize: 40; color: Theme.mute }
                    Lb { anchors.horizontalCenter: parent.horizontalCenter; width: Math.min(implicitWidth, 170); elide: Text.ElideMiddle; text: Photos.dir.replace(Quickshell.env("HOME"), "~"); px: 10 }
                }
            }
        }

        // cava as a matrix in a circle, like the Glyph Matrix on the back of the Nothing Phone (3): bass in the center, highs toward the edges, the bars grow
        // from the middle up and down. Silence — dimmed dots. cava runs only while home is visible
        Component {
            id: cavaW
            W {
                round: true
                Grid {
                    anchors.centerIn: parent
                    columns: 15
                    spacing: 4
                    Repeater {
                        model: 15 * 15
                        Rectangle {
                            required property int index
                            readonly property int cx: index % 15 - 7
                            readonly property int cy: Math.floor(index / 15) - 7
                            readonly property int half: Math.floor(Math.sqrt(7.5 * 7.5 - cx * cx)) // half the column height inside the circle
                            readonly property real v: Cava.bars[Math.abs(cx)] ?? 0
                            width: 8
                            height: 8
                            radius: 4
                            // outside the circle — transparent, not visible: Grid would shift the rest
                            color: Math.abs(cy) > half ? "transparent" : Math.abs(cy) < v * (half + 1) ? Theme.fg : Theme.s3
                        }
                    }
                }
            }
        }

        // system: numbers and a cpu graph as a matrix
        Component {
            id: systemW
            W {
                span: 3
                Grid {
                    x: 34
                    anchors.verticalCenter: parent.verticalCenter
                    columns: 2
                    columnSpacing: 10
                    rowSpacing: 22
                    Stat { label: "cpu"; value: Math.round(SysStats.cpu * 100) + "%" }
                    Stat { label: "mem"; value: SysStats.memUsed.toFixed(1) + "G" }
                    Stat { label: "gpu"; value: Math.round(SysStats.gpuTemp) + "°" }
                    Stat { label: "disk"; value: Math.round((SysStats.disks[0]?.used ?? 0) * 100) + "%" }
                }
                Column {
                    x: 344
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x - 34
                    spacing: 12
                    Lb { text: "cpu · 60 s" }
                    // the top dot of a column is white, greys under it
                    Grid {
                        id: spark
                        width: parent.width
                        columns: 34
                        spacing: 4
                        readonly property real d: (width - 33 * spacing) / 34
                        Repeater {
                            model: 34 * 8
                            Rectangle {
                                required property int index
                                readonly property int x_: index % 34
                                readonly property int up: 8 - Math.floor(index / 34) // 8 at the top … 1 at the bottom
                                readonly property int h: Math.round(1 + 6 * (root.hist[x_ - 34 + root.hist.length] ?? 0))
                                width: spark.d
                                height: spark.d
                                radius: spark.d / 2
                                color: up === h ? Theme.fg : up < h ? Theme.grey : Theme.s2
                            }
                        }
                    }
                }
            }
        }
    }

    component W: Rectangle {
        property int span: 1
        property bool round
        width: span * 220 + (span - 1) * 20
        height: 220
        radius: round ? 110 : Theme.corner(40)
        color: Theme.s1
        border { width: 1; color: Theme.s2 }
    }
    // a round widget: a ring of dots lit by a fraction f, a number and a label in the center
    component RingW: Rectangle {
        id: rw
        property real f
        property string value
        property string label
        property color on: Theme.fg
        width: 220
        height: 220
        radius: 110
        color: Theme.s1
        border { width: 1; color: Theme.s2 }
        Ring { anchors { fill: parent; margins: 12 } f: rw.f; on: rw.on }
        Column {
            anchors.centerIn: parent
            Num { anchors.horizontalCenter: parent.horizontalCenter; text: rw.value; font.pixelSize: 72 }
            Lb { anchors.horizontalCenter: parent.horizontalCenter; topPadding: 8; text: rw.label }
        }
    }
    component Meta: Row {
        property string icon
        property string text
        spacing: 10
        Icon { anchors.verticalCenter: parent.verticalCenter; text: parent.icon; font.pixelSize: 16 }
        // on a wallpaper grey gets lost
        Lb { anchors.verticalCenter: parent.verticalCenter; text: parent.text; color: Theme.state.wall ? Theme.fg : Theme.grey }
    }
    component Stat: Column {
        property string label
        property string value
        width: 130
        Lb { text: parent.label }
        Num { topPadding: lead + 6; text: parent.value }
    }
}
