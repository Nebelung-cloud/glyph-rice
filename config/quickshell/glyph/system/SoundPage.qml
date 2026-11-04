import QtQuick
import Quickshell.Services.Pipewire
import qs
import qs.components

// sound: where to output and where to listen from (a click — the default device), volume and balance, on the right — the volume of each
// app that's playing
Page {
    id: root
    property bool live
    caption: `sound · ${Pipewire.defaultAudioSink?.description ?? "no output"}`

    readonly property var nodes: Pipewire.nodes.values.filter(n => n.audio)
    readonly property var outs: nodes.filter(n => n.isSink && !n.isStream)
    readonly property var ins: nodes.filter(n => !n.isSink && !n.isStream)
    readonly property var apps: nodes.filter(n => n.isSink && n.isStream)
    // a node's volume is visible only while it's tracked
    PwObjectTracker { objects: root.live ? root.nodes : [] }

    // a live level, only while the page is on screen: no node — no capture stream. Peak is ∛amplitude, so −60…0 dB → 1 + log10(peak). It jumps
    // up and falls back slowly on the timer so a word stays readable: in silence peak sits at 0 and peakChanged never fires.
    // From Nebelung-cloud/glyph-rice dev (prefs/Audio.qml)
    component Meter: Row {
        id: meter
        property var node
        spacing: 7
        leftPadding: 8
        PwNodePeakMonitor { id: peak; node: root.live ? meter.node : null; onNodeChanged: meter.lv = 0 }
        readonly property real at: Math.max(0, Math.min(1, 1 + Math.log10(peak.peak)))
        property real lv: 0
        onAtChanged: lv = Math.max(lv, at)
        Timer { interval: 33; repeat: true; running: root.live && meter.lv > 0; onTriggered: meter.lv = Math.max(meter.at, meter.lv - 0.03) }
        Repeater {
            model: 24
            Rectangle {
                required property int index
                width: 7
                height: 7
                radius: 3.5
                // the last two — close to clipping
                color: meter.lv * 24 <= index ? Theme.s3 : index >= 22 ? Theme.red : Theme.fg
            }
        }
    }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var src: Pipewire.defaultAudioSource
    function label(n) { return n.description || n.nickname || n.name; }
    function setVol(n, v) {
        n.audio.muted = false;
        n.audio.volume = v;
    }

    // balance −1…1 from two channels; volume — the louder of them.
    // shortcut: we treat the channels as [left, right]; 5.1 gets no balance — if needed, map by audio.channels
    readonly property var vols: sink?.audio?.volumes ?? []
    readonly property real bal: vols.length === 2 && Math.max(vols[0], vols[1]) > 0 ? (vols[1] - vols[0]) / Math.max(vols[0], vols[1]) : 0
    function setBal(x) {
        let b = x * 2 - 1;
        if (Math.abs(b) < 0.04) b = 0; // snaps to the middle
        const v = Math.max(vols[0], vols[1]);
        sink.audio.volumes = [v * (b > 0 ? 1 - b : 1), v * (b < 0 ? 1 + b : 1)];
    }

    Row {
        spacing: 50

        Column {
            width: 480
            spacing: 4
            Lb { x: 8; bottomPadding: 6; text: `output · ${root.outs.length}` }
            Repeater {
                model: root.outs
                Line {
                    required property var modelData
                    icon: "\u{F04C3}"
                    title: root.label(modelData)
                    on: modelData === root.sink
                    picked: on
                    sub: on ? "in use" : ""
                    onHit: Pipewire.preferredDefaultAudioSink = modelData
                }
            }
            Item { width: 1; height: 10 }
            Meter { node: root.sink }
            Item { width: 1; height: 6 }
            Level {
                visible: !!root.sink?.audio
                icon: root.sink?.audio?.muted ? "\u{F075F}" : "\u{F057E}"
                muted: root.sink?.audio?.muted ?? false
                value: root.sink?.audio?.volume ?? 0
                onMoved: v => root.setVol(root.sink, v)
                onIconHit: root.sink.audio.muted = !root.sink.audio.muted
            }
            Item { width: 1; height: 6 }
            Level {
                visible: root.vols.length === 2
                icon: "\u{F0A1F}"
                value: (root.bal + 1) / 2
                fmt: v => { const b = Math.round((v * 2 - 1) * 100); return b < 0 ? `L ${-b}` : b > 0 ? `R ${b}` : "C"; }
                onMoved: v => root.setBal(v)
            }

            Lb { x: 8; topPadding: 30; bottomPadding: 6; text: `input · ${root.ins.length}` }
            Repeater {
                model: root.ins
                Line {
                    required property var modelData
                    icon: "\u{F036C}"
                    title: root.label(modelData)
                    on: modelData === root.src
                    picked: on
                    sub: on ? "in use" : ""
                    onHit: Pipewire.preferredDefaultAudioSource = modelData
                }
            }
            Item { width: 1; height: 10 }
            Meter { node: root.src }
            Item { width: 1; height: 6 }
            Level {
                visible: !!root.src?.audio
                icon: root.src?.audio?.muted ? "\u{F036D}" : "\u{F036C}"
                muted: root.src?.audio?.muted ?? false
                value: root.src?.audio?.volume ?? 0
                onMoved: v => root.setVol(root.src, v)
                onIconHit: root.src.audio.muted = !root.src.audio.muted
            }
        }

        Column {
            width: 420
            spacing: 10
            Lb { x: 8; bottomPadding: 6; text: root.apps.length ? `apps · ${root.apps.length}` : "apps · nothing playing" }
            Repeater {
                model: root.apps
                Column {
                    id: app
                    required property var modelData
                    width: parent.width
                    spacing: 6
                    Text {
                        x: 8
                        width: parent.width - 16
                        elide: Text.ElideRight
                        text: app.modelData.properties["application.name"] || root.label(app.modelData)
                        font { family: Theme.ui; pixelSize: 15; weight: Font.DemiBold }
                        color: Theme.fg
                    }
                    Level {
                        width: parent.width
                        icon: app.modelData.audio.muted ? "\u{F075F}" : "\u{F057E}"
                        muted: app.modelData.audio.muted
                        value: app.modelData.audio.volume
                        onMoved: v => root.setVol(app.modelData, v)
                        onIconHit: app.modelData.audio.muted = !app.modelData.audio.muted
                    }
                }
            }
        }
    }
}
