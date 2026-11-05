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

// bar: a pill at the left or right edge, or along the top — Theme.state.barAt. First the mark (a ring of 16 dots) — the launcher, the center
// turns red while recording or the microphone is on. Workspaces as dots, the window title, a Doto clock in the center, the tray last — a click
// opens quick settings. At the side everything is a column, on top a row. What's in the tray and in what order, whether there's a title —
// Theme.state (settings, the BAR section)
PanelWindow {
    id: root

    signal markClicked
    signal trayClicked
    signal powerClicked
    signal clockClicked

    readonly property bool right_: Theme.barRight
    readonly property bool vert: Theme.state.barAt !== "top" // anything but top is at the side
    anchors { left: !right_; right: right_ || !vert; top: true; bottom: vert }
    implicitWidth: Math.ceil(78 * Theme.s)  // at the side
    implicitHeight: Math.ceil(78 * Theme.s) // on top
    // auto-hide, experimental, for OLEDs (burn-in): Theme.state.barHide lists the screens. Hidden: no exclusive zone, input only on a 2 px strip at the
    // edge. Rest there and the pill slides in over the windows; leave it and it slides back out. From Isaqdn03/glyph-rice
    readonly property bool autoHide: vert && Theme.state.barHide.includes(screen?.name ?? "")
    property bool hov: false
    readonly property bool shown: !autoHide || hov || powOpen || pop.visible
    property real slide: shown ? 1 : 0
    Behavior on slide { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
    exclusionMode: autoHide ? ExclusionMode.Ignore : ExclusionMode.Auto
    mask: Region { item: root.shown ? hitAll : hitEdge }
    onAutoHideChanged: hov = false
    Timer { id: showT; interval: 150; onTriggered: root.hov = true }
    Timer { id: hideT; interval: 500; onTriggered: root.hov = false }
    Item { id: hitEdge; x: root.right_ ? root.width - 2 : 0; width: 2; height: parent.height }
    Item { id: hitAll; anchors.fill: parent }
    color: "transparent"
    WlrLayershell.namespace: "glyph-bar"

    readonly property int active: Hyprland.focusedWorkspace?.id ?? 0
    // dots — as many as workspaces (System → workspaces): all, or six and more if a far one is occupied or open; never past the limit
    readonly property int lim: Theme.state.wsCount
    readonly property int count: Theme.state.wsBar === 1 ? lim
        : Math.min(lim, Math.max(Math.min(6, lim), active, ...Hyprland.workspaces.values.filter(w => w.toplevels.values.length).map(w => w.id)))
    readonly property var top: ToplevelManager.activeToplevel
    readonly property var bat: UPower.displayDevice
    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null

    // hyprland 0.56 with lua: dispatch takes a lua expression
    function go(ws) { Hyprland.dispatch(`hl.dsp.focus({ workspace = "${ws}" })`); }

    // workspace scroll: hover the dots and turn the wheel to move through them. One wheel notch = one workspace;
    // the delta accumulates and resets after 300 ms without events, so touchpads and hi-res wheels (many small
    // events per swipe) don't fly through several at once. WheelHandler on a layer-shell surface
    // gets no wheel, hence the MouseArea at the dots
    property real wheelAcc: 0
    Timer { id: wheelIdle; interval: 300; onTriggered: root.wheelAcc = 0 }
    function nudge(d) {
        if (!d)
            return;
        wheelAcc += d;
        wheelIdle.restart();
        if (Math.abs(wheelAcc) >= 120) {
            const d = wheelAcc > 0 ? -1 : 1, slot = active + d; // within the workspace limit, wrapping like the Super+wheel bind
            wheelAcc = 0;
            wheelIdle.stop();
            if (slot >= 1 && slot <= lim) root.go(slot);
            else if (Theme.state.wsWrap) root.go(d > 0 ? 1 : lim);
        }
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Stage {
        HoverHandler {
            onHoveredChanged: {
                if (hovered) { hideT.stop(); showT.restart(); }
                else { showT.stop(); hideT.restart(); }
            }
        }
        Rectangle {
            id: pill
            // a 14 gap — on the screen-edge side; auto-hide slides it off that edge
            x: (root.right_ ? 0 : 14) + (root.vert ? (root.right_ ? 80 : -80) * (1 - root.slide) : 0)
            visible: root.slide > 0
            y: 14
            width: root.vert ? 64 : parent.width - 28
            height: root.vert ? parent.height - 28 : 64
            radius: Theme.corner(32)
            color: Theme.s1
            border { width: 1; color: Theme.s2 }

            // the mark: a ring of dots, the center — red while something is recording
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
                    color: !Sys.live ? Theme.fg : Qt.colorEqual(Theme.accent, Theme.fg) ? Theme.red : Theme.accent // monochrome: accent = fg
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.markClicked() }
            }

            // workspaces: the current one stretches into a white pill, occupied ones grey, empty ones — a line
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

            // the wheel over the dots moves through workspaces. The area is the stack's sibling (anchoring children in a positioner
            // breaks the dot layout). A wheel notch is ±120, one workspace; a touchpad sends pixelDelta a few pixels per event —
            // multiply by 0.4, otherwise one swipe clicks through three
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

            // the window title: from the workspaces to the clock, rotated at the side
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

            // the clock: at the side a column, 14 over 32 and the day, on top a row. A click — calendar and focus timer (cal/Cal)
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

            // the tray — Theme.state.bar in order (settings, the BAR section). Layout, network, bluetooth, sound (wheel — volume),
            // notifications, battery, the running cat: a click opens quick settings. Power mode and power — their own clicks
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
    // the RunCat cat: the more cpu, the faster it runs (250 ms a frame idle, 50 at full load). cpu is polled while it's in the tray;
    // the Binding isn't in the delegate — a destroyed one doesn't restore the value. Grey as is, lost on white in the light theme — black there, like buds
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
    // network: two arcs and a dot, round ends like the battery; off — a slash
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
            Notch { onNotch: d => Sys.setVol(Sys.vol + d * 0.05) }
        }
    }
    Component {
        id: notesC
        Icon {
            text: Theme.state.dnd ? "\u{F009B}" : "\u{F009A}"
            color: Notes.list.length ? Theme.fg : Theme.grey
        }
    }
    // at the side the battery stands upright, the charge grows from the bottom; on top it lies down, growing from the left. On charge — a bolt first, the fill breathes while charging
    Component {
        id: batC
        Pile {
            id: batc
            HoverHandler { onHoveredChanged: { root.batHot = hovered; root.peek(batc); } Component.onDestruction: root.batHot = false }
            spacing: 8
            readonly property bool ac: !UPower.onBattery
            readonly property bool charging: root.bat.state === UPowerDeviceState.Charging
            // breathing at a step of 20 fps, like the orb in home/Back: an animation would drive the bar on every vsync (120 Hz) all the hours
            // of charging. A cosine with a 2.2 s period — the same two 1.1 s InOutSines
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
            // the width fits «100»: on top the tray is pressed right, 99 → 100 would shift everything left
            Lb { width: full.implicitWidth; horizontalAlignment: Text.AlignHCenter; text: Math.round(root.bat.percentage * 100); px: 10 }
            Lb { id: full; visible: false; text: "100"; px: 10 }
        }
    }
    // power mode as notches (Rules.modes): ultra — one, performance — all; a click — the next one,
    // hovering (the battery too) — a card to choose
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

    // ---- battery and power mode: hovered the battery or the notches — a card beside the bar (on the screen side), like caelestia's popover.
    // The charge in Doto, status, a scale; below the modes as circles with notches — a click picks, under the cursor — what it does.
    // Left both the bar and the card — it fades out ----
    property bool batHot: false
    property bool tickHot: false
    readonly property bool powHot: batHot || tickHot || popHov.hovered
    readonly property bool batLow: UPower.onBattery && root.bat.percentage < 0.15
    // the card lines up with what was hovered (battery or notches): at the side its bottom to the bottom, on top its right edge to the right;
    // while visible — it doesn't jump
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
        // from the inner edge of the bar pill with a 14 gap; at the side it grows up from popAt, on top — down and to the left
        anchor.item: pill
        anchor.rect: root.vert ? Qt.rect(root.right_ ? -14 : pill.width + 14, root.popAt.y, 1, 1) : Qt.rect(root.popAt.x, pill.height + 14, 1, 1)
        anchor.edges: Edges.Top | Edges.Left
        anchor.gravity: root.vert ? Edges.Top | (root.right_ ? Edges.Left : Edges.Right) : Edges.Bottom | Edges.Left
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
                transform: Translate { x: root.vert ? (root.right_ ? 16 : -16) * (1 - pop.t) : 0; y: root.vert ? 0 : -16 * (1 - pop.t) }
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
                                    // notches: how many are lit — that's the strength
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
