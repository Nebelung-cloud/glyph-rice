import QtQuick
import Quickshell
import qs
import qs.components

// the mock for STYLE in settings: a desktop in palette p (Theme.make) — bar, quick settings, kitty, player, the Glyph bar, —
// on the right the roles as callouts, like on a blueprint: a point on the object, a line to the role, a swatch, hex and what it is. A new palette flows in
Item {
    id: root

    property var p: Theme.pal
    readonly property var c: p.c
    readonly property color ink: p.light ? c[1] : c[0] // text on white
    // callouts: y — the line, x — where on the mock it meets the object. Colors are separate, by number: in roles they'd recreate
    // the callouts for every palette, and the swatches would jump rather than flow
    readonly property var roles: [
        { y: 40, x: 607, k: "fg", what: "text · focus · border" },
        { y: 90, x: 560, k: "s1", what: "bar · panels · kitty" },
        { y: 140, x: 484, k: "ansi", what: "terminal" },
        { y: 193, x: 528, k: "s3", what: "lines · selection · off" },
        { y: 246, x: 440, k: "bg", what: "wallpaper" },
        { y: 312, x: 592, k: "accent", what: "the one live thing" },
        { y: 382, x: 600, k: "red", what: "alarm" }
    ]
    readonly property var cols: [c[6], c[1], null, c[3], c[0], p.accent, p.red]

    width: 1040
    height: 388

    SystemClock { id: clock; enabled: root.visible; precision: SystemClock.Minutes }

    Rectangle {
        width: 620
        height: 388
        radius: Theme.corner(24)
        color: root.c[0]
        border { width: 1; color: Theme.s3 }
        Behavior on color { ColorAnimation { duration: Theme.t } }
        Image {
            anchors { fill: parent; margins: 12 }
            fillMode: Image.Tile
            source: "data:image/svg+xml," + encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16"><circle cx="8" cy="8" r="1" fill="#${Theme.hex(root.c[2])}"/></svg>`)
        }

        // bar: the mark, workspaces, clock
        Fill {
            x: 12
            y: 12
            width: 44
            height: 364
            radius: Theme.corner(22)
            color: root.c[1]
            border { width: 1; color: root.c[2] }
            Fill { x: 16; y: 16; width: 12; height: 12; radius: 6; color: root.c[6] }
            Column {
                x: 18
                y: 52
                spacing: 8
                Fill { width: 8; height: 24; radius: 4; color: root.c[6] }
                Repeater {
                    model: 3
                    Fill { width: 8; height: 8; radius: 4; color: root.c[3] }
                }
            }
            Column {
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 16 }
                Cap { text: Theme.hh(clock.date); color: root.c[6]; font.pixelSize: 11 }
                Cap { text: Qt.formatTime(clock.date, "mm"); color: root.c[6]; font.pixelSize: 11 }
            }
        }

        // quick settings, an unfocused window: toggles like Toggle, volume, tiles
        Fill {
            x: 68
            y: 12
            width: 196
            height: 228
            radius: Theme.corner(18)
            color: root.c[1]
            border { width: 1; color: root.c[3] }
            Cap { x: 16; y: 16; text: "quick"; color: root.c[5] }
            Fill {
                x: 16
                y: 40
                width: 164
                height: 30
                radius: Theme.corner(15)
                color: root.c[2]
                Fill {
                    x: 4
                    y: 4
                    width: parent.width - 8
                    height: 22
                    radius: Theme.corner(11)
                    color: root.c[6]
                    Cap { x: 12; anchors.verticalCenter: parent.verticalCenter; text: "wi-fi"; color: root.ink }
                    Fill { anchors { right: parent.right; rightMargin: 9; verticalCenter: parent.verticalCenter } width: 6; height: 6; radius: 3; color: root.ink }
                }
            }
            Fill {
                x: 16
                y: 78
                width: 164
                height: 30
                radius: Theme.corner(15)
                color: root.c[2]
                Fill { x: 4; y: 4; width: 22; height: 22; radius: 11; color: root.c[4] }
                Cap { x: 36; anchors.verticalCenter: parent.verticalCenter; text: "bluetooth"; color: root.c[5] }
            }
            Cap { x: 16; y: 124; text: "sound"; color: root.c[5] }
            Seg { x: 16; y: 142; width: 164; height: 6; n: 16; f: 0.6; on: root.c[6]; off: root.c[3] }
            Row {
                x: 16
                y: 166
                spacing: 8
                Fill {
                    width: 78
                    height: 46
                    radius: Theme.corner(12)
                    color: root.c[6]
                    Cap { anchors.centerIn: parent; text: "dnd"; color: root.ink }
                }
                Fill {
                    width: 78
                    height: 46
                    radius: Theme.corner(12)
                    color: root.c[2]
                    Cap { anchors.centerIn: parent; text: "game"; color: root.c[5] }
                }
            }
        }

        // kitty focused: fastfetch, 16 colors, a selection, the cursor
        Fill {
            x: 276
            y: 12
            width: 332
            height: 228
            radius: Theme.corner(18)
            color: root.c[1]
            border { width: 2; color: root.c[6] }
            Column {
                x: 16
                y: 14
                spacing: 4
                Row {
                    Mono { text: "❯ "; color: root.p.ansi[2] }
                    Mono { text: "fastfetch"; color: root.c[6] }
                }
                Row {
                    Mono { text: "glyph"; color: root.p.ansi[4] }
                    Mono { text: "@"; color: root.c[5] }
                    Mono { text: "rice"; color: root.p.ansi[4] }
                }
                Repeater {
                    model: [["os", "arch linux"], ["wm", "hyprland"], ["shell", "fish"]]
                    Row {
                        required property var modelData
                        Mono { width: 56; text: parent.modelData[0]; color: root.p.ansi[4] }
                        Mono { text: parent.modelData[1]; color: root.c[6] }
                    }
                }
            }
            Grid {
                x: 16
                y: 120
                columns: 8
                spacing: 2
                Repeater {
                    model: 16
                    Fill { required property int index; width: 22; height: 14; color: root.p.ansi[index] }
                }
            }
            Fill { x: 10; y: 172; width: 242; height: 18; color: root.c[3] }
            Mono { x: 16; y: 173; text: "~/.config/quickshell/glyph"; color: root.c[6] }
            Row {
                x: 16
                y: 200
                Mono { text: "❯ "; color: root.p.ansi[2] }
                Fill { width: 8; height: 15; color: root.c[6] }
            }
        }

        // player: a dotted cover, progress, play — the accent
        Fill {
            x: 68
            y: 252
            width: 540
            height: 120
            radius: Theme.corner(28)
            color: root.c[1]
            border { width: 1; color: root.c[2] }
            Art { x: 16; y: 16; width: 88; height: 88; step: 4 }
            Text {
                x: 124
                y: 22
                text: "Glyph Matrix"
                font { family: Theme.ui; pixelSize: 20 }
                color: root.c[6]
                Behavior on color { ColorAnimation { duration: Theme.t } }
            }
            Cap { x: 124; y: 54; text: "nothing · 2:14"; color: root.c[5] }
            Seg { x: 124; y: 86; width: 300; height: 4; n: 30; f: 0.4; on: root.c[6]; off: root.c[3] }
            Fill {
                x: 468
                y: 32
                width: 56
                height: 56
                radius: 28
                color: root.p.accent
                Icon { anchors.centerIn: parent; text: "\u{F040A}"; color: Theme.on(root.p.accent); font.pixelSize: 26 }
            }
        }
        // the Glyph bar at the bottom: battery running low
        Seg { x: 470; y: 380; width: 130; height: 4; n: 10; f: 1; on: root.p.red }
    }

    // callouts: a point on the object, a line to the role; on the right — a swatch, hex and what it is
    Repeater {
        model: root.roles
        Item {
            id: rl
            required property var modelData
            required property int index
            readonly property var c: root.cols[index]
            y: modelData.y
            Rectangle { x: rl.modelData.x; width: 652 - x; height: 1; color: Theme.mute }
            Rectangle { x: rl.modelData.x - 5; y: -5; width: 11; height: 11; radius: 5.5; color: Theme.fg; border { width: 2; color: Theme.bg } }
            Rectangle {
                visible: !!rl.c
                x: 662
                y: -9
                width: 18
                height: 18
                radius: 9
                color: rl.c ?? "transparent"
                border { width: 1; color: Theme.s3 }
                Behavior on color { ColorAnimation { duration: Theme.t } }
            }
            Lb { x: 694; y: -height / 2; text: rl.modelData.k; color: Theme.fg }
            Lb { visible: !!rl.c; x: 772; y: -height / 2; text: rl.c ? "#" + Theme.hex(rl.c) : "" }
            Grid {
                visible: !rl.c
                x: 772
                y: -8
                columns: 8
                spacing: 3
                Repeater {
                    model: rl.c ? 0 : 16 // the grid — only for ansi
                    Fill { required property int index; width: 7; height: 7; radius: 3.5; color: root.p.ansi[index] }
                }
            }
            Lb { x: 866; y: -height / 2; px: 10; text: rl.modelData.what; color: Theme.mute }
        }
    }

    // the fill and labels flow into the new palette; Cap — like Lb, Mono — a terminal line
    component Fill: Rectangle {
        Behavior on color { ColorAnimation { duration: Theme.t } }
        Behavior on border.color { ColorAnimation { duration: Theme.t } }
    }
    component Cap: Text {
        font { family: Theme.mono; pixelSize: 9; letterSpacing: 1.3; capitalization: Font.AllUppercase }
        Behavior on color { ColorAnimation { duration: Theme.t } }
    }
    component Mono: Text {
        font { family: Theme.mono; pixelSize: 11 }
        Behavior on color { ColorAnimation { duration: Theme.t } }
    }
}
