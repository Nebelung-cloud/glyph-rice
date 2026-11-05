import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Wayland
import qs
import qs.components

// vpn: Super+P. Everything from Clash Verge, like the pact in demonshot: toggles, mode, nodes and ping — items of its own tray (verge stays in sync),
// the profile — from its profiles.yaml, traffic and connections — from the core's socket (mihomo).
// A 1040 panel in the center. On the left a ring of 60 dots — the tunnel: lit while System proxy or TUN is on, a red dot in the center — live.
// Under it the System/TUN pills, the mode chips, the profile. On the right the speed in Doto, traffic as a matrix, nodes with ping as segments; the selected one — white
PanelWindow {
    id: root

    // ---- verge: the tray ----
    readonly property var verge: Sys.verge
    // ponytail: tray items are found by their English labels (language: en in verge); another language — change the strings here
    function child(op, pre) { return op.children.values.find(e => e.text.startsWith(pre)) ?? null; }
    function checked(op, pre) { return child(op, pre)?.checkState === Qt.Checked; }
    QsMenuOpener { id: tray; menu: root.verge?.menu ?? null }
    QsMenuOpener { id: modes; menu: root.child(tray, "Outbound Modes") }
    QsMenuOpener { id: proxies; menu: root.child(tray, "Proxies") }
    QsMenuOpener { id: grp; menu: proxies.children.values.find(e => e.hasChildren) ?? null }

    readonly property bool sys: checked(tray, "System Proxy")
    readonly property bool tun: checked(tray, "TUN Mode")
    readonly property var modeNames: ["Rule", "Global", "Direct"]
    readonly property int mode: modeNames.findIndex(m => checked(modes, m))
    readonly property string group: (proxies.children.values.find(e => e.hasChildren)?.text ?? "proxy").toLowerCase()

    // a node from the tray item «TCP PL 🇵🇱⚡️-NODE🐸   | 48ms»: the country code from the flag, the name without the transport and emoji, the ping
    readonly property var transports: ["tcp", "xhttp", "ws", "grpc", "h2", "http", "httpupgrade", "splithttp", "quic", "kcp", "reality", "hy2", "tuic"]
    readonly property var builtin: ({ DIRECT: ["Direct", "no proxy"], REJECT: ["Reject", "blocked"] })
    function way(e) {
        const m = /^(.*?)\s*\|\s*(\S*?)\s*ms$/.exec(e.text), label = (m?.[1] ?? e.text).trim(), b = builtin[label];
        const flag = [...label].map(c => c.codePointAt(0)).filter(c => c >= 0x1F1E6 && c <= 0x1F1FF).map(c => String.fromCharCode(c - 0x1F1E6 + 65)).join("");
        const words = label.replace(/[^\x20-\x7E]/g, " ").split(/[\s\-_|·]+/).filter(Boolean);
        const cc = b ? "—" : flag || words.find(w => /^[A-Z]{2}$/.test(w)) || "··";
        const via = words.find(w => transports.includes(w.toLowerCase()))?.toLowerCase();
        const name = words.filter(w => w !== cc && !transports.includes(w.toLowerCase())).map(w => w[0] + w.slice(1).toLowerCase()).join(" ");
        return {
            entry: e, cc, on: e.checkState === Qt.Checked,
            name: b ? b[0] : name || label,
            sub: b ? b[1] : [via, ...(kinds[label] ?? [])].filter(Boolean).join(" · "),
            ms: b ? 0 : parseInt(m?.[2])
        };
    }
    readonly property var ways: grp.children.values.filter(e => !e.isSeparator && e.buttonType !== QsMenuButtonType.None).map(e => way(e))

    // click a tray item; several — one at a time: verge rebuilds the menu after each
    property var queue: []
    function press(label) {
        queue = queue.concat([label]);
        if (!presser.running) presser.start();
    }
    Timer {
        id: presser
        interval: 350
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const [l, ...rest] = root.queue;
            root.queue = rest;
            root.child(tray, l)?.triggered();
            if (!rest.length) stop();
        }
    }
    function go(i) { const w = ways[i]; if (w && !w.on) w.entry.triggered(); }
    function route(i) { child(modes, modeNames[i])?.triggered(); }
    property bool pinging: false
    function ping() { child(grp, "Test Latency")?.triggered(); pinging = true; pingT.restart(); }
    Timer { id: pingT; interval: 2500; onTriggered: root.pinging = false }

    // ---- the tunnel: System proxy or TUN. Turned off — both go dark, turned on — the ones that were on come back ----
    readonly property bool live: sys || tun
    property var kept: ["System Proxy", "TUN Mode"] // what to bring back on turning on
    property int want: -1                           // until verge catches up: 1 — turning on, 0 — turning off
    readonly property bool connected: want >= 0 ? want === 1 : live
    onLiveChanged: { want = -1; wall(); }
    Timer { id: wantT; interval: 5000; onTriggered: root.want = -1 } // verge stayed silent — show it as it is
    // not installed (it's an extra in install.sh): say so instead of offering a button that does nothing
    property bool hasVerge: true
    Process { running: true; command: ["sh", "-c", "command -v clash-verge"]; onExited: code => root.hasVerge = code === 0 }
    function flip() {
        if (!hasVerge) return;
        if (!verge) return Quickshell.execDetached(["clash-verge"]); // asleep — wake it
        if (connected) {
            kept = [sys && "System Proxy", tun && "TUN Mode"].filter(Boolean);
            kept.forEach(l => press(l));
            want = 0;
        } else {
            (kept.length ? kept : ["System Proxy", "TUN Mode"]).forEach(l => press(l));
            want = 1;
        }
        wantT.restart();
    }
    // ponytail: «since when» — since turning on with the shell alive; a tunnel brought up before startup counts from startup
    property date since: new Date()
    onConnectedChanged: if (connected) since = new Date()

    // a public network with a sign-in page: the tunnel won't let it through (dns-hijack, MATCH,PROXY) — turn it off and open the portal;
    // the network let us in (Full) — turn it back on. NM checks connectivity past the tunnel (bound to wlan0), so it sees the Portal honestly.
    // A tunnel that came up already behind a portal (verge starts after the shell) is taken down the same way; one turned on by hand after that is left alone
    property bool portal: false // the tunnel was dropped because of a portal — return it when the network lets us through
    function wall() {
        if (Networking.connectivity === NetworkConnectivity.Portal && live && !portal) {
            portal = true;
            flip();
            Quickshell.execDetached(["notify-send", "-a", "vpn", "Portal", "tunnel dropped until you sign in to the network"]);
        } else if (Networking.connectivity === NetworkConnectivity.Full && portal) {
            portal = false;
            if (!connected) flip();
        }
    }
    Connections {
        target: Networking
        function onConnectivityChanged() {
            root.wall();
            if (Networking.connectivity === NetworkConnectivity.Portal) gate.restart(); // the browser — once verge has already dropped the system proxy
        }
    }
    Timer { id: gate; interval: 1500; onTriggered: Qt.openUrlExternally("http://neverssl.com") }
    // after signing in NM rechecks connectivity with a growing interval of up to 5 minutes — we hurry it ourselves
    Timer { running: root.portal; interval: 5000; repeat: true; onTriggered: Networking.checkConnectivity() }

    // ---- verge: the profile (name, where from, when updated, how much used) ----
    readonly property string home: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/io.github.clash-verge-rev.clash-verge-rev"
    property var prof: ({})
    FileView {
        path: root.home + "/profiles.yaml"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.prof = root.parseProf(text())
    }
    // ponytail: yaml is read with regexps — verge writes profiles.yaml, its format is flat
    function parseProf(t) {
        const cur = /^current: *(\S+)/m.exec(t)?.[1], b = t.split(/\n- /).find(s => s.startsWith(`uid: ${cur}`)) ?? "";
        const f = k => new RegExp(`^ +${k}: *(.*)$`, "m").exec(b)?.[1]?.trim() ?? "";
        return { name: f("name"), host: /\/\/([^/:]+)/.exec(f("url"))?.[1] ?? "local", updated: +f("updated"), spent: +f("upload") + +f("download"), total: +f("total") };
    }
    function bytes(n) {
        const u = ["b", "kb", "mb", "gb", "tb", "pb"];
        let i = 0;
        while (n >= 1024 && i < 5) { n /= 1024; i++; }
        return `${n.toFixed(i > 2 ? 2 : 0)} ${u[i]}`;
    }

    // ---- verge: the core. The verge service socket or its own, the secret — from the verge config; $0 — the API path ----
    readonly property string core: `d='${home}'; s=/run/clash-verge-service/users/$(id -u)/verge-mihomo.sock; [ -S "$s" ] || s="$d/verge-mihomo.sock"; `
        + `exec curl -sfN --unix-socket "$s" -H "Authorization: Bearer $(sed -n 's/^secret: *//p' "$d/config.yaml")" "http://core$0"`

    // speed once a second, the last 10 minutes — always accumulated, so the graph doesn't start from zero
    property var toll: []
    property real up: 0
    property real down: 0
    Process {
        id: traffic
        running: true
        command: ["sh", "-c", root.core, "/traffic"]
        stdout: SplitParser {
            onRead: l => {
                try {
                    const j = JSON.parse(l);
                    root.up = j.up;
                    root.down = j.down;
                    root.toll = root.toll.slice(-599).concat([[j.up, j.down]]);
                } catch (e) {}
            }
        }
        onExited: retry.start() // verge is asleep — we'll knock later
    }
    Timer { id: retry; interval: 5000; onTriggered: traffic.running = true }

    property int links: 0
    Process {
        id: conns
        command: ["sh", "-c", root.core, "/connections"]
        stdout: StdioCollector { onStreamFinished: { try { root.links = JSON.parse(text).connections?.length ?? 0; } catch (e) {} } }
    }
    Timer { running: root.visible; interval: 2000; repeat: true; triggeredOnStart: true; onTriggered: conns.running = true }

    // the nodes' protocol (vless · xudp) — only the core has it, the tray doesn't
    property var kinds: ({})
    Process {
        id: kindsP
        command: ["sh", "-c", root.core, "/proxies"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const p = JSON.parse(text).proxies, k = {};
                    for (const n in p) k[n] = [p[n].type.toLowerCase(), p[n].xudp && "xudp"].filter(Boolean);
                    root.kinds = k;
                } catch (e) {}
            }
        }
    }

    // the traffic matrix: 50 columns of 12 s, dots from the axis: [in up, out down], 0…5 by the overall maximum.
    // The panel is closed — don't compute: it accumulates every second, and nobody sees the matrix
    readonly property var cols: {
        if (!root.visible) return [];
        const s = Array(Math.max(0, 600 - toll.length)).fill([0, 0]).concat(toll), c = [];
        let max = 1;
        for (let i = 0; i < 50; i++) {
            let a = 0, b = 0;
            for (let j = i * 12; j < i * 12 + 12; j++) { a += s[j][0]; b += s[j][1]; }
            c.push([b / 12, a / 12]);
            max = Math.max(max, a / 12, b / 12);
        }
        const lv = v => v > 0 ? Math.max(1, Math.round(5 * v / max)) : 0;
        return c.map(([i, o]) => [lv(i), lv(o)]);
    }
    function speed(b) { const k = b / 1024; return k >= 1000 ? [(k / 1024).toFixed(1), "mb/s"] : [k.toFixed(1), "kb/s"]; }

    // ---- opening / closing: its own animation (glyph layers have no_anim in hypr) ----
    property int cur: 0 // the keyboard cursor over the nodes
    property bool shown: false
    // the window appears a moment before it moves: its first frame (creating the surface) is the slow one, so it lands
    // while nothing is moving yet
    property bool mapped: false
    Timer { running: root.visible && !root.mapped; interval: 20; onTriggered: root.mapped = true }
    Connections { target: root; function onVisibleChanged() { if (!root.visible) root.mapped = false; } }
    property real t: shown && mapped ? 1 : 0
    Behavior on t { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }

    function open() {
        cur = Math.max(0, ways.findIndex(w => w.on));
        kindsP.running = true;
        shown = true;
        panel.forceActiveFocus();
    }
    function close() { shown = false; }
    function toggle() { shown ? close() : open(); }
    onVisibleChanged: if (visible) list.positionViewAtIndex(cur, ListView.Contain)

    visible: t > 0 || shown
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "glyph-vpn"

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: root.t
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    Stage {
        id: stage

        Rectangle {
            id: panel
            x: (stage.width - width) / 2
            y: (stage.height - height) / 2 - 20 + 24 * (1 - root.t)
            width: 1040
            height: 760
            opacity: root.t
            radius: Theme.corner(44)
            color: Theme.s1
            border { width: 1; color: Theme.s2 }
            focus: true
            MouseArea { anchors.fill: parent } // a click on the panel doesn't close it

            Keys.onPressed: e => {
                const n = root.ways.length;
                if ((e.key === Qt.Key_Up || e.key === Qt.Key_K) && n) root.cur = (root.cur + n - 1) % n;
                else if ((e.key === Qt.Key_Down || e.key === Qt.Key_J) && n) root.cur = (root.cur + 1) % n;
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.go(root.cur);
                else if (e.key === Qt.Key_S) root.flip();
                else if (e.key === Qt.Key_T) root.ping();
                else if (e.key === Qt.Key_Tab) root.route((root.mode + 1) % 3);
                else if (e.key === Qt.Key_Escape) root.close();
                else return;
                list.positionViewAtIndex(root.cur, ListView.Contain);
                e.accepted = true;
            }

            // ---- left: ring, pills, mode, profile ----
            Column {
                x: 36
                y: 36
                width: 340
                spacing: 16

                // the ring: lights up in a wave on open and on turning on; a click — on/off
                Item {
                    width: 340
                    height: 340
                    Ring { anchors.fill: parent; n: 60; dot: 10; f: root.shown && root.connected ? 1 : 0 }
                    Column {
                        anchors.centerIn: parent
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 18
                            height: 18
                            radius: 9
                            color: root.live ? Theme.accent : Theme.s3
                            Behavior on color { ColorAnimation { duration: Theme.t } }
                        }
                        Num {
                            anchors.horizontalCenter: parent.horizontalCenter
                            topPadding: lead + 22
                            bottomPadding: lead + 16
                            text: root.connected ? "ON" : "OFF"
                            font.pixelSize: 120
                            color: root.connected ? Theme.fg : Theme.mute
                            Behavior on color { ColorAnimation { duration: Theme.t } }
                        }
                        Lb {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: !root.hasVerge ? "not installed" : !root.verge ? "verge sleeps · tap" : root.connected ? `since ${Qt.formatTime(root.since, "hh:mm")}` : "tap to connect"
                        }
                    }
                    TapHandler { onTapped: root.flip() }
                }
                Item { width: 1; height: 12 }

                Row {
                    spacing: 12
                    Pill { on: root.sys; icon: "\u{F059F}"; name: "System"; sub: "proxy"; onClicked: root.press("System Proxy") }
                    Pill { on: root.tun; icon: "\u{F0A60}"; name: "TUN"; sub: "tunnel"; onClicked: root.press("TUN Mode") }
                }

                // mode: the white fill flows to the selected chip
                Rectangle {
                    id: modeBox
                    width: 340
                    height: 58
                    radius: Theme.corner(29)
                    color: Theme.s2
                    readonly property real cw: (width - 12) / 3
                    Rectangle {
                        x: 6 + Math.max(0, root.mode) * modeBox.cw
                        y: 6
                        visible: root.mode >= 0
                        width: modeBox.cw
                        height: 46
                        radius: Theme.corner(23)
                        color: Theme.fg
                        Behavior on x { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
                    }
                    Row {
                        x: 6
                        y: 6
                        Repeater {
                            model: root.modeNames
                            Item {
                                required property string modelData
                                required property int index
                                width: modeBox.cw
                                height: 46
                                Lb { anchors.centerIn: parent; text: parent.modelData; px: 11; color: root.mode === parent.index ? Theme.ink : Theme.grey }
                                TapHandler { onTapped: root.route(parent.index) }
                            }
                        }
                    }
                }
            }

            Column {
                x: 36
                anchors { bottom: parent.bottom; bottomMargin: 36 }
                width: 340
                spacing: 6
                Lb { text: "profile"; px: 11 }
                Lb { width: parent.width; elide: Text.ElideRight; text: root.prof.name || "none"; px: 14; color: Theme.fg }
                Lb { text: `${root.prof.host ?? "local"}${root.prof.updated ? " · upd " + Qt.locale("en_US").toString(new Date(root.prof.updated * 1000), "d MMM") : ""}`; px: 11 }
                Item { width: 1; height: 6 }
                Seg { visible: (root.prof.total ?? 0) > 0; width: parent.width; height: 6; n: 24; f: (root.prof.spent ?? 0) / (root.prof.total || 1) }
                Lb { text: `${root.bytes(root.prof.spent ?? 0)} of ${root.prof.total ? root.bytes(root.prof.total) : "∞"} spent`; px: 11 }
            }

            // ---- right: speed, traffic, nodes ----
            Item {
                x: 420
                y: 36
                width: parent.width - x - 36
                height: parent.height - 72

                Column {
                    id: rcol
                    width: parent.width
                    spacing: 12

                    Row {
                        spacing: 56
                        Stat { k: `↓ in · ${root.speed(root.down)[1]}`; v: root.speed(root.down)[0] }
                        Stat { k: `↑ out · ${root.speed(root.up)[1]}`; v: root.speed(root.up)[0] }
                    }
                    Item { width: 1; height: 14 }

                    Item {
                        width: parent.width
                        height: tl.height
                        Lb { id: tl; text: "traffic · in / out · 10 min" }
                        Lb { anchors.right: parent.right; text: `${root.links} connections`; color: Theme.fg }
                    }
                    // the matrix: in grows from the middle up, out — down; the top white, greys under it
                    Grid {
                        id: mx
                        width: parent.width
                        columns: 50
                        spacing: 4
                        readonly property real d: (width - 49 * spacing) / 50
                        Repeater {
                            model: 50 * 10
                            Rectangle {
                                required property int index
                                readonly property int r: Math.floor(index / 50)
                                readonly property int lv: r < 5 ? 5 - r : r - 4 // from the axis: 1 … 5
                                readonly property int h: root.cols[index % 50]?.[r < 5 ? 0 : 1] ?? 0
                                width: mx.d
                                height: mx.d
                                radius: mx.d / 2
                                color: lv === h ? Theme.fg : lv < h ? Theme.grey : Theme.s2
                            }
                        }
                    }
                    Item { width: 1; height: 14 }

                    Item {
                        width: parent.width
                        height: nl.height
                        Lb { id: nl; text: `nodes · ${root.group}` }
                        Lb {
                            anchors.right: parent.right
                            text: root.pinging ? "testing ···" : "test latency"
                            color: root.pinging ? Theme.grey : Theme.fg
                            TapHandler { onTapped: root.ping() }
                        }
                    }
                }

                // ponytail: don't fit — they scroll, the panel doesn't grow
                ListView {
                    id: list
                    anchors { top: rcol.bottom; topMargin: 4; bottom: parent.bottom; left: parent.left; right: parent.right }
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.ways.length // by count: the delegates live on, the fill has time to flow
                    delegate: Rectangle {
                        id: row
                        required property int index
                        readonly property var w: root.ways[index] ?? {}
                        readonly property bool on: !!w.on
                        width: list.width
                        height: 52
                        radius: Theme.corner(26)
                        color: on ? Theme.fg : index === root.cur ? Theme.s2 : Theme.fade(Theme.s2, 0)
                        Behavior on color { ColorAnimation { duration: Theme.t } }

                        Num {
                            id: cc
                            x: 20
                            anchors.verticalCenter: parent.verticalCenter
                            width: 50
                            text: row.w.cc ?? ""
                            font.pixelSize: 26
                            color: row.on ? Theme.ink : Theme.fg
                        }
                        Column {
                            anchors { left: cc.right; leftMargin: 10; right: ping.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: row.w.name ?? ""
                                font { family: Theme.ui; pixelSize: 16; weight: Font.DemiBold }
                                color: row.on ? Theme.ink : Theme.fg
                            }
                            Lb {
                                width: parent.width
                                visible: !!row.w.sub
                                elide: Text.ElideRight
                                text: row.w.sub ?? ""
                                px: 10
                                color: row.on ? Theme.ink : Theme.grey
                                opacity: row.on ? 0.6 : 1
                            }
                        }
                        // ping: 5 segments, fewer — worse; built-in ones (direct/reject) have no ping
                        Row {
                            id: ping
                            anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                            spacing: 12
                            Seg {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 54
                                height: 6
                                n: 5
                                f: row.w.ms > 0 ? Math.max(0.2, 1 - row.w.ms / 500) : 0
                                on: row.on ? Theme.ink : Theme.fg
                                off: row.on ? Theme.fade(Theme.ink, 0.2) : Theme.s3
                            }
                            Lb {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 64
                                horizontalAlignment: Text.AlignRight
                                text: root.pinging && row.w.ms !== 0 ? "···" : row.w.ms ? `${row.w.ms} ms` : "—"
                                px: 11
                                color: row.on ? Theme.ink : Theme.grey
                            }
                        }
                        TapHandler { onTapped: { root.cur = row.index; root.go(row.index); } }
                    }
                }
                Lb { visible: !root.ways.length; anchors.centerIn: list; text: !root.hasVerge ? "clash verge isn't installed · it's an extra in install.sh" : root.verge ? "no nodes" : "clash verge sleeps" }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: panel.y + panel.height + 30
            opacity: root.t
            spacing: 34
            Repeater {
                model: ["↑↓ node", "↵ connect", "s tunnel", "t ping", "tab route", "esc close"]
                Lb { required property string modelData; text: modelData }
            }
        }
    }

    // a pill: on — white, the text black (like in quick settings)
    component Pill: Rectangle {
        id: pill
        property bool on
        property string icon
        property string name
        property string sub
        signal clicked
        width: 164
        height: 76
        radius: Theme.corner(38)
        color: on ? Theme.fg : Theme.s2
        Behavior on color { ColorAnimation { duration: Theme.t } }
        Rectangle {
            id: pi
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 52
            height: 52
            radius: 26
            color: pill.on ? Theme.ink : Theme.s3
            Icon { anchors.centerIn: parent; text: pill.icon; font.pixelSize: 22 }
        }
        Column {
            anchors { left: pi.right; leftMargin: 12; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            Text { text: pill.name; font { family: Theme.ui; pixelSize: 16; weight: Font.DemiBold } color: pill.on ? Theme.ink : Theme.fg }
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: pill.sub
                font { family: Theme.mono; pixelSize: 11; letterSpacing: 0.9; capitalization: Font.AllUppercase }
                color: pill.on ? Theme.ink : Theme.fg
                opacity: 0.6
            }
        }
        TapHandler { onTapped: pill.clicked() }
    }
    // speed: a label and a Doto number
    component Stat: Column {
        property string k
        property string v
        width: 264
        Lb { text: parent.k }
        Num { topPadding: lead + 10; text: parent.v; font.pixelSize: 80 }
    }
}
