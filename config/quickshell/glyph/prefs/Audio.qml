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

    // hardware only (no app streams), grouped by card: "SSL 2+" + "Line Outputs 1/L + 2/R".
    // A duplex node (a virtual mic-and-speaker) is a sink and a source at once — it goes in both lists
    function devs(out) {
        return Pipewire.nodes.values.filter(n => n.audio && !n.isStream && (out ? n.isSink : n.type & PwNodeType.Source))
            .map(n => Object.assign({ node: n }, split(n)))
            .sort((a, b) => a.card.localeCompare(b.card) || a.port.localeCompare(b.port));
    }
    function split(n) {
        const d = n.description || n.name, nick = (n.nickname || "").replace(/ #\d+$/, "");
        if (nick && d.startsWith(nick + " ")) return { card: nick, port: d.slice(nick.length + 1) };
        // HDMI: "GA102 … Digital Stereo (HDMI 2) [ED340CU S3]" — the monitor is the name
        const bus = d.match(/\(((?:HDMI|DP)[^)]*)\)/);
        if (nick && d.includes(`[${nick}]`)) return { card: bus ? bus[1] : "", port: nick };
        return { card: "", port: d };
    }

    spacing: 70

    Side { out: true; label: "output"; node: Sys.sink; list: root.outs } // Sys tracks both
    Side { out: false; label: "input"; node: Sys.mic; list: root.ins }

    component Side: Column {
        id: side
        required property bool out
        required property string label
        required property var node // the default device
        required property var list
        readonly property int cur: list.findIndex(d => d.node === node)
        function pick(i) {
            const n = list[(i + list.length) % list.length]?.node;
            if (!n) return;
            if (out) Pipewire.preferredDefaultAudioSink = n;
            else Pipewire.preferredDefaultAudioSource = n;
        }

        width: 470
        spacing: 26

        // no node while hidden — no capture stream, whichever binding Qt sets first
        PwNodePeakMonitor { id: peak; node: root.live ? side.node : null; onNodeChanged: side.lv = 0 }
        // peak is ∛amplitude, so dB = 60·log10(peak); the row shows -60…0 dB → 1 + log10(peak). Above 1 when the node's
        // volume is software (quickshell divides by it). Jumps up on a peak, falls back slowly on the timer so a word stays
        // readable: in silence peak sits at 0 and peakChanged never fires
        readonly property real at: Math.max(0, Math.min(1, 1 + Math.log10(peak.peak)))
        property real lv: 0
        onAtChanged: lv = Math.max(lv, at)
        Timer { interval: 33; repeat: true; running: root.live && side.lv > 0; onTriggered: side.lv = Math.max(side.at, side.lv - 0.03) }

        Row {
            spacing: 36
            Dial {
                enabled: !!side.node?.audio
                size: 200
                n: 48
                live: true
                label: side.label
                value: Math.round((side.node?.audio?.volume ?? 0) * 100)
                onMoved: v => {
                    if (side.out) side.node.audio.muted = false; // the mic stays muted: its gain isn't a reason to open it
                    side.node.audio.volume = v / 100;
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 22
                Toggle {
                    enabled: !!side.node?.audio
                    width: 200
                    text: "mute"
                    on: side.node?.audio?.muted ?? false
                    onFlip: side.node.audio.muted = !side.node.audio.muted
                }
                // level: 12 dots — 10 white, then 2 red from -7.5 dB, close to clipping
                Column {
                    spacing: 12
                    Row {
                        spacing: 7
                        Seg { n: 10; spacing: 7; width: 163; height: 10; f: side.lv * 1.2 }
                        Seg { n: 2; spacing: 7; width: 27; height: 10; f: side.lv * 6 - 5; on: Theme.red }
                    }
                    Lb { text: side.node?.audio?.muted ? "level · muted" : "level"; px: 10 }
                }
            }
        }

        // devices: a vertical Pick — the white pill slides to the default. Eight rows fit; more (virtual sinks, OBS,
        // loopbacks) scroll, or the list runs over the hints and off the canvas
        Rectangle {
            id: box
            width: side.width
            height: Math.min(8, Math.max(1, side.list.length)) * 56 + 12
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
            Flickable {
                id: rows
                anchors { fill: parent; topMargin: 6; bottomMargin: 6 }
                clip: true
                contentHeight: side.list.length * 56
                boundsBehavior: Flickable.StopAtBounds
                // ←→ or a new default off screen — scroll just enough to show it
                readonly property int cur: side.cur
                onCurChanged: if (cur >= 0) contentY = Math.max(Math.min(contentY, cur * 56), (cur + 1) * 56 - height)
                Rectangle {
                    visible: side.cur >= 0
                    x: 6
                    y: Math.max(side.cur, 0) * 56 // from -1 it shows up in place, not flying in from above
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
                        y: index * 56
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
                            elide: Text.ElideMiddle // long ALSA names differ at the end: "… (HDMI 2)"
                            text: dv.modelData.port
                            textFormat: Text.PlainText
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
}
