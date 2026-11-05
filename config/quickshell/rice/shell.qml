import QtQuick
import Quickshell
import Quickshell.Io

// Rice — the shell switcher (qs -c rice, «switch shell» in glyph Prefs — when there's more than one shell).
// A card for each shell — a folder in ~/.config/quickshell with rice.json, drawn in its colors and font.
// ←→ to pick, Enter or click — `rice switch`: the current one stops, hypr returns to its config, the picked one starts
ShellRoot {
    id: root

    readonly property string rice: Quickshell.shellPath("rice")
    property string current: ""
    property var shells: [] // [{ id, name, tagline, title, text, bg, surface, line, fg, dim, accent, palette }]
    property int sel: 0

    Process {
        running: true
        command: ["sh", "-c", '"$0"; for f in "$HOME"/.config/quickshell/*/rice.json; do printf "%s\\t" "$(basename "$(dirname "$f")")"; tr -d "\\n" < "$f"; echo; done', root.rice]
        stdout: StdioCollector {
            onStreamFinished: {
                const [cur, ...rows] = text.trim().split("\n");
                root.current = cur;
                root.shells = rows.map(l => {
                    const t = l.indexOf("\t");
                    try { return Object.assign({ id: l.slice(0, t) }, JSON.parse(l.slice(t + 1))); } catch (e) { return null; }
                }).filter(Boolean);
                root.sel = Math.max(0, root.shells.findIndex(s => s.id !== cur)); // by default — «the other one»
            }
        }
    }

    function go(i) {
        const s = shells[i];
        if (!s) return;
        Quickshell.execDetached(s.id === current ? [rice, "restart"] : [rice, "switch", s.id]);
        Qt.quit();
    }

    FloatingWindow {
        title: "Rice"
        color: "#0B0B0B"
        implicitWidth: 1040
        implicitHeight: 600
        onVisibleChanged: if (!visible) Qt.quit() // the window was closed (Super+C) — quit

        Item {
            anchors.fill: parent
            focus: true
            Keys.onPressed: e => {
                const n = root.shells.length;
                if (e.key === Qt.Key_Left || e.key === Qt.Key_H) root.sel = (root.sel + n - 1) % n;
                else if (e.key === Qt.Key_Right || e.key === Qt.Key_L || e.key === Qt.Key_Tab) root.sel = (root.sel + 1) % n;
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.go(root.sel);
                else if (e.key === Qt.Key_Escape) Qt.quit();
                else return;
                e.accepted = true;
            }

            Column {
                x: 40
                y: 36
                spacing: 6
                Text { text: "RICE"; font { family: "Space Mono"; pixelSize: 12; letterSpacing: 1.7 } color: "#7A7A7A" }
                Text { text: "Choose a shell"; font { family: "Space Grotesk"; pixelSize: 34; weight: Font.Light } color: "#EDEDED" }
            }

            Row {
                id: cards
                x: 40
                y: 124
                spacing: 24
                Repeater {
                    model: root.shells
                    Card {}
                }
            }

            Text {
                x: 40
                anchors { bottom: parent.bottom; bottomMargin: 30 }
                text: "← → choose  ·  ↵ switch  ·  esc close"
                font { family: "Space Mono"; pixelSize: 12; letterSpacing: 1.7; capitalization: Font.AllUppercase }
                color: "#5A5A5A"
            }
        }
    }

    // a shell's card in its colors: a mini desktop, the name in its font, the palette. The selected one — outlined in the accent
    component Card: Rectangle {
        id: card
        required property var modelData
        required property int index
        readonly property var m: modelData
        readonly property bool on: root.sel === index
        readonly property bool live: m.id === root.current

        width: (1040 - 80 - (root.shells.length - 1) * 24) / Math.max(1, root.shells.length)
        height: 400
        radius: 22
        color: m.bg
        border { width: on ? 2 : 1; color: on ? m.accent : m.line }
        Behavior on border.color { ColorAnimation { duration: 200 } }

        // mini desktop: bar on the left, a window with an accent frame on the focused one
        Rectangle {
            id: desk
            x: 18
            y: 18
            width: parent.width - 36
            height: 170
            radius: 12
            color: Qt.darker(card.m.bg, 1.2)
            border { width: 1; color: card.m.line }
            Rectangle {
                x: 8; y: 8
                width: 16
                height: parent.height - 16
                radius: 6
                color: card.m.surface
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 10
                    spacing: 4
                    Repeater {
                        model: 4
                        Rectangle { required property int index; width: 4; height: index === 1 ? 12 : 4; radius: 2; color: index === 1 ? card.m.accent : card.m.dim }
                    }
                }
            }
            Rectangle {
                x: 34; y: 8
                width: (parent.width - 50) * 0.58
                height: parent.height - 16
                radius: 6
                color: card.m.surface
                border { width: 1; color: card.m.fg }
                Column {
                    x: 10; y: 10
                    spacing: 6
                    Repeater {
                        model: [0.7, 0.45, 0.6, 0.3]
                        Rectangle { required property real modelData; width: 120 * modelData; height: 4; radius: 2; color: card.m.dim }
                    }
                }
            }
            Rectangle {
                x: 34 + (parent.width - 50) * 0.58 + 8; y: 8
                width: parent.width - x - 8
                height: parent.height - 16
                radius: 6
                color: card.m.surface
                border { width: 1; color: card.m.line }
                Rectangle { anchors.centerIn: parent; width: 26; height: 26; radius: 13; color: card.m.accent }
            }
        }

        Column {
            x: 26
            anchors { top: desk.bottom; topMargin: 22; right: parent.right; rightMargin: 26 }
            spacing: 10
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: card.m.name
                font { family: card.m.title; pixelSize: 54; weight: Font.Black }
                color: card.m.fg
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: card.m.tagline
                font { family: "Space Mono"; pixelSize: 11; letterSpacing: 1.5; capitalization: Font.AllUppercase }
                color: card.m.dim
            }
            Row {
                topPadding: 8
                spacing: 8
                Repeater {
                    model: card.m.palette ?? []
                    Rectangle { required property string modelData; width: 18; height: 18; radius: 9; color: modelData; border { width: 1; color: card.m.line } }
                }
            }
        }

        // this one is current: an accent dot and «current»
        Row {
            visible: card.live
            anchors { right: parent.right; rightMargin: 26; bottom: parent.bottom; bottomMargin: 24 }
            spacing: 8
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 4; color: card.m.accent }
            Text { text: card.on ? "current · ↵ restart" : "current"; font { family: "Space Mono"; pixelSize: 11; letterSpacing: 1.5; capitalization: Font.AllUppercase } color: card.m.fg }
        }

        HoverHandler { cursorShape: Qt.PointingHandCursor; onHoveredChanged: if (hovered) root.sel = card.index }
        TapHandler { onTapped: root.go(card.index) }
    }
}
