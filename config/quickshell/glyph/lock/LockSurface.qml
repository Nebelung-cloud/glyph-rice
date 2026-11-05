import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Networking
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// lock: a full-width Doto clock, the date and weather as labels, the layout/network/battery and the notification count in the corners.
// At the bottom an avatar in a ring of dots, the name and a pill field: what's typed — white dots, the caret red. A wrong password — everything red, the field shakes
WlSessionLockSurface {
    id: root

    required property var auth // { buffer, fail, busy, leaving, submit() } from lock.qml
    property string layout: "en"

    color: Theme.bg

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property var en: Qt.locale("en_US")
    readonly property var bat: UPower.displayDevice
    property bool blink: true
    Timer { running: true; interval: 500; repeat: true; onTriggered: root.blink = !root.blink }

    // appearance: t 0→1 linear, each element has its own phase with ease-out-quart (like glide): orb and clock, labels, avatar —
    // the ring lights up in a wave, the field grows from a dot. Password accepted (auth.leaving) — t back and faster, lock.qml removes the lock
    property real t: 0
    Behavior on t { NumberAnimation { duration: root.auth.leaving ? 450 : 1100 } }
    Component.onCompleted: {
        t = Qt.binding(() => root.auth.leaving ? 0 : root.ready ? 1 : 0);
        mainName = Hyprland.focusedMonitor?.name ?? "";
    }
    // one screen (prefs → LOOK): the screen in focus at lock time gets the lock, the others a plain cover. Once, not a binding: moving the
    // cursor mustn't swap them. Typing works from any screen, the buffer is shared through auth
    property string mainName: ""
    readonly property bool primary: !Theme.state.lockOneScreen || !mainName || screen?.name === mainName
    readonly property bool hideLen: Theme.state.lockHideLen
    // the intro waits for the wallpaper to be decoded, then a frame more (600 ms at most): right after boot the disk is cold
    // (the login screen especially), and an intro that plays while images and fonts are still loading stutters. The screen is
    // covered by the background color from the first frame, so waiting doesn't show anything behind the lock
    property bool ready: false
    Timer { running: !root.ready && (wall.opaque || !Theme.state.wall); interval: 30; onTriggered: root.ready = true }
    Timer { running: !root.ready; interval: 600; onTriggered: root.ready = true }
    function ph(a, b) { const x = Math.max(0, Math.min(1, (t - a) / (b - a))); return 1 - Math.pow(1 - x, 4); }
    // password check: a wave runs over the typed dots
    property real wave: 0
    NumberAnimation on wave { running: root.auth.busy; from: 0; to: 1; duration: 700; loops: Animation.Infinite }

    // if the view ever loses the keys (a monitor waking, focus arriving late), take them back: there's nothing else to click on a lock
    Timer { running: !stage.activeFocus; interval: 300; repeat: true; onTriggered: stage.forceActiveFocus() } // lock-focus

    Stage {
        id: stage
        focus: true

        Keys.onPressed: e => {
            if (root.auth.leaving) return;
            if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.auth.submit();
            else if (e.key === Qt.Key_Escape) root.auth.buffer = "";
            else if (e.key === Qt.Key_Backspace) root.auth.buffer = root.auth.buffer.slice(0, -1);
            else if (e.text && e.text.charCodeAt(0) >= 32) { root.auth.buffer += e.text; root.auth.fail = false; }
            else return;
            e.accepted = true;
        }

        Item {
            opacity: root.ph(0, 0.6)
            Orb { visible: Theme.state.orb; x: stage.width - 720; y: stage.height - 580 }
            // Atmosphere (Theme.state.atmosphere, like in Nothing OS): while locked — the wallpaper in a haze, a little closer and slowly
            // breathing; password accepted — sharpness and scale return as the lock leaves
            Wall {
                id: wall
                width: stage.width
                height: stage.height
                path: Theme.wallSrc(Theme.state.wall)
                property real haze: Theme.state.atmosphere && !Theme.state.lite && !root.auth.leaving ? 1 : 0
                Behavior on haze { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
                property real breathe: 0
                SequentialAnimation on breathe {
                    running: wall.haze > 0
                    loops: Animation.Infinite
                    NumberAnimation { to: 1; duration: 8000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0; duration: 8000; easing.type: Easing.InOutSine }
                }
                scale: 1 + wall.haze * (0.05 + 0.03 * wall.breathe)
                layer.enabled: wall.haze > 0
                layer.effect: MultiEffect { blurEnabled: true; blurMax: 64; blur: wall.haze }
            }
        }

        Lb {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 170
            text: root.en.toString(clock.date, "dddd · d MMMM")
            px: 14
            opacity: root.ph(0.15, 0.55)
            transform: Translate { y: 16 * (1 - root.ph(0.15, 0.55)) }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 230
            opacity: root.ph(0, 0.5)
            transform: Translate { y: -40 * (1 - root.ph(0, 0.5)) }
            Num { text: Theme.hh(clock.date); font.pixelSize: 400 }
            Num { text: ":"; font.pixelSize: 400; opacity: root.blink || !Theme.state.blink ? 1 : 0.2 }
            Num { text: Qt.formatTime(clock.date, "mm"); font.pixelSize: 400 }
        }
        Lb {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 600
            opacity: root.ph(0.25, 0.65)
            transform: Translate { y: 16 * (1 - root.ph(0.25, 0.65)) }
            text: [Weather.ok ? `${Math.round(Weather.now.temp)}° ${Weather.name(Weather.now.code)}` : "",
                   Media.player?.trackTitle ? `${Media.player.trackTitle} — ${Media.player.trackArtist}` : ""].filter(Boolean).join(" · ")
        }

        Row {
            anchors { right: parent.right; rightMargin: 44 }
            y: 36
            spacing: 16
            opacity: root.ph(0.45, 0.85)
            Lb { anchors.verticalCenter: parent.verticalCenter; text: root.layout }
            Icon { anchors.verticalCenter: parent.verticalCenter; text: Networking.wifiEnabled ? "\u{F05A9}" : "\u{F05AA}"; font.pixelSize: 17 }
            Rectangle {
                visible: root.bat.isLaptopBattery
                anchors.verticalCenter: parent.verticalCenter
                width: 27
                height: 13
                radius: 7
                color: "transparent"
                border { width: 1.5; color: Theme.grey }
                Rectangle { x: 3; y: 3; width: (parent.width - 6) * root.bat.percentage; height: parent.height - 6; radius: 4; color: Theme.fg }
            }
            Lb { visible: root.bat.isLaptopBattery; anchors.verticalCenter: parent.verticalCenter; text: Math.round(root.bat.percentage * 100) }
        }
        Row {
            visible: Theme.state.unread > 0
            opacity: root.ph(0.45, 0.85)
            x: 44
            anchors { bottom: parent.bottom; bottomMargin: 44 }
            spacing: 16
            Icon { anchors.verticalCenter: parent.verticalCenter; text: "\u{F009A}"; font.pixelSize: 17 }
            Lb { anchors.verticalCenter: parent.verticalCenter; text: `${Theme.state.unread} notifications` }
        }

        Column {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 120 }
            spacing: 16

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 96
                height: 96
                opacity: root.ph(0.3, 0.7)
                transform: Translate { y: 24 * (1 - root.ph(0.3, 0.7)) }
                Ring { anchors.fill: parent; n: 32; f: root.t > 0.35 ? 1 : 0 } // lights up and dims in a wave around the circle
                // ~/.face as dots, like covers; no file — the Art gradient
                Art { anchors { fill: parent; margins: 18 } url: `file://${Quickshell.env("HOME")}/.face`; step: 3 }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Quickshell.env("USER")
                font { family: Theme.ui; pixelSize: 22 }
                color: Theme.fg
                opacity: root.ph(0.4, 0.75)
                transform: Translate { y: 16 * (1 - root.ph(0.4, 0.75)) }
            }

            // the field: typed — dots, after the caret — dimmed ones up to six
            Rectangle {
                id: pwd
                anchors.horizontalCenter: parent.horizontalCenter
                width: 58 + (380 - 58) * root.ph(0.5, 0.9) // grows from a dot into a pill
                height: 58
                radius: Theme.corner(29)
                opacity: root.ph(0.45, 0.6)
                color: Theme.s1
                border { width: 1; color: root.auth.fail ? Theme.red : Theme.s3 }

                Row {
                    anchors.centerIn: parent
                    spacing: 14
                    opacity: root.ph(0.75, 1)
                    Repeater {
                        id: typed
                        model: root.hideLen ? (root.auth.buffer.length ? 3 : 0) : Math.min(root.auth.buffer.length, 16)
                        // a new dot pops out; while pam thinks — a wave runs over the dots
                        Rectangle {
                            required property int index
                            anchors.verticalCenter: parent.verticalCenter
                            width: 11
                            height: 11
                            radius: 5.5
                            color: root.auth.fail ? Theme.red : Theme.fg
                            opacity: root.auth.busy && Math.abs(root.wave * (typed.count + 2) - 1 - index) > 1.2 ? 0.3 : 1
                            NumberAnimation on scale { from: 0.2; to: 1; duration: 180; easing.type: Easing.OutCubic }
                            // hide length: three fixed dots that pulse on each key
                            SequentialAnimation on scale {
                                id: pulse
                                running: false
                                NumberAnimation { to: 0.55; duration: 50 }
                                NumberAnimation { to: 1; duration: 160; easing.type: Easing.OutCubic }
                            }
                            Connections {
                                target: root.auth
                                function onBufferChanged() { if (root.hideLen && root.auth.buffer.length) pulse.restart(); }
                            }
                        }
                    }
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 2; height: 24; color: Theme.accent; opacity: root.blink ? 1 : 0 }
                    Repeater {
                        model: root.hideLen ? 0 : Math.max(0, 6 - root.auth.buffer.length)
                        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 11; height: 11; radius: 5.5; color: Theme.s3 }
                    }
                }

                SequentialAnimation {
                    id: shake
                    loops: 2
                    NumberAnimation { target: pwd; property: "anchors.horizontalCenterOffset"; to: -10; duration: 50 }
                    NumberAnimation { target: pwd; property: "anchors.horizontalCenterOffset"; to: 10; duration: 80 }
                    NumberAnimation { target: pwd; property: "anchors.horizontalCenterOffset"; to: 0; duration: 50 }
                }
                Connections {
                    target: root.auth
                    function onFailChanged() { if (root.auth.fail) shake.restart(); }
                }
            }
            Lb {
                anchors.horizontalCenter: parent.horizontalCenter
                opacity: root.ph(0.8, 1)
                text: root.auth.busy ? "checking…" : root.auth.fail ? "wrong password · try again" : "enter password"
                color: root.auth.fail ? Theme.red : Theme.grey
            }
        }
    }

    Rectangle { anchors.fill: parent; color: Theme.bg; visible: !root.primary }
}
