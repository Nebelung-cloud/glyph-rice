import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// блокировка: часы Doto на всю ширину, дата и погода метками, по углам раскладка/сеть/батарея и счёт уведомлений.
// Внизу аватар в кольце точек, имя и поле-пилюля: введённое — белые точки, каретка красная. Неверный пароль — всё красное, поле трясётся
WlSessionLockSurface {
    id: root

    required property var auth // { buffer, fail, busy, leaving, submit() } из lock.qml
    property string layout: "en"

    color: Theme.bg

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property var en: Qt.locale("en_US")
    readonly property var bat: UPower.displayDevice
    property bool blink: true
    Timer { running: true; interval: 500; repeat: true; onTriggered: root.blink = !root.blink }

    // появление: t 0→1 линейно, у каждого элемента своя фаза с ease-out-quart (как glide): шар и часы, метки, аватар —
    // кольцо загорается волной, поле вырастает из точки. Пароль принят (auth.leaving) — t назад и быстрее, лок снимает lock.qml
    property real t: 0
    Behavior on t { NumberAnimation { duration: root.auth.leaving ? 450 : 1100 } }
    Component.onCompleted: t = Qt.binding(() => root.auth.leaving ? 0 : 1)
    function ph(a, b) { const x = Math.max(0, Math.min(1, (t - a) / (b - a))); return 1 - Math.pow(1 - x, 4); }
    // проверка пароля: по введённым точкам бежит волна
    property real wave: 0
    NumberAnimation on wave { running: root.auth.busy; from: 0; to: 1; duration: 700; loops: Animation.Infinite }

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
            Wall { width: stage.width; height: stage.height; path: Theme.wallSrc(Theme.scr(root.screen?.name, "wall")) }
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
                Ring { anchors.fill: parent; n: 32; f: root.t > 0.35 ? 1 : 0 } // загорается и гаснет волной по кругу
                // ~/.face точками, как обложки; нет файла — градиент Art
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

            // поле: введённые — точки, после каретки — погасшие до шести
            Rectangle {
                id: pwd
                anchors.horizontalCenter: parent.horizontalCenter
                width: 58 + (380 - 58) * root.ph(0.5, 0.9) // вырастает из точки в пилюлю
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
                        model: Math.min(root.auth.buffer.length, 16)
                        // новая точка выщёлкивается; пока pam думает — по точкам бежит волна
                        Rectangle {
                            required property int index
                            anchors.verticalCenter: parent.verticalCenter
                            width: 11
                            height: 11
                            radius: 5.5
                            color: root.auth.fail ? Theme.red : Theme.fg
                            opacity: root.auth.busy && Math.abs(root.wave * (typed.count + 2) - 1 - index) > 1.2 ? 0.3 : 1
                            NumberAnimation on scale { from: 0.2; to: 1; duration: 180; easing.type: Easing.OutCubic }
                        }
                    }
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 2; height: 24; color: Theme.accent; opacity: root.blink ? 1 : 0 }
                    Repeater {
                        model: Math.max(0, 6 - root.auth.buffer.length)
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
}
