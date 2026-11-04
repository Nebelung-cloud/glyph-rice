import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs
import qs.components
import "../prefs"
import "conn.js" as Conn

// network instead of nmtui. On the left: networks in range, saved ones out of range, other connections (wired, vpn), «+ wi-fi», «+ ethernet».
// On the right the selected one: address, gateway, dns, mac, connect/disconnect/forget and «settings» — full editing, like in nmtui (Edit).
// At the top — wi-fi and the computer's name. Live state — Quickshell.Networking, profiles and editing — nmcli
Page {
    id: root
    property bool live // the window is open and the section is selected: scan, read nmcli
    caption: `network · ${!wifiOn ? "wi-fi off" : connectivity}`

    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property string connectivity: ["unknown", "offline", "sign in", "limited", "online"][Networking.connectivity] ?? ""
    Binding { when: root.live && root.wifiOn && !!root.wifi; target: root.wifi; property: "scannerEnabled"; value: true }

    // ---- NetworkManager profiles: uuid, type, active, name, ssid (for wifi). A connection's name isn't always the ssid ----
    property var profiles: []
    function refresh() { list.running = true; }
    Process {
        id: list
        command: ["sh", "-c", "nmcli -t -f UUID,TYPE,ACTIVE connection show | while IFS=: read -r u t a; do s=; [ \"$t\" = 802-11-wireless ] && s=$(nmcli -g 802-11-wireless.ssid connection show \"$u\"); printf '%s\\t%s\\t%s\\t%s\\t%s\\n' \"$u\" \"$t\" \"$a\" \"$(nmcli -g connection.id connection show \"$u\")\" \"$s\"; done"]
        stdout: StdioCollector {
            onStreamFinished: root.profiles = text.split("\n").filter(Boolean).map(l => {
                const [uuid, type, active, name, ssid] = l.split("\t").map(x => (x ?? "").replace(/\\(.)/g, "$1"));
                return { uuid, type, active: active === "yes", name, ssid };
            }).filter(p => p.type !== "loopback")
        }
    }
    onLiveChanged: if (live) refresh()
    // ssid → uuid; two profiles for one network — take the active one
    readonly property var saved: profiles.filter(p => p.ssid).sort((a, b) => a.active - b.active).reduce((m, p) => (m[p.ssid] = p.uuid, m), {})

    // in range: ours on top, then the saved ones, then by strength
    readonly property var nets: !wifiOn || !wifi ? [] : wifi.networks.values.filter(n => n.name)
        .sort((a, b) => b.connected - a.connected || b.known - a.known || b.signalStrength - a.signalStrength).slice(0, 12)
    readonly property var away: profiles.filter(p => p.ssid && !nets.some(n => n.name === p.ssid))
    readonly property var others: profiles.filter(p => p.type !== "802-11-wireless")

    // ---- the selection: a network from the scan (by ssid) or a profile (by uuid) ----
    property string selSsid
    property string selUuid
    function pickNet(s) { selUuid = ""; selSsid = s; }
    function pickProf(u) { selSsid = ""; selUuid = u; }
    readonly property var net: selSsid ? nets.find(n => n.name === selSsid) ?? null : null
    readonly property string uuid: selUuid || (selSsid ? saved[selSsid] ?? "" : "")
    readonly property var prof: profiles.find(p => p.uuid === uuid) ?? null
    readonly property bool any: !!selSsid || !!selUuid
    readonly property bool active: net ? net.connected : prof?.active ?? false
    readonly property string sec: net ? scanSec(net) : ""
    // without a profile a password is enough (or nothing); the rest (enterprise, wep, leap) — straight to editing
    readonly property bool quick: !!net && ["none", "owe", "wpa-psk", "sae"].includes(sec)
    property bool askPw: false
    property string msg: ""
    onSelSsidChanged: { askPw = false; msg = ""; pw.text = ""; }
    onSelUuidChanged: { askPw = false; msg = ""; }

    // editing (Edit) over the lists. A new one: an empty uuid, the type, ssid and security from the scan
    property bool editing: false
    property var draft: ({})
    function edit(d) {
        draft = d;
        adding = false;
        editing = true;
    }
    // from one edit to another (a port): Edit reads everything on creation — recreate it
    function reopen(d) {
        editing = false;
        draft = d;
        Qt.callLater(() => editing = true);
    }
    function back() {
        if (editing) {
            editing = false;
            return true;
        }
        if (!any) return false;
        selSsid = selUuid = "";
        return true;
    }

    function scanSec(n) {
        const T = WifiSecurityType;
        const m = [[T.Open, "none"], [T.Owe, "owe"], [T.StaticWep, "wep"], [T.DynamicWep, "dynamic-wep"], [T.Leap, "leap"], [T.WpaPsk, "wpa-psk"],
            [T.Wpa2Psk, "wpa-psk"], [T.Sae, "sae"], [T.WpaEap, "wpa-eap"], [T.Wpa2Eap, "wpa-eap"], [T.Wpa3SuiteB192, "suite-b"]];
        return (m.find(x => x[0] === n.security) ?? [0, "wpa-psk"])[1];
    }
    function bars(n) {
        const lock = n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe;
        const i = Math.min(3, Math.floor(n.signalStrength * 4));
        return (lock ? ["\u{F0920}", "\u{F0923}", "\u{F0926}", "\u{F0929}"] : ["\u{F091F}", "\u{F0922}", "\u{F0925}", "\u{F0928}"])[i];
    }
    function status(n) {
        return `${n.connected ? (Networking.connectivity === NetworkConnectivity.Portal ? "sign in" : "connected") : n.stateChanging ? "connecting" : n.known ? "saved" : WifiSecurityType.toString(n.security).toLowerCase()} · ${Math.round(n.signalStrength * 100)}%`;
    }
    function kind(t) { return Conn.typeName(t); }

    // ---- add: any nmtui type; vpn and wireguard — also by importing a file (.ovpn, .conf) ----
    property bool adding: false
    property var vpnTypes: []
    Process {
        running: root.live
        command: ["sh", "-c", "for f in /usr/lib/NetworkManager/VPN/*.name; do [ -e \"$f\" ] && basename \"$f\" .name | sed 's/^nm-//; s/-service$//'; done"]
        stdout: StdioCollector { onStreamFinished: root.vpnTypes = ["wireguard"].concat(text.split("\n").filter(Boolean)) }
    }
    property int importAt: 0
    function importFile(path) {
        path = path.trim().replace(/^~/, Quickshell.env("HOME"));
        if (!path) return;
        adding = false;
        nm(["connection", "import", "type", vpnTypes[importAt], "file", path]);
    }

    // ---- mobile data: a switch, only if there's a modem ----
    property bool wwanHw: false
    property bool wwanOn: false
    Process {
        id: radio
        running: root.live
        command: ["nmcli", "-t", "-f", "WWAN-HW,WWAN", "radio"]
        stdout: StdioCollector { onStreamFinished: { const [hw, on] = text.trim().split(":"); root.wwanHw = hw !== "missing"; root.wwanOn = on === "enabled"; } }
    }

    // ---- what the connected one has now: addresses, gateway, dns, mac. -t -f with names: -g skips empty ones and breaks the order ----
    property var info: []
    Process {
        id: dev
        running: root.live && root.active && !!root.uuid && !root.editing
        command: ["sh", "-c", "d=$(nmcli -g GENERAL.DEVICES connection show \"$1\"); nmcli -t -f GENERAL.HWADDR,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS device show \"${d%%,*}\"", "sh", root.uuid]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = { "GENERAL.HWADDR": "mac", "IP4.ADDRESS": "ip", "IP4.GATEWAY": "gateway", "IP4.DNS": "dns", "IP6.ADDRESS": "ipv6" };
                const m = {};
                for (const l of text.split("\n")) {
                    const i = l.indexOf(":"), k = names[l.slice(0, i).replace(/\[\d+\]$/, "")], x = l.slice(i + 1).replace(/\\(.)/g, "$1");
                    if (k && x) m[k] = m[k] ? `${m[k]}  ${x}` : x;
                }
                root.info = ["ip", "gateway", "dns", "ipv6", "mac"].filter(k => m[k]).map(k => [k, m[k]]);
            }
        }
    }

    // ---- nmcli actions: the error output into msg, afterwards — re-read the profiles ----
    Process {
        id: act
        stderr: StdioCollector { id: actErr }
        onExited: code => {
            root.msg = code === 0 ? "" : (actErr.text.trim().split("\n").pop() || "nmcli failed").replace(/^Error: /, "");
            root.refresh();
        }
    }
    function nm(args) {
        msg = "";
        act.command = ["nmcli"].concat(args);
        act.running = true;
    }
    function forget() {
        const u = uuid;
        selSsid = selUuid = "";
        nm(["connection", "delete", u]);
    }
    function connect() {
        msg = "";
        if (uuid) return net ? net.connect() : nm(["connection", "up", uuid]);
        if (!quick) return edit({ type: "802-11-wireless", ssid: net.name, sec: sec });
        if (sec === "none" || sec === "owe") return net.connect();
        if (!pw.text) {
            askPw = true;
            return pw.focusIn();
        }
        net.connectWithPsk(pw.text);
        pw.text = "";
        askPw = false;
    }
    function disconnect() { net ? net.disconnect() : nm(["connection", "down", uuid]); }
    Connections {
        target: root.net
        ignoreUnknownSignals: true
        function onConnectionFailed(r) {
            if (r === ConnectionFailReason.NoSecrets && root.quick) {
                root.askPw = true;
                pw.focusIn();
            } else root.msg = ConnectionFailReason.toString(r).toLowerCase();
        }
        function onConnectedChanged() { root.refresh(); }
    }

    // ---- the computer's name: nmcli general hostname, asks for the password (polkit) ----
    property string host
    Process { running: root.live; command: ["nmcli", "general", "hostname"]; stdout: StdioCollector { onStreamFinished: { root.host = text.trim(); hostField.text = root.host; } } }
    Process {
        id: setHost
        stderr: StdioCollector { id: hostErr }
        onExited: code => { root.msg = code === 0 ? "" : (hostErr.text.trim().split("\n").pop() || "hostname not changed").replace(/^Error: /, ""); }
    }
    function rename(h) {
        h = h.trim();
        if (h === host) return;
        if (!/^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$/.test(h)) return msg = "hostname · letters, digits and -";
        host = h;
        setHost.command = ["nmcli", "general", "hostname", h];
        setHost.running = true;
    }

    Row {
        spacing: 20
        Toggle { text: "wi-fi"; on: Networking.wifiEnabled; onFlip: Networking.wifiEnabled = !Networking.wifiEnabled }
        Toggle { visible: root.wwanHw; text: "mobile data"; on: root.wwanOn; onFlip: { root.wwanOn = !root.wwanOn; root.nm(["radio", "wwan", root.wwanOn ? "on" : "off"]); } }
        Field { id: hostField; width: 420; label: "hostname"; hint: "↵ to rename"; onAccepted: root.rename(text) }
    }

    Loader {
        active: root.editing
        visible: active
        sourceComponent: Edit {
            uuid: root.draft.uuid ?? ""
            type: root.draft.type ?? "802-11-wireless"
            ssid: root.draft.ssid ?? ""
            sec: root.draft.sec ?? "wpa-psk"
            extra: root.draft.extra ?? ({})
            onOpen: d => root.reopen(d)
            onDone: u => {
                root.editing = false;
                root.refresh();
                if (u) root.pickProf(u);
            }
        }
    }

    Row {
        visible: !root.editing
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
                Lb { x: 8; bottomPadding: 6; text: !root.wifiOn ? "wi-fi off" : root.nets.length ? `in range · ${root.nets.length}` : "scanning…" }
                Repeater {
                    model: root.nets
                    Line {
                        required property var modelData
                        icon: root.bars(modelData)
                        title: modelData.name
                        sub: root.status(modelData)
                        on: modelData.connected
                        busy: modelData.stateChanging
                        picked: root.selSsid === modelData.name
                        onHit: root.pickNet(modelData.name)
                    }
                }
                Lb { x: 8; topPadding: 22; bottomPadding: 6; visible: root.away.length > 0; text: `saved · away · ${root.away.length}` }
                Repeater {
                    model: root.away
                    Line {
                        required property var modelData
                        icon: "\u{F05AA}"
                        title: modelData.name
                        sub: modelData.name === modelData.ssid ? "out of range" : `${modelData.ssid} · out of range`
                        picked: root.selUuid === modelData.uuid
                        onHit: root.pickProf(modelData.uuid)
                    }
                }
                Lb { x: 8; topPadding: 22; bottomPadding: 6; visible: root.others.length > 0; text: `other connections · ${root.others.length}` }
                Repeater {
                    model: root.others
                    Line {
                        required property var modelData
                        icon: modelData.type === "802-3-ethernet" ? "\u{F0200}" : /vpn|wireguard/.test(modelData.type) ? "\u{F0582}" : "\u{F0318}"
                        title: modelData.name
                        sub: `${root.kind(modelData.type)} · ${modelData.active ? "connected" : "off"}`
                        on: modelData.active
                        picked: root.selUuid === modelData.uuid
                        onHit: root.pickProf(modelData.uuid)
                    }
                }
                Act { icon: root.adding ? "\u{F0156}" : "\u{F0415}"; text: root.adding ? "close" : "add connection"; onHit: root.adding = !root.adding }
                // nmtui types; wi-fi here — a hidden or manually set network
                Flow {
                    visible: root.adding
                    width: parent.width
                    topPadding: 10
                    spacing: 10
                    Repeater {
                        model: Conn.types.filter(t => t !== "vpn")
                        Act {
                            required property string modelData
                            icon: "\u{F0415}"
                            text: modelData === "802-11-wireless" ? "wi-fi · hidden" : Conn.typeName(modelData)
                            onHit: root.edit({ type: modelData, ssid: "", sec: "wpa-psk" })
                        }
                    }
                }
                Column {
                    visible: root.adding
                    topPadding: 16
                    spacing: 10
                    Pick { label: "import"; opts: root.vpnTypes; cur: root.importAt; onPicked: i => root.importAt = i }
                    Field { width: 420; label: "file"; hint: root.vpnTypes[root.importAt] === "wireguard" ? "~/wg0.conf · ↵" : "~/client.ovpn · ↵"; onAccepted: root.importFile(text) }
                }
            }
        }

        // ---- the selected one ----
        Flickable {
            width: 480
            height: Math.min(contentHeight, 700)
            contentHeight: det.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: det
                width: parent.width
                spacing: 16

                Lb { visible: !root.any; text: "pick a connection to see its details" }

                Column {
                    visible: root.any
                    width: parent.width
                    spacing: 6
                    Text { width: parent.width; elide: Text.ElideRight; text: root.net?.name ?? root.prof?.name ?? ""; font { family: Theme.ui; pixelSize: 32; weight: Font.DemiBold } color: Theme.fg }
                    Lb {
                        width: parent.width
                        elide: Text.ElideRight
                        text: root.net ? root.status(root.net) + (root.uuid ? "" : root.quick ? " · new" : " · needs setup")
                            : root.prof ? `${root.kind(root.prof.type)} · ${root.prof.active ? "connected" : root.prof.ssid ? "out of range" : "off"}` : ""
                    }
                }

                Grid {
                    visible: root.active && root.info.length > 0
                    columns: 2
                    columnSpacing: 24
                    rowSpacing: 8
                    Repeater {
                        model: [].concat(...root.info) // label, value, label…
                        Text {
                            required property string modelData
                            required property int index
                            width: index % 2 ? 380 : implicitWidth
                            wrapMode: Text.WrapAnywhere
                            text: modelData
                            font { family: Theme.mono; pixelSize: index % 2 ? 15 : 11; capitalization: index % 2 ? Font.MixedCase : Font.AllUppercase; letterSpacing: index % 2 ? 0 : 1.5 }
                            color: index % 2 ? Theme.fg : Theme.grey
                        }
                    }
                }

                Field {
                    id: pw
                    visible: root.askPw
                    label: "password"
                    secret: true
                    hint: "type it, then ↵"
                    onAccepted: if (text) root.connect()
                }

                Flow {
                    visible: root.any
                    width: parent.width
                    spacing: 14
                    Act { visible: !root.active && (!!root.net || !!root.uuid); icon: "\u{F0337}"; text: !root.uuid && !root.quick ? "set up" : "connect"; onHit: root.connect() }
                    Act { visible: root.active; icon: "\u{F0338}"; text: "disconnect"; onHit: root.disconnect() }
                    Act { visible: !!root.uuid; icon: "\u{F0493}"; text: "settings"; onHit: root.edit({ uuid: root.uuid }) }
                    Act { visible: !root.uuid && root.quick; icon: "\u{F0493}"; text: "more options"; onHit: root.edit({ type: "802-11-wireless", ssid: root.net.name, sec: root.sec }) }
                    Act { visible: !!root.uuid; icon: "\u{F0A7A}"; text: "forget"; onHit: root.forget() }
                }
                Lb { width: parent.width; wrapMode: Text.Wrap; visible: !!root.msg; text: root.msg; color: Theme.red }
            }
        }
    }
}
