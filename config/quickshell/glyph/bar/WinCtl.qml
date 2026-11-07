import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components
import qs.settings

// WinCtl: Верхние правые кнопки управления окном в аутентичном стиле Nothing OS
// Предоставляет универсальные кнопки [ - ] (Свернуть), [ ⧉ ] (Свободное окно), [ ✕ ] (Закрыть)
// для абсолютно всех приложений (LibreOffice Calc / CSV, Kitty, GNOME Terminal, Antigravity и т.д.)
PanelWindow {
    id: root

    required property var screen

    anchors { top: true; right: true }
    margins { top: 14; right: 14 }
    implicitWidth: pill.width
    implicitHeight: pill.height + 36
    color: "transparent"
    WlrLayershell.namespace: "glyph-winctl"
    WlrLayershell.layer: WlrLayer.Top
    exclusionMode: ExclusionMode.Ignore

    // Активно, только когда на текущем рабочем столе есть окна
    readonly property bool hasWins: (Hyprland.focusedWorkspace?.toplevels.values.length ?? 0) > 0
    visible: hasWins

    property string hoverTip: ""

    // Всплывающая подсказка Nothing OS
    Rectangle {
        id: tip
        x: pill.x + (pill.width - width) / 2
        y: pill.y + pill.height + 8
        opacity: root.hoverTip !== "" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 140 } }
        width: tipTxt.implicitWidth + 20
        height: tipTxt.implicitHeight + 10
        radius: Theme.corner(10)
        color: Theme.s1
        border { width: 1; color: Theme.s2 }

        Text {
            id: tipTxt
            anchors.centerIn: parent
            font { family: Theme.mono; pixelSize: 11 }
            color: Theme.fg
            text: root.hoverTip
        }
    }

    Rectangle {
        id: pill
        width: row.width + 16
        height: 38
        radius: Theme.corner(19)
        color: Theme.s1
        border { width: 1.5; color: Theme.s2 }

        Row {
            id: row
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            // 1. Свернуть окно (Minimize: movetoworkspacesilent special:minimized)
            Rectangle {
                id: minBtn
                width: 28
                height: 28
                radius: 14
                color: minArea.containsMouse ? Theme.s3 : "transparent"
                scale: minArea.containsMouse ? 1.08 : 1.0
                Behavior on scale { NumberAnimation { duration: 140 } }
                Behavior on color { ColorAnimation { duration: Theme.t } }

                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -1
                    text: "−"
                    font { family: Theme.mono; pixelSize: 16; bold: true }
                    color: minArea.containsMouse ? Theme.fg : Theme.grey
                }
                MouseArea {
                    id: minArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.hoverTip = "Minimize"
                    onExited: if (root.hoverTip === "Minimize") root.hoverTip = ""
                    onClicked: Hyprland.dispatch("movetoworkspacesilent special:minimized")
                }
            }

            // 2. Свободное / тайловое окно (Float / Tile toggle)
            Rectangle {
                id: floatBtn
                width: 28
                height: 28
                radius: 14
                color: floatArea.containsMouse ? Theme.s3 : "transparent"
                scale: floatArea.containsMouse ? 1.08 : 1.0
                Behavior on scale { NumberAnimation { duration: 140 } }
                Behavior on color { ColorAnimation { duration: Theme.t } }

                Text {
                    anchors.centerIn: parent
                    text: "⧉"
                    font { family: Theme.mono; pixelSize: 13 }
                    color: floatArea.containsMouse ? Theme.fg : Theme.grey
                }
                MouseArea {
                    id: floatArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.hoverTip = "Toggle Float / Tile"
                    onExited: if (root.hoverTip === "Toggle Float / Tile") root.hoverTip = ""
                    onClicked: Hyprland.dispatch("togglefloating")
                }
            }

            // 3. Закрыть окно (Close: killactive)
            Rectangle {
                id: closeBtn
                width: 28
                height: 28
                radius: 14
                color: closeArea.containsMouse ? Theme.red : "transparent"
                scale: closeArea.containsMouse ? 1.08 : 1.0
                Behavior on scale { NumberAnimation { duration: 140 } }
                Behavior on color { ColorAnimation { duration: Theme.t } }

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    font { family: Theme.mono; pixelSize: 12; bold: true }
                    color: closeArea.containsMouse ? "#ffffff" : Theme.fg
                }
                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.hoverTip = "Close"
                    onExited: if (root.hoverTip === "Close") root.hoverTip = ""
                    onClicked: Hyprland.dispatch("killactive")
                }
            }
        }
    }
}
