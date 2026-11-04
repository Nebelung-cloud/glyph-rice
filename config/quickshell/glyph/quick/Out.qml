import QtQuick
import Quickshell.Services.Pipewire
import qs
import qs.components

// audio outputs under the volume slider (right-click it). Tap makes one the default; the slider and
// playing apps follow it. Same rows as Picker. From Isaqdn03/glyph-rice
Rectangle {
    id: root
    signal touched // any click inside pins the panel

    // [label, icon, order]
    function kind(n) {
        return /^raop_sink/.test(n.name) ? ["airplay", "\u{F0118}", 3]
            : /^bluez_output/.test(n.name) ? ["bluetooth", "\u{F02CB}", 2]
            : /\.usb-/.test(n.name) ? ["usb", "\u{F02CB}", 2]
            : /HDMI/.test(n.name) ? ["hdmi", "\u{F0379}", 1]
            : ["built-in", "\u{F04C3}", 0];
    }
    // "Ryzen HD Audio Controller Speaker" → Speaker; HDMI goes by the monitor's name
    function name(n) {
        if (/HDMI/.test(n.name) && n.nickname) return n.nickname;
        return n.description.replace(/^.*Controller /, "").replace(/ \(.*\)$/, "") || n.nickname || n.name;
    }
    // unplugged HDMI ports stay as sinks; only a connected one carries the monitor's name (ELD) as its nick.
    // ponytail: a monitor that reports no name hides as unplugged
    readonly property var outs: Pipewire.nodes.values
        .filter(n => n.isSink && n.audio && !n.isStream && !/^HDMI \d+$/.test(n.nickname))
        .sort((a, b) => kind(a)[2] - kind(b)[2] || name(a).localeCompare(name(b)))

    height: list.height + 32
    radius: Theme.corner(30)
    color: Theme.s2

    Column {
        id: list
        x: 16
        y: 16
        width: parent.width - 32
        spacing: 4

        Item {
            width: parent.width
            height: 24
            Lb { x: 4; anchors.verticalCenter: parent.verticalCenter; text: `outputs · ${root.outs.length}` }
        }

        Repeater {
            model: root.outs
            Rectangle {
                id: row
                required property var modelData
                readonly property var o: modelData
                readonly property bool on: Pipewire.defaultAudioSink === o
                readonly property var k: root.kind(o)
                width: list.width
                height: 56
                radius: Theme.corner(28)
                color: hov.hovered ? Theme.s3 : "transparent"

                Rectangle {
                    id: ic
                    x: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    height: 44
                    radius: 22
                    color: row.on ? Theme.fg : Theme.s3
                    Behavior on color { ColorAnimation { duration: Theme.t } }
                    Icon { anchors.centerIn: parent; text: row.k[1]; font.pixelSize: 19; color: row.on ? Theme.ink : Theme.fg }
                }
                Column {
                    anchors { left: ic.right; leftMargin: 14; right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                    Text { width: parent.width; elide: Text.ElideRight; text: root.name(row.o); font { family: Theme.ui; pixelSize: 15; weight: Font.DemiBold } color: Theme.fg }
                    Lb { px: 10; text: row.on ? `default · ${row.k[0]}` : row.k[0] }
                }
                HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: { root.touched(); Pipewire.preferredDefaultAudioSink = row.o; } }
            }
        }
    }
}
