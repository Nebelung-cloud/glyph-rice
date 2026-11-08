import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components
import qs.settings

// WinCtl: Верхние кнопки управления окном в аутентичном стиле Nothing OS
// В обычном состоянии — аккуратная незаметная точка [●], не перекрывающая вкладки и кнопку [+].
// Разворачивается ТОЛЬКО по нажатию (клику) мыши, а не по наведению.
// Можно скрыть в любой момент клавишей Super+\ или Super+`
PanelWindow {
    id: root

    required property var screen

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "glyph-winctl"
    WlrLayershell.layer: WlrLayer.Top
    exclusionMode: ExclusionMode.Ignore

    // Активное окно на текущем рабочем столе
    readonly property var activeWin: Hyprland.toplevels.values.find(t => t.lastIpcObject?.focusHistoryID === 0)
    readonly property bool isFullscreen: (activeWin?.lastIpcObject?.fullscreen ?? 0) !== 0
    readonly property bool hasWins: !!activeWin && (Hyprland.focusedWorkspace?.toplevels.values.length ?? 0) > 0

    // Полное скрытие по Super+\ или настройке
    visible: hasWins && !isFullscreen && Theme.state.winCtl

    readonly property real winX: activeWin?.lastIpcObject?.at?.[0] ?? (root.width - pill.width - 14)
    readonly property real winY: activeWin?.lastIpcObject?.at?.[1] ?? 14
    readonly property real winW: activeWin?.lastIpcObject?.size?.[0] ?? pill.width
    readonly property real winH: activeWin?.lastIpcObject?.size?.[1] ?? 0

    // Смещение при перетаскивании капсулы
    property real userDragX: 0
    property real userDragY: 0

    // Развёрнутое состояние: ТОЛЬКО по клику / нажатию
    property bool isExpanded: false

    onActiveWinChanged: {
        userDragX = 0;
        userDragY = 0;
        isExpanded = false;
    }

    // Пропускаем клики мимо капсулы насквозь в окна
    mask: Region { item: pill }

    property string hoverTip: ""

    // Всплывающая подсказка Nothing OS
    Rectangle {
        id: tip
        x: Math.max(10, Math.min(root.width - width - 10, pill.x + (pill.width - width) / 2))
        y: pill.y + pill.height + 6
        opacity: root.hoverTip !== "" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
        width: tipTxt.implicitWidth + 16
        height: tipTxt.implicitHeight + 8
        radius: Theme.corner(8)
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
        readonly property real defaultX: winX + winW - width - 10
        readonly property real defaultY: winY + 6

        x: Math.max(8, Math.min(root.width - width - 8, defaultX + userDragX))
        y: Math.max(8, Math.min(root.height - height - 8, defaultY + userDragY))

        width: root.isExpanded ? (row.width + 12) : 28
        height: 28
        radius: Theme.corner(14)
        color: Theme.s1
        border { width: 1.5; color: (pillMouse.containsMouse || root.isExpanded) ? Theme.fg : Theme.s2 }

        Behavior on width {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
        Behavior on border.color { ColorAnimation { duration: 140 } }

        // Точка Nothing OS в свёрнутом состоянии
        Rectangle {
            anchors.centerIn: parent
            width: 8
            height: 8
            radius: 4
            color: Theme.nothingRed
            visible: !root.isExpanded
            opacity: root.isExpanded ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 140 } }
        }

        // Область клика по свёрнутой точке (нажатие для разворачивания)
        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: !root.isExpanded
            onClicked: {
                root.isExpanded = true;
                root.hoverTip = "";
            }
            onEntered: {
                if (!root.isExpanded) root.hoverTip = "Window Controls (Click to open)";
            }
            onExited: {
                if (root.hoverTip.startsWith("Window Controls")) root.hoverTip = "";
            }
        }

        // Кнопки управления (видны только в развёрнутом виде)
        Row {
            id: row
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            visible: root.isExpanded
            opacity: root.isExpanded ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 140 } }

            // 0. Ручка перетаскивания (Grip)
            Rectangle {
                width: 18
                height: 22
                radius: 4
                color: dragHandleArea.containsMouse ? Theme.s3 : "transparent"
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.centerIn: parent
                    text: "⠿"
                    font { family: Theme.mono; pixelSize: 11 }
                    color: dragHandleArea.containsMouse ? Theme.fg : Theme.grey
                }
                MouseArea {
                    id: dragHandleArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.SizeAllCursor
                    drag.target: pill
                    drag.axis: Drag.XAndYAxis
                    drag.minimumX: 8
                    drag.maximumX: root.width - pill.width - 8
                    drag.minimumY: 8
                    drag.maximumY: root.height - pill.height - 8
                    onPositionChanged: {
                        if (drag.active) {
                            root.userDragX = pill.x - pill.defaultX;
                            root.userDragY = pill.y - pill.defaultY;
                        }
                    }
                    onEntered: root.hoverTip = "Drag to reposition (Double-click to reset)"
                    onExited: if (root.hoverTip.startsWith("Drag")) root.hoverTip = ""
                    onDoubleClicked: {
                        root.userDragX = 0;
                        root.userDragY = 0;
                    }
                }
            }

            // 1. Свернуть окно (Minimize)
            Rectangle {
                id: minBtn
                width: 22
                height: 22
                radius: 11
                anchors.verticalCenter: parent.verticalCenter
                color: minArea.containsMouse ? Theme.s3 : "transparent"
                scale: minArea.containsMouse ? 1.08 : 1.0
                Behavior on scale { NumberAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -1
                    text: "−"
                    font { family: Theme.mono; pixelSize: 14; bold: true }
                    color: minArea.containsMouse ? Theme.fg : Theme.grey
                }
                MouseArea {
                    id: minArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.hoverTip = "Minimize (Super+M)"
                    onExited: if (root.hoverTip.startsWith("Minimize")) root.hoverTip = ""
                    onClicked: {
                        root.isExpanded = false;
                        Hyprland.dispatch("movetoworkspacesilent special:minimized");
                    }
                }
            }

            // 2. Свободное / тайловое окно (Float / Tile toggle)
            Rectangle {
                id: floatBtn
                width: 22
                height: 22
                radius: 11
                anchors.verticalCenter: parent.verticalCenter
                color: floatArea.containsMouse ? Theme.s3 : "transparent"
                scale: floatArea.containsMouse ? 1.08 : 1.0
                Behavior on scale { NumberAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "⧉"
                    font { family: Theme.mono; pixelSize: 12 }
                    color: floatArea.containsMouse ? Theme.fg : Theme.grey
                }
                MouseArea {
                    id: floatArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.hoverTip = "Toggle Float / Tile (Super+T)"
                    onExited: if (root.hoverTip.startsWith("Toggle Float")) root.hoverTip = ""
                    onClicked: {
                        Hyprland.dispatch("togglefloating");
                    }
                }
            }

            // 3. Закрыть окно (Close)
            Rectangle {
                id: closeBtn
                width: 22
                height: 22
                radius: 11
                anchors.verticalCenter: parent.verticalCenter
                color: closeArea.containsMouse ? Theme.red : "transparent"
                scale: closeArea.containsMouse ? 1.08 : 1.0
                Behavior on scale { NumberAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    font { family: Theme.mono; pixelSize: 11; bold: true }
                    color: closeArea.containsMouse ? "#ffffff" : Theme.fg
                }
                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.hoverTip = "Close (Super+C)"
                    onExited: if (root.hoverTip.startsWith("Close")) root.hoverTip = ""
                    onClicked: {
                        root.isExpanded = false;
                        Hyprland.dispatch("killactive");
                    }
                }
            }

            // 4. Свернуть обратно в точку (Collapse button)
            Rectangle {
                id: collapseBtn
                width: 18
                height: 22
                radius: 4
                anchors.verticalCenter: parent.verticalCenter
                color: collapseArea.containsMouse ? Theme.s3 : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "›"
                    font { family: Theme.mono; pixelSize: 13; bold: true }
                    color: collapseArea.containsMouse ? Theme.fg : Theme.grey
                }
                MouseArea {
                    id: collapseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.hoverTip = "Collapse"
                    onExited: if (root.hoverTip.startsWith("Collapse")) root.hoverTip = ""
                    onClicked: {
                        root.isExpanded = false;
                        root.hoverTip = "";
                    }
                }
            }
        }
    }
}
