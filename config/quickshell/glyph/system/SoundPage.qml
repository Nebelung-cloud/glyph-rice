import QtQuick
import Quickshell.Services.Pipewire
import qs
import qs.components
import "../prefs"

// sound: where to output and where to listen from (a click — the default device), volume and balance, on the right — the volume of each
// app that's playing
Sheet {
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

    // stable row lists (Keep): every stream that starts or stops, even a notification sound, makes new arrays
    Keep { id: outK; src: root.outs.map(n => n.id) }
    Keep { id: inK; src: root.ins.map(n => n.id) }
    Keep { id: appK; src: root.apps.map(n => n.id) }
    function node(id) { return nodes.find(n => n.id === id) ?? null; }
    readonly property Component outLevel: Component { Meter { node: root.sink } }
    readonly property Component inLevel: Component { Meter { node: root.src } }

    Lb { topPadding: 8; bottomPadding: 4; text: `output · ${outK.out.length}` }
    Repeater {
        model: outK.out
        Opt {
            id: outRow
            required property int modelData
            readonly property var n: root.node(modelData)
            readonly property bool on: !!n && n === root.sink
            title: n ? root.label(n) : ""
            hint: on ? "Playing everything now." : "Speakers, headphones or a screen."
            about: "Where sound plays. Plugging in headphones may switch on its own; pick here to choose by hand."
            value: on ? "in use" : "—"
            preview: root.outLevel
            Act { icon: "\u{F04C3}"; text: outRow.on ? "in use" : "use"; onHit: Pipewire.preferredDefaultAudioSink = outRow.n }
        }
    }
    Opt {
        visible: !!root.sink?.audio
        wide: true
        title: "Volume"
        hint: "How loud the output is. The icon mutes."
        about: "The level dots on the right show what's playing right now; the red ones mean it's close to distorting."
        value: root.sink?.audio?.muted ? "muted" : `${Math.round((root.sink?.audio?.volume ?? 0) * 100)} %`
        preview: root.outLevel
        Level {
            icon: root.sink?.audio?.muted ? "\u{F075F}" : "\u{F057E}"
            muted: root.sink?.audio?.muted ?? false
            value: root.sink?.audio?.volume ?? 0
            onMoved: v => root.setVol(root.sink, v)
            onIconHit: root.sink.audio.muted = !root.sink.audio.muted
        }
    }
    Opt {
        visible: root.vols.length === 2
        wide: true
        title: "Balance"
        hint: "Shift the sound left or right."
        about: "C is centred. Useful when one ear or one speaker needs more."
        value: { const b = Math.round(root.bal * 100); return b < 0 ? `L ${-b}` : b > 0 ? `R ${b}` : "C"; }
        Level {
            icon: "\u{F0A1F}"
            value: (root.bal + 1) / 2
            fmt: v => { const b = Math.round((v * 2 - 1) * 100); return b < 0 ? `L ${-b}` : b > 0 ? `R ${b}` : "C"; }
            onMoved: v => root.setBal(v)
        }
    }

    Lb { topPadding: 40; bottomPadding: 4; text: `input · ${inK.out.length}` }
    Repeater {
        model: inK.out
        Opt {
            id: inRow
            required property int modelData
            readonly property var n: root.node(modelData)
            readonly property bool on: !!n && n === root.src
            title: n ? root.label(n) : ""
            hint: on ? "Apps hear this one." : "A microphone."
            about: "Which microphone calls and recordings use. Speak and watch the level on the right."
            value: on ? "in use" : "—"
            preview: root.inLevel
            Act { icon: "\u{F036C}"; text: inRow.on ? "in use" : "use"; onHit: Pipewire.preferredDefaultAudioSource = inRow.n }
        }
    }
    Opt {
        visible: !!root.src?.audio
        wide: true
        title: "Microphone volume"
        hint: "How loud you sound to others. The icon mutes."
        about: "Speak normally: the level should reach the middle, not the red dots at the end."
        value: root.src?.audio?.muted ? "muted" : `${Math.round((root.src?.audio?.volume ?? 0) * 100)} %`
        preview: root.inLevel
        Level {
            icon: root.src?.audio?.muted ? "\u{F036D}" : "\u{F036C}"
            muted: root.src?.audio?.muted ?? false
            value: root.src?.audio?.volume ?? 0
            onMoved: v => root.setVol(root.src, v)
            onIconHit: root.src.audio.muted = !root.src.audio.muted
        }
    }

    Lb { topPadding: 40; bottomPadding: 4; text: appK.out.length ? `apps · ${appK.out.length}` : "apps · nothing playing" }
    Repeater {
        model: appK.out
        Opt {
            id: app
            required property int modelData
            readonly property var n: root.node(modelData)
            visible: !!n?.audio
            wide: true
            title: n ? n.properties["application.name"] || root.label(n) : ""
            hint: "This app's own volume, on top of the output's."
            about: "Turn one app down without touching the rest, like music under a call."
            value: n?.audio?.muted ? "muted" : `${Math.round((n?.audio?.volume ?? 0) * 100)} %`
            Level {
                icon: app.n?.audio?.muted ? "\u{F075F}" : "\u{F057E}"
                muted: app.n?.audio?.muted ?? false
                value: app.n?.audio?.volume ?? 0
                onMoved: v => root.setVol(app.n, v)
                onIconHit: app.n.audio.muted = !app.n.audio.muted
            }
        }
    }
}
