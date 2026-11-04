import QtQuick
import Quickshell.Bluetooth
import qs
import qs.components
import "../prefs"

// bluetooth: on the left paired and unknown devices nearby (scans while the section is open), on the right the selected one — battery, name (can be changed),
// trust, block, connect/disconnect, pair, forget
Page {
    id: root
    property bool live
    caption: `bluetooth · ${bt ? bt.name : "no adapter"}`

    readonly property var bt: Bluetooth.defaultAdapter
    readonly property bool btOn: bt?.enabled ?? false
    Binding { when: root.live && root.btOn; target: root.bt; property: "discovering"; value: true }

    readonly property var all: !btOn ? [] : bt.devices.values
    readonly property var paired: all.filter(d => d.paired).sort((a, b) => b.connected - a.connected)
    // nameless ones (just an address) — airwave noise
    readonly property var near: all.filter(d => !d.paired && d.deviceName)

    property string cur: "" // the selected one's address
    readonly property var dev: all.find(d => d.address === cur) ?? null
    onDevChanged: rename.text = dev?.name ?? ""
    function back() {
        if (!cur) return false;
        cur = "";
        return true;
    }

    function icon(i) {
        return /audio|head/.test(i) ? "\u{F02CB}" : /mouse/.test(i) ? "\u{F037D}" : /keyboard/.test(i) ? "\u{F030C}" : /phone/.test(i) ? "\u{F03F2}" : "\u{F00AF}";
    }
    function status(d) {
        return (d.pairing ? "pairing" : d.state === BluetoothDeviceState.Connecting ? "connecting" : d.state === BluetoothDeviceState.Disconnecting ? "disconnecting"
            : d.connected ? "connected" : d.paired ? "paired" : "new") + (d.batteryAvailable ? ` · ${Math.round(d.battery * 100)}%` : "");
    }
    function busy(d) { return d.pairing || d.state === BluetoothDeviceState.Connecting || d.state === BluetoothDeviceState.Disconnecting; }

    Row {
        spacing: 20
        Toggle { text: "bluetooth"; on: root.btOn; onFlip: if (root.bt) root.bt.enabled = !root.bt.enabled }
        Toggle { visible: root.btOn; text: "visible to others"; on: root.bt?.discoverable ?? false; onFlip: root.bt.discoverable = !root.bt.discoverable }
    }

    Row {
        spacing: 50

        Flickable {
            width: 420
            height: Math.min(contentHeight, 640)
            contentHeight: lists.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: lists
                width: parent.width
                spacing: 4
                Lb { x: 8; bottomPadding: 6; text: !root.bt ? "no adapter" : !root.btOn ? "bluetooth off" : `paired · ${root.paired.length}` }
                Repeater {
                    model: root.paired
                    Line {
                        required property var modelData
                        icon: root.icon(modelData.icon)
                        title: modelData.name || modelData.address
                        sub: root.status(modelData)
                        on: modelData.connected
                        busy: root.busy(modelData)
                        picked: root.cur === modelData.address
                        onHit: root.cur = modelData.address
                    }
                }
                Lb { x: 8; topPadding: 22; bottomPadding: 6; visible: root.btOn; text: root.near.length ? `nearby · ${root.near.length}` : "searching…" }
                Repeater {
                    model: root.near
                    Line {
                        required property var modelData
                        icon: root.icon(modelData.icon)
                        title: modelData.name || modelData.address
                        sub: root.status(modelData)
                        busy: root.busy(modelData)
                        picked: root.cur === modelData.address
                        onHit: root.cur = modelData.address
                    }
                }
            }
        }

        Column {
            width: 480
            spacing: 16
            Lb { visible: !root.dev; text: "pick a device to see its details" }

            Column {
                visible: !!root.dev
                width: parent.width
                spacing: 6
                Text { width: parent.width; elide: Text.ElideRight; text: root.dev ? root.dev.name || root.dev.address : ""; font { family: Theme.ui; pixelSize: 32; weight: Font.DemiBold } color: Theme.fg }
                Lb { text: root.dev ? `${root.status(root.dev)} · ${root.dev.address}` : "" }
            }
            Row {
                visible: !!root.dev?.batteryAvailable
                spacing: 10
                Num { id: batN; text: Math.round((root.dev?.battery ?? 0) * 100); font.pixelSize: 96 }
                Num { anchors.baseline: batN.baseline; text: "%"; font.pixelSize: 40; color: Theme.mute }
            }
            Flow {
                visible: !!root.dev
                width: parent.width
                spacing: 14
                Act { visible: !!root.dev && root.dev.paired && !root.dev.connected; icon: "\u{F00B1}"; text: "connect"; onHit: root.dev.connect() }
                Act { visible: !!root.dev?.connected; icon: "\u{F00B3}"; text: "disconnect"; onHit: root.dev.disconnect() }
                Act { visible: !!root.dev && !root.dev.paired && !root.dev.pairing; icon: "\u{F00B1}"; text: "pair"; onHit: { root.dev.trusted = true; root.dev.pair(); } }
                Act { visible: !!root.dev?.pairing; icon: "\u{F0156}"; text: "cancel"; onHit: root.dev.cancelPair() }
                Act { visible: !!root.dev?.paired; icon: "\u{F0A7A}"; text: "forget"; onHit: { root.dev.forget(); root.cur = ""; } }
            }
            Column {
                visible: !!root.dev?.paired
                spacing: 12
                Lb { topPadding: 14; text: "settings" }
                Field { id: rename; label: "name"; hint: "↵ to rename"; onAccepted: if (root.dev && text.trim()) root.dev.name = text.trim() }
                Toggle { text: "trusted · auto-connect"; on: root.dev?.trusted ?? false; onFlip: root.dev.trusted = !root.dev.trusted }
                Toggle { text: "blocked"; on: root.dev?.blocked ?? false; onFlip: root.dev.blocked = !root.dev.blocked }
            }
        }
    }
}
