import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs
import qs.components

// Glyph: the screen edges as the LEDs on the back of the phone, instead of an OSD and popups in the middle of the screen.
// At the top — a flash on a notification (red for critical ones) and the «island» with it, on the right — volume/brightness bottom to top,
// at the bottom — the progress of long tasks (notifications with a hint value) or the focus timer (Focus). They fade after 3 s
Scope {
    id: root

    // ---- right: volume and brightness ----
    property string kind: "vol"
    property real value: 0
    property bool armed: false // the first values at startup aren't shown
    property bool volShown: false // lit for 3 s after a change: at the right edge or as a pill in the island (live)
    Timer { running: true; interval: 1500; onTriggered: root.armed = true }
    function level(k, v) {
        if (!armed || !Theme.state.edges) return;
        kind = k;
        value = v;
        volShown = true;
        sideT.restart();
    }
    Connections {
        target: Sys.sink?.audio ?? null
        function onVolumeChanged() { root.level("vol", Sys.muted ? 0 : Sys.vol); }
        function onMutedChanged() { root.level("vol", Sys.muted ? 0 : Sys.vol); }
    }
    Connections {
        target: Sys
        function onBriChanged() { root.level("bri", Sys.bri); }
    }
    Timer { id: sideT; interval: 3000; onTriggered: root.volShown = false }

    // ---- where the lights glow: at the edges (by default) or as a pill in the island at the top — Theme.state.glyphLights. A bar on the right takes
    // the right edge, then volume/brightness are always in the island. Volume outranks progress: it's for 3 s, progress can wait ----
    readonly property bool volIsland: Theme.state.glyphLights === 1 || Theme.barRight
    readonly property bool progIsland: Theme.state.glyphLights === 1
    readonly property bool liveVol: root.volShown && root.volIsland
    readonly property bool liveProg: root.busy && root.progIsland && !root.liveVol
    readonly property bool live: Theme.state.edges && (root.liveVol || root.liveProg)
    property real lt: live ? 1 : 0
    Behavior on lt { NumberAnimation { duration: root.live ? 600 : 400; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }

    PanelWindow {
        visible: root.lt > 0
        anchors.top: true
        implicitWidth: Math.ceil(600 * Theme.s)
        implicitHeight: Math.ceil(96 * Theme.s)
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "glyph-live"

        Stage {
            // the pill drops and spreads out, like the island's cards; the content appears last
            Rectangle {
                width: 150 + 330 * root.lt
                height: 60
                x: (600 - width) / 2
                y: 24 - 24 * (1 - root.lt)
                opacity: Math.min(1, root.lt * 2)
                radius: 30
                color: Theme.s1
                border { width: 1; color: root.flash && !root.flash.ok && !root.job && root.liveProg ? Theme.red : Theme.fg }

                Row {
                    anchors.centerIn: parent
                    spacing: 14
                    opacity: Math.max(0, (root.lt - 0.6) / 0.4)
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.liveVol ? (root.kind === "bri" ? "\u{F00E0}" : Sys.muted ? "\u{F075F}" : "\u{F057E}") : root.job ? "\u{F018D}" : "\u{F01DA}"
                    }
                    Lb {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.liveProg && !!text
                        width: Math.min(implicitWidth, 150)
                        elide: Text.ElideRight
                        text: root.job?.label ?? root.task?.summary ?? ""
                        color: Theme.fg
                    }
                    Lit {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 160
                        height: 5
                        n: 16
                        f: root.liveVol ? root.value : root.progress
                        from: root.liveProg && root.job && root.job.f < 0 ? Math.floor(root.sweep * 16 / 40) : 0
                        on: root.flash && !root.flash.ok && !root.job && root.liveProg ? Theme.red : Theme.fg
                    }
                    Num {
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: 26
                        text: root.liveVol ? Math.round(root.value * 100)
                            : root.job && root.job.f < 0 ? root.dur(root.now - root.job.t0)
                            : Math.round(root.progress * 100) + "%"
                    }
                }
            }
        }
    }

    // ---- top: a new notification — a flash of the strip and a card in the island's stack ----
    property var note: null // the latest one, for the flash
    // the stack: snapshots of the fields (the notification can be closed while the card leaves — the object will be gone), the object itself — in refs for the action
    ListModel { id: stack }
    property var refs: ({})
    property int seq: 0
    readonly property int most: 4
    // a card into the stack: c — { app, summary, body, icon (icon theme), glyph (nerd font), crit }; ref — the notification, for the action
    function push(c, ref) {
        root.note = { urgency: c.crit ? NotificationUrgency.Critical : NotificationUrgency.Normal };
        noteT.restart();
        const key = String(++root.seq);
        if (ref) root.refs[key] = ref;
        stack.insert(0, Object.assign({ key, app: "", summary: "", body: "", icon: "", glyph: "", crit: false, leaving: false }, c));
        // more than most — the oldest living one leaves
        let live = 0;
        for (let i = 0; i < stack.count; i++) if (!stack.get(i).leaving && ++live > root.most) stack.setProperty(i, "leaving", true);
    }
    Connections {
        target: Notes
        function onArrived(n) {
            root.push({ app: n.appName || "app", summary: n.summary ?? "", body: n.body ?? "", icon: n.appIcon ?? "",
                        crit: n.urgency === NotificationUrgency.Critical }, n);
        }
    }

    // ---- power: charging plugged in/pulled, fully charged, running low (15% — warn, 5% — in red). As a card in the island,
    // bypassing the notification history. armed — not at startup ----
    readonly property var bat: UPower.displayDevice
    readonly property int pct: Math.round((bat?.percentage ?? 0) * 100)
    property int warned: 100
    function hm(s) { const m = Math.round(s / 60); return m >= 60 ? `${Math.floor(m / 60)} h ${m % 60} m` : `${m} m`; }
    function power(summary, glyph, crit, time) {
        if (root.armed && root.bat?.isLaptopBattery) root.push({ app: "power", summary, body: `${root.pct}%` + (time ? ` · ${time}` : ""), glyph, crit: !!crit });
    }
    Connections {
        target: UPower
        function onOnBatteryChanged() {
            root.warned = 100;
            if (UPower.onBattery) root.power("On battery", "\u{F0079}", false, root.bat.timeToEmpty ? `${root.hm(root.bat.timeToEmpty)} left` : "");
            else root.power("Charging", "\u{F0084}", false, root.bat.timeToFull ? `full in ${root.hm(root.bat.timeToFull)}` : "");
        }
    }
    Connections {
        target: root.bat
        function onStateChanged() { if (root.bat.state === UPowerDeviceState.FullyCharged && !UPower.onBattery) root.power("Fully charged", "\u{F0079}"); }
        function onPercentageChanged() {
            if (!UPower.onBattery) return;
            if (root.pct <= 5 && root.warned > 5) { root.warned = 5; root.power("Battery critical", "\u{F0083}", true, "plug in now"); }
            else if (root.pct <= 15 && root.warned > 15) { root.warned = 15; root.power("Battery low", "\u{F0083}", false, "plug in soon"); }
        }
    }
    function dismiss(key) { for (let i = 0; i < stack.count; i++) if (stack.get(i).key === key) return stack.setProperty(i, "leaving", true); }
    function forget(key) {
        delete refs[key];
        for (let i = 0; i < stack.count; i++) if (stack.get(i).key === key) return stack.remove(i);
    }
    Timer { id: noteT; interval: 3000; onTriggered: root.note = null }
    readonly property bool crit: note?.urgency === NotificationUrgency.Critical

    Edge {
        id: top
        shown: !!root.note && Theme.state.edges
        anchors.top: true
        margins.top: Theme.state.barAt === "top" ? Math.ceil(78 * Theme.s) : 0 // under the bar
        implicitWidth: Math.ceil(640 * Theme.s)
        implicitHeight: Math.ceil(30 * Theme.s)
        Seg {
            x: 20
            y: 4
            width: 600
            height: 4
            n: 12
            f: 1
            on: root.crit ? Theme.red : Theme.fg
            layer.enabled: true
            layer.effect: Glow {}
            SequentialAnimation on opacity {
                running: top.shown
                loops: Animation.Infinite
                NumberAnimation { from: 0.15; to: 1; duration: 720; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1; to: 0.15; duration: 1680; easing.type: Easing.InOutSine }
            }
        }
    }

    // the island: a stack of cards at the top center, new ones on top. A white outline (critical — red), an icon in a circle, a red dot.
    // Each one — like a dynamic island: drops as a pill, spreads into a card, the text appears last; goes back, and its place
    // collapses — the ones below move up. Each has its own 4 s life, hovering the stack keeps them all.
    // A window of constant size (for most cards), the mouse is caught only by the stack itself
    PanelWindow {
        visible: stack.count > 0
        anchors.top: true
        margins.top: Theme.state.barAt === "top" ? Math.ceil(78 * Theme.s) : 0 // under the bar
        implicitWidth: Math.ceil(600 * Theme.s)
        implicitHeight: Math.ceil((24 + root.most * 132) * Theme.s)
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region { item: col }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "glyph-island"

        Stage {
            Column {
                id: col
                y: 24 + 76 * root.lt // under the lights pill while it's lit
                width: 600
                HoverHandler { id: hov }

                Repeater {
                    model: stack

                    Item {
                        id: c
                        required property int index
                        required property string key
                        required property string app
                        required property string summary
                        required property string body
                        required property string icon
                        required property string glyph
                        required property bool crit
                        required property bool leaving

                        // p 0…1 linear, each phase has its own ease-out-quart (like glide)
                        property real p: 0
                        Component.onCompleted: p = Qt.binding(() => leaving ? 0 : 1)
                        Behavior on p { NumberAnimation { duration: c.leaving ? 450 : 700 } }
                        onPChanged: if (leaving && p <= 0) Qt.callLater(root.forget, key)
                        function ph(a, b) { const x = Math.max(0, Math.min(1, (p - a) / (b - a))); return 1 - Math.pow(1 - x, 4); }
                        readonly property real drop: ph(0, 0.3)   // the pill drops
                        readonly property real grow: ph(0.25, 0.8) // and spreads into a card
                        readonly property real full: Math.max(86, txt.height + 32)

                        width: 600
                        height: (40 + (full - 40) * grow + 12) * drop // the place in the stack grows and collapses with the card
                        Timer { running: !c.leaving && !hov.hovered; interval: 4000; onTriggered: root.dismiss(c.key) }

                        Rectangle {
                            width: 140 + (600 - 140) * c.grow
                            height: 40 + (c.full - 40) * c.grow
                            x: (600 - width) / 2
                            y: -24 * (1 - c.drop)
                            opacity: c.drop
                            radius: Theme.corner(Math.min(34, height / 2))
                            clip: true
                            color: Theme.s1
                            border { width: 1; color: c.crit ? Theme.red : Theme.fg }

                            // the content — at full size in the center: the text width doesn't change while the card grows
                            Item {
                                anchors.centerIn: parent
                                width: 600
                                height: c.full
                                opacity: c.ph(0.7, 1)

                                Rectangle {
                                    id: ic
                                    x: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 54
                                    height: 54
                                    radius: 27
                                    color: Theme.s2
                                    Icon { anchors.centerIn: parent; visible: !img.visible; text: c.glyph || "\u{F009A}"; font.pixelSize: 24 }
                                    Image {
                                        id: img
                                        anchors.centerIn: parent
                                        width: 28
                                        height: 28
                                        visible: status === Image.Ready
                                        source: c.icon ? Quickshell.iconPath(c.icon, true) : ""
                                        sourceSize: Qt.size(28, 28)
                                        layer.enabled: true
                                        layer.effect: Dm { step: 2 }
                                    }
                                }
                                Column {
                                    id: txt
                                    anchors { left: ic.right; leftMargin: 16; right: dot.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
                                    Lb { width: parent.width; elide: Text.ElideRight; text: `${c.app} · now` }
                                    Text {
                                        width: parent.width
                                        topPadding: 2
                                        elide: Text.ElideRight
                                        text: c.summary
                                        textFormat: Text.PlainText
                                        font { family: Theme.ui; pixelSize: 17; weight: Font.DemiBold }
                                        color: Theme.fg
                                    }
                                    Text {
                                        width: parent.width
                                        visible: !!c.body
                                        elide: Text.ElideRight
                                        maximumLineCount: 2
                                        wrapMode: Text.Wrap
                                        textFormat: Text.PlainText
                                        text: c.body
                                        font { family: Theme.ui; pixelSize: 14 }
                                        color: Theme.grey
                                    }
                                }
                                // the accent dot — only on the newest one: there's one accent thing on screen
                                Rectangle { id: dot; visible: c.index === 0; anchors { right: parent.right; rightMargin: 22; verticalCenter: parent.verticalCenter } width: 12; height: 12; radius: 6; color: Theme.accent }
                            }

                            // a click — the default action; the card leaves, it stays in the history. The notification may already be closed —
                            // then the object is an empty wrapper with no actions
                            TapHandler {
                                onTapped: {
                                    root.refs[c.key]?.actions?.find(a => a.identifier === "default")?.invoke();
                                    root.dismiss(c.key);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- right ----
    Edge {
        id: side
        shown: root.volShown && !root.volIsland
        anchors.right: true
        implicitWidth: Math.ceil(160 * Theme.s)
        implicitHeight: Math.ceil(520 * Theme.s)
        Lit {
            x: 160 - 5 - 5
            y: 10
            width: 5
            height: 500
            n: 20
            vertical: true
            f: root.value
        }
        Tag {
            vertical: true // on a vertical strip the capsule stands upright too: the icon above the number
            anchors { right: parent.right; rightMargin: 26; verticalCenter: parent.verticalCenter }
            Icon { text: root.kind === "bri" ? "\u{F00E0}" : Sys.muted ? "\u{F075F}" : "\u{F057E}" }
            Num { text: Math.round(root.value * 100); font.pixelSize: 30 }
        }
    }

    // ---- bottom: progress (Glyph Progress). By priority: a terminal/script task over IPC, a notification with a hint value,
    // a running focus timer (as one strip, without a capsule: it hangs around for tens of minutes).
    // IPC: qs ipc -p ~/.config/quickshell/glyph call progress start <id> <label> · set <id> <0…100> · end <id> <code>.
    // The terminal sends start/end itself (~/.config/fish/conf.d/glyph-progress.fish). The strip lights up after 5 s — short
    // commands don't blink; without a percentage a light runs along it. The end — a full flash (an error — in red), and one that ran 10 s or
    // longer also as a card in the island
    property var jobs: ({}) // id → { label, f (-1 — no percentage), t0 }
    property real now: Date.now()
    property var flash: null // { ok } — the end flash
    property int sweep: -4 // the head of the running light
    readonly property var job: {
        let best = null;
        for (const id in jobs) {
            const j = jobs[id];
            if (now - j.t0 >= 5000 && (!best || j.t0 > best.t0)) best = j;
        }
        return best;
    }
    function dur(ms) { const s = Math.floor(ms / 1000); return s < 60 ? `${s}s` : `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`; }
    Timer { running: Object.keys(root.jobs).length > 0; interval: 1000; repeat: true; onTriggered: root.now = Date.now() }
    Timer { running: !!root.job && root.job.f < 0 && Theme.state.edges; interval: 60; repeat: true; onTriggered: root.sweep = root.sweep >= 40 ? -4 : root.sweep + 1 }
    Timer { id: flashT; interval: 1500; onTriggered: root.flash = null }

    IpcHandler {
        target: "progress"
        function start(id: string, label: string): void {
            root.now = Date.now();
            root.jobs = Object.assign({}, root.jobs, { [id]: { label, f: -1, t0: root.now } });
        }
        function set(id: string, value: real): void {
            const j = root.jobs[id];
            if (j) root.jobs = Object.assign({}, root.jobs, { [id]: Object.assign({}, j, { f: Math.max(0, Math.min(1, value / 100)) }) });
        }
        function end(id: string, code: int): void {
            const j = root.jobs[id];
            if (!j) return;
            const rest = Object.assign({}, root.jobs);
            delete rest[id];
            root.jobs = rest;
            const ms = Date.now() - j.t0;
            if (ms < 5000 || !Theme.state.edges) return; // the strip never lit up — nothing to turn off
            root.flash = { ok: code === 0 };
            flashT.restart();
            if (ms >= 10000 && !Theme.state.dnd)
                root.push({ app: "terminal", summary: j.label, glyph: code === 0 ? "\u{F012C}" : "\u{F0156}",
                            body: code === 0 ? `done · ${root.dur(ms)}` : `failed · exit ${code} · ${root.dur(ms)}` });
        }
    }

    readonly property var task: Notes.task
    readonly property bool busy: !!job || !!flash || !!task || Focus.running
    readonly property real progress: job ? (job.f < 0 ? 4 / 40 : job.f) : flash ? 1
                                   : task ? Math.max(0, Math.min(100, task.hints.value ?? 0)) / 100 : Focus.f
    Connections {
        target: Focus
        function onDone() { root.push({ app: "focus", summary: "Focus done", body: `${Focus.minutes} min`, glyph: "\u{F13AB}" }); }
    }
    Edge {
        shown: root.busy && Theme.state.edges && !root.progIsland
        anchors.bottom: true
        implicitWidth: Math.ceil(1100 * Theme.s)
        implicitHeight: Math.ceil(110 * Theme.s)
        Lit {
            x: 10
            y: 110 - 5 - 5
            width: 1080
            height: 5
            n: 40
            f: root.progress
            from: root.job && root.job.f < 0 ? root.sweep : 0
            on: root.flash && !root.flash.ok && !root.job ? Theme.red : Theme.fg
        }
        Tag {
            visible: !!root.job || !!root.task
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 26 }
            Icon { text: root.job ? "\u{F018D}" : "\u{F01DA}" }
            Lb { width: Math.min(implicitWidth, 560); elide: Text.ElideRight; text: root.job?.label ?? root.task?.summary ?? ""; color: Theme.fg }
            Num {
                text: !root.job ? Math.round(root.progress * 100) + "%" : root.job.f < 0 ? root.dur(root.now - root.job.t0) : Math.round(root.job.f * 100) + "%"
                font.pixelSize: 26
            }
        }
    }

    // a strip at the edge: click-through, drawn in layout pixels
    component Edge: PanelWindow {
        property bool shown
        default property alias content: st.data
        visible: shown
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "glyph-edge"
        Stage { id: st }
    }
    // a value capsule next to the strip; vertical — the content as a column
    component Tag: Rectangle {
        default property alias content: box.data
        property bool vertical
        width: vertical ? Math.max(52, box.width + 24) : box.width + 32
        height: vertical ? box.height + 36 : 52
        radius: Theme.corner(Math.min(width, height) / 2)
        color: Theme.s1
        border { width: 1; color: Theme.s2 }
        Grid {
            id: box
            anchors.centerIn: parent
            columns: parent.vertical ? 1 : 99
            spacing: parent.vertical ? 10 : 12
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter
        }
    }
    // the glow of the lit segments — the only «shadow» in the whole shell
    component Glow: MultiEffect {
        shadowEnabled: true
        shadowColor: Theme.glow
        shadowBlur: 0.7
        blurMax: 20
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
    }
}
