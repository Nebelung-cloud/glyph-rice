import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import "../prefs"

// first-run card: the keys to know. Once «got it» is pressed it stays away (Theme.state.welcomed); System → about brings it back
PanelWindow {
    id: root

    readonly property var keys: [
        ["Super", "launcher, apps and search"], ["Super + T", "terminal"],
        ["Super + I", "system: wifi, bluetooth, sound"], ["Super + A", "quick settings"],
        ["Super + Tab", "workspace overview"], ["Super + Space", "dashboard"],
        ["Super + W", "browser"], ["Super + E", "files"],
        ["Super + Shift + W", "wallpapers"], ["Super + V", "clipboard"],
        ["Super + Shift + S", "screenshot"], ["Super + Period", "emoji"],
        ["Super + Q", "close a window"], ["Super + 1…9", "go to a workspace"],
        ["Super + drag", "move a window"], ["Super + X + drag", "resize a window"],
        ["Super + L", "lock"], ["Super + Esc", "power menu"]
    ]

    readonly property bool ready: Theme.warm // after the login settles; asked for later, at once
    property real t: ready ? 1 : 0
    Behavior on t { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
    function done() { Theme.state.welcomed = true; }

    visible: ready
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "glyph-welcome"

    Rectangle { anchors.fill: parent; color: Theme.scrim; opacity: root.t }

    Stage {
        id: stage
        focus: true
        Keys.onPressed: e => {
            if (e.key !== Qt.Key_Escape && e.key !== Qt.Key_Return && e.key !== Qt.Key_Enter) return;
            root.done();
            e.accepted = true;
        }

        Rectangle {
            x: (stage.width - width) / 2
            y: (stage.height - height) / 2 + 24 * (1 - root.t)
            width: 1120
            height: body.height + 96
            radius: Theme.corner(44)
            opacity: root.t
            color: Theme.s1
            border { width: 1; color: Theme.s2 }

            Column {
                id: body
                x: 56
                y: 48
                width: parent.width - 112
                spacing: 28

                Row {
                    spacing: 24
                    Ring { width: 64; height: 64; n: 16; dot: 4; f: 1 }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        Num { text: "glyph"; font.pixelSize: 44 }
                        Lb { text: "the keys to know" }
                    }
                }

                Grid {
                    columns: 2
                    columnSpacing: 40
                    rowSpacing: 12
                    Repeater {
                        model: root.keys
                        Item {
                            required property var modelData
                            width: 484
                            height: 34
                            Rectangle {
                                id: cap
                                anchors.verticalCenter: parent.verticalCenter
                                width: capL.implicitWidth + 24
                                height: 32
                                radius: Theme.corner(16)
                                color: Theme.s2
                                Lb { id: capL; anchors.centerIn: parent; text: parent.parent.modelData[0]; px: 11; color: Theme.fg }
                            }
                            Text {
                                anchors { left: cap.right; leftMargin: 16; right: parent.right; verticalCenter: parent.verticalCenter }
                                elide: Text.ElideRight
                                text: parent.modelData[1]
                                font { family: Theme.ui; pixelSize: 17 }
                                color: Theme.grey
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 64
                    Lb { anchors.verticalCenter: parent.verticalCenter; text: "this card again: system → about → keyboard shortcuts" }
                    Act { anchors.right: parent.right; icon: "\u{F012C}"; text: "got it"; onHit: root.done() }
                }
            }
        }
    }
}
