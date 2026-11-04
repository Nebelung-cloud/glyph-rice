import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.components
import "../prefs"
import "conn.js" as Conn

// editing a connection, like in nmtui: general, wi-fi or ethernet, security, 802.1x (peap, ttls, tls…), ipv4, ipv6.
// What's visible — conn.js decides by the type and what's selected. A uuid — modify, none — add a new one (type, ssid, sec from the scan).
// Save — only what changed; «and connect» — also connection up, an nmcli error stays on screen
Column {
    id: root
    property string uuid
    property string type: "802-11-wireless"
    property string ssid
    property string sec: "wpa-psk"
    property var extra: ({}) // a new one with values set from outside: a port — controller, port-type
    signal done(string uuid) // saved (and connected) — the uuid; cancelled — ""
    signal open(var draft)   // go to another one: a port, a new port

    property var was: ({})
    // choices and flags — in v (reassigned: what's visible depends on them), text — in texts without reassignment,
    // otherwise the Repeater would recreate the fields and focus would leave mid-word
    property var v: ({})
    property var texts: ({})
    property string msg
    property bool busy
    // fields — only once read: otherwise empty fields would remember "" and save would wipe the real values
    property bool ready: false
    readonly property var shown: Conn.visible(type, v)

    width: 950
    spacing: 18

    Component.onCompleted: {
        if (uuid) return reader.running = true;
        was = {};
        v = Conn.fresh(type, ssid, sec, extra);
        peerList = Conn.peers("");
        ready = true;
    }
    Process {
        id: reader
        command: ["nmcli", "-t", "-f", "connection,802-11-wireless,802-11-wireless-security,802-1x,802-3-ethernet,ipv4,ipv6", "connection", "show", root.uuid]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = Conn.parse(text);
                root.type = p["connection.type"] ?? root.type;
                root.was = p;
                if (root.type === "wireguard") return wgPeers.running = true;
                root.v = Object.assign({}, p);
                root.ready = true;
            }
        }
    }

    // wireguard peers are read with secrets (-s): nmcli hides the preshared-key, and writing the peers without it would wipe the key
    Process {
        id: wgPeers
        command: ["nmcli", "-s", "-t", "-f", "wireguard.peers", "connection", "show", root.uuid]
        stdout: StdioCollector {
            onStreamFinished: {
                const s = text.trim().replace(/^wireguard\.peers:/, "").replace(/\\(.)/g, "$1");
                const w = Object.assign({}, root.was, { "wireguard.peers": s });
                root.was = w;
                root.v = Object.assign({}, w);
                root.peerList = Conn.peers(s);
                root.ready = true;
            }
        }
    }
    property var peerList: []
    function syncPeers() { texts["wireguard.peers"] = Conn.peersText(peerList); }

    // ---- ports of a bond, bridge, team: profiles whose controller is this device or the uuid ----
    readonly property string me: v["connection.interface-name"] || uuid
    property var portList: []
    Process {
        id: portsProc
        running: root.ready && !!root.uuid && ["bond", "bridge", "team"].includes(root.type)
        command: ["sh", "-c", "for u in $(nmcli -g UUID connection show); do nmcli -t -f connection.uuid,connection.id,connection.type,connection.controller,connection.interface-name connection show \"$u\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const all = [];
                let cur = null;
                for (const l of text.split("\n")) {
                    const i = l.indexOf(":"), k = l.slice(0, i), x = l.slice(i + 1).replace(/\\(.)/g, "$1");
                    if (k === "connection.uuid") all.push(cur = { uuid: x });
                    else if (cur) cur[k.slice(11)] = x;
                }
                root.portList = all.filter(p => p.controller && (p.controller === root.me || p.controller === root.uuid));
            }
        }
    }
    Process { id: dropPort; onExited: portsProc.running = true }

    function set(k, x) {
        const n = Object.assign({}, v);
        n[k] = x;
        // 802.1x turned on for the first time — like in nmtui: protected eap, mschapv2
        const eap = k === "x8021" && x === "yes" || k === "sec" && ["dynamic-wep", "wpa-eap", "suite-b"].includes(x);
        if (eap && !n["802-1x.eap"]) Object.assign(n, { "802-1x.eap": "peap", "802-1x.phase2-auth": "mschapv2" });
        v = n;
    }

    // ---- writing: the commands one by one, then (if asked) connection up ----
    property var queue: []
    property bool up: false
    property string made // the uuid of the one just added
    function save(connect) {
        msg = "";
        const w = Conn.writes(type, was, Object.assign({}, v, texts), Quickshell.env("USER"));
        const q = [];
        if (!uuid) q.push(["nmcli", "connection", "add", "type", type].concat(w.set, [].concat(...Object.entries(extra))));
        else {
            if (w.set.length) q.push(["nmcli", "connection", "modify", uuid].concat(w.set));
            for (const d of w.drop) q.push(["nmcli", "connection", "modify", uuid, "remove", d]);
        }
        queue = q;
        up = connect;
        busy = true;
        next();
    }
    function next() {
        const id = uuid || made;
        if (queue.length) {
            run.command = queue[0];
            queue = queue.slice(1);
        } else if (up && id) {
            up = false;
            msg = "connecting…";
            run.command = ["nmcli", "connection", "up", id];
        } else {
            busy = false;
            msg = "";
            return done(id);
        }
        run.running = true;
    }
    Process {
        id: run
        stdout: StdioCollector { id: out }
        stderr: StdioCollector { id: err }
        onExited: code => {
            if (code !== 0) {
                root.busy = false;
                root.queue = [];
                root.up = false;
                return root.msg = (err.text.trim().split("\n").pop() || "nmcli failed").replace(/^Error: /, "");
            }
            const m = /\(([0-9a-f-]{36})\)/.exec(out.text);
            if (!root.uuid && m) root.made = m[1];
            root.next();
        }
    }

    Row {
        spacing: 18
        Text { text: root.v["connection.id"] || "new connection"; font { family: Theme.ui; pixelSize: 32; weight: Font.DemiBold } color: Theme.fg }
        Lb { anchors.verticalCenter: parent.verticalCenter; text: `${Conn.typeName(root.type)}${root.extra["connection.port-type"] || root.v["connection.port-type"] ? " · port" : ""} · ${root.uuid ? "edit" : "new"}` }
    }

    Flickable {
        width: parent.width
        height: Math.min(contentHeight, 620)
        contentHeight: flow.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Flow {
            id: flow
            width: parent.width
            spacing: 14
            Repeater {
                model: root.ready ? root.shown : []
                Loader {
                    required property var modelData
                    readonly property var f: modelData
                    sourceComponent: f.group ? head : f.kind === "pick" ? choose : f.kind === "flag" ? flag : f.kind === "peers" ? peersC : f.kind === "ports" ? portsC : field
                }
            }
        }
    }

    Row {
        spacing: 14
        Act { icon: "\u{F0193}"; text: root.busy ? "working…" : "save"; onHit: if (root.ready && !root.busy) root.save(false) }
        Act { icon: "\u{F0337}"; text: "save & connect"; onHit: if (root.ready && !root.busy) root.save(true) }
        Act { icon: "\u{F0156}"; text: "cancel"; onHit: root.done("") }
    }
    Lb { width: parent.width; wrapMode: Text.Wrap; visible: !!root.msg; text: root.msg; color: root.busy ? Theme.fg : Theme.red }

    Component { id: head; Lb { readonly property var f: parent?.f ?? ({}); width: 950; topPadding: 16; text: f.group ?? ""; color: Theme.fg } }
    Component {
        id: choose
        Choose {
            readonly property var f: parent?.f ?? ({})
            label: f.label ?? ""
            names: f.names ?? []
            cur: (f.opts ?? []).indexOf(root.v[f.k] ?? "")
            onPicked: i => root.set(f.k, f.opts[i])
        }
    }
    Component {
        id: flag
        Toggle {
            readonly property var f: parent?.f ?? ({})
            width: 466
            text: f.label ?? ""
            on: root.v[f.k] === "yes"
            onFlip: root.set(f.k, on ? "no" : "yes")
        }
    }
    Component {
        id: field
        Field {
            readonly property var f: parent?.f ?? ({})
            width: 466
            label: f.label ?? ""
            secret: f.kind === "secret"
            hint: secret ? (root.uuid ? "saved · type to change" : "") : f.hint ?? ""
            text: root.texts[f.k] ?? (secret ? "" : root.v[f.k] ?? "")
            onTextChanged: root.texts[f.k] = text
        }
    }

    // wireguard peers, like in nmtui: key, address, allowed ips, keepalive, the shared key; add and remove
    Component {
        id: peersC
        Column {
            width: 950
            spacing: 14
            Repeater {
                model: root.peerList
                Flow {
                    id: peer
                    required property var modelData
                    required property int index
                    width: 950
                    spacing: 14
                    Lb { width: 950; topPadding: 6; text: `peer ${peer.index + 1}` }
                    Field { width: 466; label: "public key"; text: peer.modelData.key; onTextChanged: { peer.modelData.key = text; root.syncPeers(); } }
                    Field { width: 466; label: "endpoint"; hint: "1.2.3.4:51820"; text: peer.modelData.endpoint; onTextChanged: { peer.modelData.endpoint = text; root.syncPeers(); } }
                    Field { width: 466; label: "allowed ips"; hint: "0.0.0.0/0, ::/0"; text: peer.modelData.ips; onTextChanged: { peer.modelData.ips = text; root.syncPeers(); } }
                    Field { width: 466; label: "keepalive · s"; hint: "25"; text: peer.modelData.keepalive; onTextChanged: { peer.modelData.keepalive = text; root.syncPeers(); } }
                    Field { width: 466; label: "preshared key"; secret: true; hint: "none"; text: peer.modelData.psk; onTextChanged: { peer.modelData.psk = text; root.syncPeers(); } }
                    Act {
                        icon: "\u{F0A7A}"
                        text: "remove peer"
                        onHit: {
                            root.peerList = root.peerList.filter((p, i) => i !== peer.index);
                            root.syncPeers();
                        }
                    }
                }
            }
            Act { icon: "\u{F0415}"; text: "add peer"; onHit: root.peerList = root.peerList.concat([{ key: "", endpoint: "", ips: "", psk: "", keepalive: "" }]) }
        }
    }
    // ports: a click — edit the port, «add port» — a new ethernet port of this device. A new device — save it first
    Component {
        id: portsC
        Column {
            width: 950
            spacing: 4
            Lb { visible: !root.uuid; text: "save first, then add ports" }
            Repeater {
                model: root.portList
                Line {
                    required property var modelData
                    width: 466
                    icon: "\u{F0200}"
                    title: modelData.id
                    sub: `${Conn.typeName(modelData.type)} · ${modelData["interface-name"] || "any device"}`
                    onHit: root.open({ uuid: modelData.uuid })
                }
            }
            Flow {
                visible: !!root.uuid
                width: 950
                topPadding: 10
                spacing: 14
                Act { icon: "\u{F0415}"; text: "add port"; onHit: root.open({ type: "802-3-ethernet", extra: { "connection.controller": root.me, "connection.port-type": root.type } }) }
                Repeater {
                    model: root.portList
                    Act {
                        required property var modelData
                        icon: "\u{F0A7A}"
                        text: `remove ${modelData.id}`
                        onHit: {
                            dropPort.command = ["nmcli", "connection", "delete", modelData.uuid];
                            dropPort.running = true;
                        }
                    }
                }
            }
        }
    }
}
