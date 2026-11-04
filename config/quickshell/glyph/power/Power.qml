import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components
import qs.services

// power menu: Super+Esc. The screen almost black, a column of Doto words on the left: the selected one large with a red dot, the rest Mute.
// ↑↓ — a word grows and shrinks smoothly. On the right a ring of 60 dots: uptime (a fraction of a six-hour shift)
PanelWindow {
    id: root

    property int sel: 2
    readonly property var items: [
        ["LOCK", () => Quickshell.execDetached([Quickshell.env("HOME") + "/.config/quickshell/rice/rice", "lock"])],
        ["SLEEP", () => Quickshell.execDetached(["systemctl", "suspend"])],
        ["SHUT DOWN", () => Quickshell.execDetached(["systemctl", "poweroff"])],
        ["REBOOT", () => Quickshell.execDetached(["systemctl", "reboot"])],
        ["LOG OUT", () => Hyprland.dispatch("hl.dsp.exit()")]
    ]

    function open() {
        sel = 2;
        SysStats.sample(); // fresh uptime
        visible = true;
    }
    function close() { visible = false; }
    function accept() {
        close();
        items[sel][1]();
    }

    visible: false
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "glyph-power"

    Rectangle {
        anchors.fill: parent
        color: Theme.fade(Theme.bg, 0.96)
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    Stage {
        id: stage
        focus: true
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Up || e.key === Qt.Key_K) root.sel = (root.sel + 4) % 5;
            else if (e.key === Qt.Key_Down || e.key === Qt.Key_J || e.key === Qt.Key_Tab) root.sel = (root.sel + 1) % 5;
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.accept();
            else if (e.key === Qt.Key_Escape) root.close();
            else return;
            e.accepted = true;
        }

        Column {
            x: 240
            anchors.verticalCenter: parent.verticalCenter
            spacing: 26
            Repeater {
                model: root.items
                Row {
                    id: it
                    required property var modelData
                    required property int index
                    readonly property bool on: root.sel === index
                    spacing: 30
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: it.on
                        width: 30
                        height: 30
                        radius: 15
                        color: Theme.red
                    }
                    Grow { text: it.modelData[0]; on: it.on; big: 168; small: 66; anchors.verticalCenter: parent.verticalCenter }
                    HoverHandler { onHoveredChanged: if (hovered) root.sel = it.index }
                    TapHandler { onTapped: { root.sel = it.index; root.accept(); } }
                }
            }
        }

        Item {
            x: stage.width - 200 - 460
            anchors.verticalCenter: parent.verticalCenter
            width: 460
            height: 460
            Ring { anchors.fill: parent; n: 60; dot: 10; f: SysStats.uptime / (6 * 3600) }
            Column {
                anchors.centerIn: parent
                Lb { anchors.horizontalCenter: parent.horizontalCenter; text: "uptime" }
                Num {
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: lead + 10
                    bottomPadding: lead + 10
                    text: `${Math.floor(SysStats.uptime / 3600)}:${String(Math.floor(SysStats.uptime / 60) % 60).padStart(2, "0")}`
                    font.pixelSize: 110
                }
                Lb {
                    anchors.horizontalCenter: parent.horizontalCenter
                    readonly property int n: Hyprland.toplevels.values.length
                    text: `${n} window${n === 1 ? "" : "s"} open`
                }
            }
        }

        Row {
            x: 240
            anchors { bottom: parent.bottom; bottomMargin: 70 }
            spacing: 34
            Lb { text: "↑↓ select" }
            Lb { text: "↵ confirm" }
            Lb { text: "esc cancel" }
        }
    }
}
