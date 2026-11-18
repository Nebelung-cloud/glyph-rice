import QtQuick
import Quickshell.Bluetooth
import qs
import qs.components
import "../prefs"

// bluetooth: on the left paired and unknown devices nearby (scans while the section is open), on the right the selected one — battery, name (can be changed),
// trust, block, connect/disconnect, pair, forget
Sheet {
    id: root
    // trust only once pairing succeeded: a cancelled pairing would leave a stranger's device trusted, free to connect in (as quick/Picker)
    property var pend: null
    Connections {
        target: root.pend
        function onPairedChanged() { if (root.pend.paired) { root.pend.trusted = true; root.pend = null; } }
    }
    property bool live
    caption: `bluetooth · ${bt ? bt.name : "no adapter"}`

    readonly property var bt: Bluetooth.defaultAdapter
    readonly property bool btOn: bt?.enabled ?? false
    Binding { when: root.live && root.btOn; target: root.bt; property: "discovering"; value: true }

    readonly property var all: !btOn ? [] : bt.devices.values
    readonly property var paired: all.filter(d => d.paired).sort((a, b) => b.connected - a.connected)
    // nameless ones (just an address) — airwave noise
    readonly property var near: all.filter(d => !d.paired && d.deviceName)

    function icon(i) {
        return /audio|head/.test(i) ? "\u{F02CB}" : /mouse/.test(i) ? "\u{F037D}" : /keyboard/.test(i) ? "\u{F030C}" : /phone/.test(i) ? "\u{F03F2}" : "\u{F00AF}";
    }
    function status(d) {
        return (d.pairing ? "pairing" : d.state === BluetoothDeviceState.Connecting ? "connecting" : d.state === BluetoothDeviceState.Disconnecting ? "disconnecting"
            : d.connected ? "connected" : d.paired ? "paired" : "new") + (d.batteryAvailable ? ` · ${Math.round(d.battery * 100)}%` : "");
    }
    function busy(d) { return d.pairing || d.state === BluetoothDeviceState.Connecting || d.state === BluetoothDeviceState.Disconnecting; }

    // the inspector for one device: status, battery, actions; paired ones also get a name, trust and block. → on the row enters it
    // stable row lists (Keep): discovery changes the device list all the time
    Keep { id: pairedK; src: root.paired.map(d => d.address) }
    Keep { id: nearK; src: root.near.map(d => d.address) }
    readonly property var dev: hot?.d ?? null
    readonly property Component card: Component {
        Column {
            id: card
            readonly property var d: root.dev
            width: 480
            spacing: 16
            Lb { text: card.d ? `${root.status(card.d)} · ${card.d.address}` : "" }
            Row {
                visible: !!card.d?.batteryAvailable
                spacing: 10
                Num { id: batN; text: Math.round((card.d?.battery ?? 0) * 100); font.pixelSize: 72 }
                Num { anchors.baseline: batN.baseline; text: "%"; font.pixelSize: 32; color: Theme.mute }
            }
            Flow {
                width: parent.width
                spacing: 14
                Act { visible: !!card.d && card.d.paired && !card.d.connected; icon: "\u{F00B1}"; text: "connect"; onHit: card.d.connect() }
                Act { visible: !!card.d?.connected; icon: "\u{F00B3}"; text: "disconnect"; onHit: card.d.disconnect() }
                Act { visible: !!card.d && !card.d.paired && !card.d.pairing; icon: "\u{F00B1}"; text: "pair"; onHit: { root.pend = card.d; card.d.pair(); } }
                Act { visible: !!card.d?.pairing; icon: "\u{F0156}"; text: "cancel"; onHit: card.d.cancelPair() }
                Act { visible: !!card.d?.paired; icon: "\u{F0A7A}"; text: "forget"; onHit: card.d.forget() }
            }
            Column {
                visible: !!card.d?.paired
                spacing: 12
                Field { label: "name"; hint: "↵ to rename"; text: card.d?.name ?? ""; onAccepted: if (card.d && text.trim()) card.d.name = text.trim() }
                Toggle { text: "trusted · connects on its own"; on: card.d?.trusted ?? false; onFlip: card.d.trusted = !card.d.trusted }
                Toggle { text: "blocked · never connects"; on: card.d?.blocked ?? false; onFlip: card.d.blocked = !card.d.blocked }
            }
        }
    }

    Lb { topPadding: 8; bottomPadding: 4; text: "bluetooth" }
    Opt {
        title: "Bluetooth"
        hint: !root.bt ? "No Bluetooth adapter found." : "Wireless headphones, mice, keyboards, phones."
        about: "Turning it off disconnects every device and saves a little battery."
        value: root.btOn ? "on" : "off"
        Switch { on: root.btOn; onFlip: if (root.bt) root.bt.enabled = !root.bt.enabled }
    }
    Opt {
        visible: root.btOn
        title: "Visible to others"
        hint: "Let phones and computers find this one."
        about: "Only needed when another device pairs with this computer. Devices you pair from here don't need it."
        value: root.bt?.discoverable ? "on" : "off"
        Switch { on: root.bt?.discoverable ?? false; onFlip: root.bt.discoverable = !root.bt.discoverable }
    }

    Lb { visible: root.btOn; topPadding: 40; bottomPadding: 4; text: `paired · ${pairedK.out.length} · → for actions` }
    Repeater {
        model: pairedK.out
        Opt {
            required property string modelData
            readonly property var d: root.all.find(x => x.address === modelData) ?? null
            title: d ? d.name || d.address : ""
            hint: d ? root.status(d) : ""
            about: "A device you paired before. It reconnects when trusted and in range."
            value: d?.connected ? "connected" : "paired"
            preview: root.card
        }
    }
    Lb { visible: root.btOn; topPadding: 40; bottomPadding: 4; text: nearK.out.length ? `nearby · ${nearK.out.length} · → to pair` : "nearby · searching…" }
    Repeater {
        model: nearK.out
        Opt {
            required property string modelData
            readonly property var d: root.all.find(x => x.address === modelData) ?? null
            title: d ? d.name || d.address : ""
            hint: d ? root.status(d) : ""
            about: "A device in range that isn't paired. Put it in pairing mode, then pair it here."
            value: "new"
            preview: root.card
        }
    }
}
