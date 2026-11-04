import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Networking
import Quickshell.Services.Notifications
import Quickshell.Wayland
import qs
import qs.components
import qs.settings
import qs.services

// quick settings: Super+A or a click on the tray. A 470 panel at the right edge, pressed to the bottom, slides out from the right: clock, Wi-Fi/Bluetooth pills,
// round tiles, sliders (filled — a white pill, empty — dots), a mini player, notifications. The windows behind it dim by 35%
PanelWindow {
    id: root

    signal powerRequested
    signal settingsRequested

    property bool open: false
    // peeked — opened by hovering the edge opposite the bar (Hot): doesn't take the keyboard, the cursor left the panel — closes by itself
    property bool peeked: false
    function toggle() { peeked = false; open = !open; }
    function close() { open = false; }
    // a click inside — the panel is pinned: from then on it closes as usual (esc, outside), hovering no longer decides
    function pin() { peeked = false; }
    function peek() {
        if (open) return;
        peeked = true;
        open = true;
    }
    // the open list: "wifi" | "bt" — under the pills (Picker), "rec" — under the tiles (Rec), "" — nothing
    property string pick: ""
    // on open remember Hyprland's focus: Super+A goes by focus, a peek from the hot edge — where the cursor is.
    // Brightness then changes this very monitor (Sys.panelMon)
    onOpenChanged: if (open) { Sys.panelMon = Hyprland.focusedMonitor?.name ?? ""; Sys.earRun([]); } else pick = ""
    // the cursor 500ms outside the panel and the Hot strip — we close. seen: Hyprland doesn't give a fresh surface the cursor until the mouse moves —
    // until the first move it's unknown where it is, and the panel waits (otherwise with a still cursor it opened and closed right away)
    Timer { interval: 500; running: root.open && root.peeked && seen.hovered && !keep.hovered && !edge.hovered; onTriggered: root.close() }

    // the window appears a moment before it moves: its first frame (creating the surface) is the slow one, so it lands
    // while nothing is moving yet
    property bool mapped: false
    Timer { running: root.visible && !root.mapped; interval: 20; onTriggered: root.mapped = true }
    Connections { target: root; function onVisibleChanged() { if (!root.visible) root.mapped = false; } }
    property real t: open && mapped ? 1 : 0
    Behavior on t { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
    // the side — opposite the bar: bar on the right (Theme.barRight) — the panel and its edge on the left. m — the edge offset, slides in
    readonly property bool left_: Theme.barRight
    readonly property real m: 14 - 24 * (1 - t)

    visible: t > 0 || open
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
        color: Theme.dim
        opacity: 0.35 * root.t
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    Stage {
        id: stage
        HoverHandler { id: seen }
        // the hover zone: the panel and the strip up to the screen edge — a cursor at the very edge doesn't count as «left», otherwise it would close
        // and open right away. The panel inside the zone, not as a sibling: a button's HoverHandler (mode cells, Picker rows) cancels
        // a sibling's hover under it, but not an ancestor's
        Item {
            anchors { right: root.left_ ? undefined : parent.right; left: root.left_ ? parent.left : undefined; bottom: parent.bottom }
            width: panel.width + root.m
            height: panel.height + 14
            HoverHandler { id: keep }
            Rectangle {
                id: panel
                anchors {
                    right: root.left_ ? undefined : parent.right
                    left: root.left_ ? parent.left : undefined
                    rightMargin: root.m
                    leftMargin: root.m
                    bottom: parent.bottom
                    bottomMargin: 14
                }
                width: 470
                height: col.height + 44
                opacity: root.t
                radius: Theme.corner(36)
                color: Theme.s1
                border { width: 1; color: Theme.s2 }
                focus: true
                Keys.onEscapePressed: root.close()
                MouseArea { anchors.fill: parent } // a click on the panel doesn't close it

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
                            Round { icon: "\u{F0493}"; onClicked: { root.close(); root.settingsRequested(); } } // settings; shells — in their SHELL
                            Round { icon: "\u{F0425}"; onClicked: { root.close(); root.powerRequested(); } }
                        }
                    }

                    Row {
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

                    Picker { width: parent.width; kind: root.pick; onTouched: root.pin() }

                    // Nothing / CMF earbuds (Sys.ear): name and battery, noise cancelling under them — cells like the power modes
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
                                text: ["l", "r", "case"].filter(k => Sys.ear?.[k] !== undefined).map(k => `${k} ${Sys.ear[k]}`).join(" · ")
                                color: Theme.fg
                            }
                        }
                        Rectangle {
                            id: anc
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

                    // brightness — of the monitor where the panel was opened: focus is remembered on open (open change below).
                    // Built-in — backlight, external — DDC (ddcutil). No backlight and no DDC — no slider
                    Slider {
                        icon: "\u{F00E0}"
                        visible: Sys.panelBriExternal ? Sys.ddcOk : Sys.hasBri
                        value: Sys.panelBri
                        onMoved: v => Sys.setPanelBri(v)
                    }
                    Slider { icon: Sys.muted ? "\u{F075F}" : "\u{F057E}"; value: Sys.muted ? 0 : Sys.vol; onMoved: v => Sys.setVol(v); picked: root.pick === "out"; onMenu: root.pick = picked ? "" : "out" }
                    Out { width: parent.width; visible: root.pick === "out"; onTouched: root.pin() } // right-click the slider

                    // power mode, like in caelestia: four cells, the white fill slides to the selected one; notches — strength.
                    // ultra — also 60 Hz and no animations, blur or shadows (Rules.modes)
                    // on the right — game mode, like in caelestia (Rules.store.game): no animations, blur, shadows or gaps, tearing
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

                    // mini player
                    Rectangle {
                        visible: !!Media.player
                        width: parent.width
                        height: 86
                        radius: Theme.corner(30)
                        color: Theme.s2
                        Art { id: mart; x: 12; anchors.verticalCenter: parent.verticalCenter; width: 62; height: 62; step: 4; url: Media.player?.trackArtUrl ?? "" }
                        Column {
                            anchors { left: mart.right; leftMargin: 16; right: mctl.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
                            Text { width: parent.width; elide: Text.ElideRight; text: Media.player?.trackTitle || "Nothing on"; font { family: Theme.ui; pixelSize: 16; weight: Font.DemiBold } color: Theme.fg }
                            Text { width: parent.width; elide: Text.ElideRight; text: Media.player?.trackArtist ?? ""; font { family: Theme.ui; pixelSize: 13 } color: Theme.grey }
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

                    // notification cards, the freshest on top; don't fit — they scroll
                    ListView {
                        id: notes
                        width: parent.width
                        height: Math.min(contentHeight, stage.height - 28 - 44 - y)
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
                                Text { width: parent.width; elide: Text.ElideRight; text: n.summary; font { family: Theme.ui; pixelSize: 15; weight: Font.DemiBold } color: Theme.fg }
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
                            // a click — the default action (if any) and dismiss. invoke() closes the notification itself, and with it
                            // this card — from then on only via its own reference, and dismiss only if it's still alive
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
    // the Hot strip: the panel lies over it, the cursor on it keeps the panel, like the panel itself
    Item {
        anchors { right: root.left_ ? undefined : parent.right; left: root.left_ ? parent.left : undefined; bottom: parent.bottom }
        width: 2
        height: Math.round(parent.height * 0.8)
        HoverHandler { id: edge }
    }

    // a round button in the header
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
    // a pill: on — white, the text black. The chevron or a right click — the list of networks/devices, the chevron shows whether it's open
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
            opacity: pill.picked ? 1 : 0.7
            rotation: pill.picked ? 180 : 0
            Behavior on rotation { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
        }
        // the chevron — its own button: a click on the right 64 opens the list, the rest — on/off
        TapHandler { onTapped: p => { root.pin(); p.position.x > pill.width - 64 ? pill.menu() : pill.clicked(); } }
        TapHandler { acceptedButtons: Qt.RightButton; onTapped: { root.pin(); pill.menu(); } }
    }
    // a round 68 tile: on — a white circle. Right click — menu (for record — the recording settings), open — the label white
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
    // a slider: the filled part — a white pill with an icon, the empty one — a row of dots
    component Slider: Rectangle {
        id: sl
        property real value
        property string icon
        property bool picked // right-click → a menu (volume: outputs), open — the number is white
        signal moved(real v)
        signal menu
        TapHandler { acceptedButtons: Qt.RightButton; onTapped: { root.pin(); sl.menu(); } }
        readonly property real shown: area.pressed ? area.v : value
        width: col.width
        height: 54
        radius: Theme.corner(27)
        color: Theme.s2
        // the empty part — dots at a step of 11. Not as an svg tile: it rasterizes at 11px and blurs with the canvas scale
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
            // the wheel on the slider: a notch — a 5% step, a touchpad — by pixels with a multiplier. Small fractions accumulate
            // and apply from 2% — volume and brightness keep whole percents, a fractional step would be eaten otherwise
            property real wacc: 0
            Timer { id: widle; interval: 300; onTriggered: area.wacc = 0 }
            anchors.fill: parent
            preventStealing: true
            function set(x) { v = Math.max(0, Math.min(1, x / width)); sl.moved(v); }
            // pin only on release: it drops the peek, which rebuilds the layer's keyboardFocus — mid-press
            // that breaks the implicit mouse grab, and the first press after the panel opens reaches the click point and dies.
            // During a drag focus isn't touched, it catches up on release — as before, but with no live grab
            onPressed: e => set(e.x)
            onPositionChanged: e => set(e.x)
            onReleased: root.pin()
            onWheel: e => {
                // the wheel holds no implicit grab — pin is safe here
                root.pin();
                const a = e.angleDelta.y || e.angleDelta.x;
                wacc += a ? a / 120 * 0.05 : (e.pixelDelta.y || e.pixelDelta.x) * 0.001;
                widle.restart();
                if (Math.abs(wacc) >= 0.02) {
                    sl.moved(Math.max(0, Math.min(1, (area.pressed ? area.v : sl.value) + wacc)));
                    wacc = 0;
                    widle.stop();
                }
            }
        }
    }
}
