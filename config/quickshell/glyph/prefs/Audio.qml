import QtQuick
import Quickshell.Services.Pipewire
import qs
import qs.components

// AUDIO page of prefs. Output and input side by side: a volume ring, mute, a live level row, then every
// device on the machine. The white pill is the default; click or ←→ moves it (Pipewire.preferredDefault*,
// which wireplumber remembers across reboots)
Row {
    id: root

    property bool live: true // the meters capture only while the page is on screen
    readonly property var outs: devs(true)
    readonly property var ins: devs(false)
    readonly property string caption: `audio · pipewire · ${outs.length} out · ${ins.length} in`

    // hardware only (no app streams), grouped by card: "SSL 2+" + "Line Outputs 1/L + 2/R"
    function devs(sink) {
        return Pipewire.nodes.values.filter(n => n.audio && !n.isStream && n.isSink === sink)
            .map(n => Object.assign({ node: n }, split(n)))
            .sort((a, b) => a.card.localeCompare(b.card) || a.port.localeCompare(b.port));
    }
    function split(n) {
        const d = n.description || n.name, nick = (n.nickname || "").replace(/ #\d+$/, "");
        if (nick && d.startsWith(nick + " ")) return { card: nick, port: d.slice(nick.length + 1) };
        // HDMI: "GA102 … Digital Stereo (HDMI) [ED340CU S3]" — the monitor is the name
        const bus = d.match(/\((\w+)\)/);
        if (nick && d.includes(`[${nick}]`)) return { card: bus ? bus[1] : "", port: nick };
        return { card: "", port: d };
    }

    spacing: 70

    Side { label: "output"; node: Pipewire.defaultAudioSink; list: root.outs }
    Side { label: "input"; node: Pipewire.defaultAudioSource; list: root.ins }

    component Side: Column {
        id: side
        required property string label
        required property var node // the default device
        required property var list
        readonly property int cur: list.findIndex(d => d.node === node)
        function pick(i) {
            const n = list[(i + list.length) % list.length]?.node;
            if (!n) return;
            if (n.isSink) Pipewire.preferredDefaultAudioSink = n;
            else Pipewire.preferredDefaultAudioSource = n;
        }

        width: 470
        spacing: 26

        PwObjectTracker { objects: [side.node] }
        PwNodePeakMonitor { id: peak; node: side.node; enabled: root.live && !!side.node }
        // peak is linear 0-1; the row shows -60…0 dB, falls back slowly so a word stays readable
        property real lv: 0
        Connections {
            target: peak
            function onPeakChanged() {
                const db = peak.peak > 0 ? 20 * Math.log10(peak.peak) : -100;
                side.lv = Math.max(Math.max(0, (db + 60) / 60), side.lv - 0.03);
            }
        }
        onNodeChanged: lv = 0

        Row {
            spacing: 36
            Dial {
                size: 200
                n: 48
                live: true
                label: side.label
                value: Math.round((side.node?.audio?.volume ?? 0) * 100)
                onMoved: v => {
                    if (!side.node?.audio) return;
                    side.node.audio.muted = false;
                    side.node.audio.volume = v / 100;
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 22
                Toggle {
                    width: 200
                    text: "mute"
                    on: side.node?.audio?.muted ?? false
                    onFlip: if (side.node?.audio) side.node.audio.muted = !side.node.audio.muted
                }
                // level: 12 dots, the last two red — that's -10 dB and up, close to clipping
                Column {
                    spacing: 12
                    Row {
                        spacing: 7
                        Repeater {
                            model: 12
                            Rectangle {
                                required property int index
                                readonly property bool lit: index < Math.round(side.lv * 12)
                                width: 10
                                height: 10
                                radius: 5
                                color: !lit ? Theme.s3 : index >= 10 ? Theme.red : Theme.fg
                            }
                        }
                    }
                    Lb { text: side.node?.audio?.muted ? "level · muted" : "level"; px: 10 }
                }
            }
        }

        // devices: a vertical Pick — the white pill slides to the default
        Rectangle {
            id: box
            width: side.width
            height: Math.max(1, side.list.length) * 56 + 12
            radius: Theme.corner(34)
            color: Theme.s1
            border { width: 1; color: box.activeFocus ? Theme.fg : Theme.s2 }
            activeFocusOnTab: true
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Left) side.pick(Math.max(side.cur, 0) - 1);
                else if (e.key === Qt.Key_Right || e.key === Qt.Key_Space) side.pick(side.cur + 1);
                else return;
                e.accepted = true;
            }

            Lb { visible: !side.list.length; anchors.centerIn: parent; text: "no devices"; px: 10 }
            Rectangle {
                visible: side.cur >= 0
                x: 6
                y: 6 + side.cur * 56
                width: box.width - 12
                height: 56
                radius: Theme.corner(28)
                color: Theme.fg
                Behavior on y { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
            }
            Repeater {
                model: side.list
                Item {
                    id: dv
                    required property var modelData
                    required property int index
                    readonly property bool on: index === side.cur
                    x: 6
                    y: 6 + index * 56
                    width: box.width - 12
                    height: 56

                    Rectangle {
                        x: 24
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8
                        height: 8
                        radius: 4
                        color: dv.on ? Theme.ink : Theme.s3
                    }
                    Text {
                        anchors { left: parent.left; leftMargin: 50; right: card.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
                        elide: Text.ElideRight
                        text: dv.modelData.port
                        font { family: Theme.ui; pixelSize: 19 }
                        color: dv.on ? Theme.ink : Theme.grey
                        Behavior on color { ColorAnimation { duration: Theme.t } }
                    }
                    Lb {
                        id: card
                        anchors { right: parent.right; rightMargin: 24; verticalCenter: parent.verticalCenter }
                        text: dv.modelData.card
                        px: 10
                        color: dv.on ? Theme.ink : Theme.mute
                    }
                    TapHandler {
                        onTapped: {
                            box.forceActiveFocus();
                            side.pick(dv.index);
                        }
                    }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }
            }
        }
    }
}
