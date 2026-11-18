import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs
import qs.components
import "../prefs"
import "conn.js" as Conn

// network instead of nmtui. On the left: networks in range, saved ones out of range, other connections (wired, vpn), «+ wi-fi», «+ ethernet».
// On the right the selected one: address, gateway, dns, mac, connect/disconnect/forget and «settings» — full form, like in nmtui (Edit).
// At the top — wi-fi and the computer's name. Live state — Quickshell.Networking, profiles and form — nmcli
Sheet {
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
    // without a profile a password is enough (or nothing); the rest (enterprise, wep, leap) — straight to form
    readonly property bool quick: !!net && ["none", "owe", "wpa-psk", "sae"].includes(sec)
    property bool askPw: false
    property string msg: ""
    onSelSsidChanged: { askPw = false; msg = ""; pw.text = ""; }
    onSelUuidChanged: { askPw = false; msg = ""; }

    // form (Edit) over the lists. A new one: an empty uuid, the type, ssid and security from the scan
    property bool form: false
    property var draft: ({})
    function openForm(d) {
        draft = d;
        form = true;
    }
    // from one edit to another (a port): Edit reads everything on creation — recreate it
    function reopen(d) {
        form = false;
        draft = d;
        Qt.callLater(() => form = true);
    }
    // esc closes the form and goes back to the row it came from
    function back() {
        if (!form) return false;
        form = false;
        Qt.callLater(() => hot?.forceActiveFocus());
        return true;
    }
    // the selection follows the row the inspector shows; other rows (the password, the name) keep it
    onHotChanged: if (hot?.ssid !== undefined) pickNet(hot.ssid); else if (hot?.uuid !== undefined) pickProf(hot.uuid)

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
        running: root.live && root.active && !!root.uuid && !root.form
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
        if (!quick) return openForm({ type: "802-11-wireless", ssid: net.name, sec: sec });
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

    // stable row lists (Keep): scanning re-sorts the networks every few seconds. Strength isn't in the order, it's in the hint
    Keep { id: netK; src: root.nets.slice().sort((a, b) => b.connected - a.connected || b.known - a.known || a.name.localeCompare(b.name)).map(n => n.name) }
    Keep { id: awayK; src: root.away.map(p => p.uuid) }
    Keep { id: otherK; src: root.others.map(p => p.uuid) }

    // ---- the inspector for the selected connection: what it has now and what you can do. → on its row enters it ----
    readonly property Component card: Component {
        Column {
            width: 480
            spacing: 16
            Lb {
                width: parent.width
                elide: Text.ElideRight
                text: root.net ? root.status(root.net) + (root.uuid ? "" : root.quick ? " · new" : " · needs setup")
                    : root.prof ? `${root.kind(root.prof.type)} · ${root.prof.active ? "connected" : root.prof.ssid ? "out of range" : "off"}` : ""
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
            Flow {
                width: parent.width
                spacing: 14
                Act { visible: !root.active && (!!root.net || !!root.uuid); icon: "\u{F0337}"; text: !root.uuid && !root.quick ? "set up" : "connect"; onHit: root.connect() }
                Act { visible: root.active; icon: "\u{F0338}"; text: "disconnect"; onHit: root.disconnect() }
                Act { visible: !!root.uuid; icon: "\u{F0493}"; text: "settings"; onHit: root.openForm({ uuid: root.uuid }) }
                Act { visible: !root.uuid && root.quick; icon: "\u{F0493}"; text: "more options"; onHit: root.openForm({ type: "802-11-wireless", ssid: root.net.name, sec: root.sec }) }
                Act { visible: !!root.uuid; icon: "\u{F0A7A}"; text: "forget"; onHit: root.forget() }
            }
            Lb { width: parent.width; wrapMode: Text.Wrap; visible: !!root.msg; text: root.msg; color: Theme.red }
        }
    }
    // ---- adding: any nmtui type (wi-fi here — a hidden or manually set one), or importing a vpn file ----
    readonly property Component adder: Component {
        Column {
            width: 480
            spacing: 16
            Flow {
                width: parent.width
                spacing: 10
                Repeater {
                    model: Conn.types.filter(t => t !== "vpn")
                    Act {
                        required property string modelData
                        icon: "\u{F0415}"
                        text: modelData === "802-11-wireless" ? "wi-fi · hidden" : Conn.typeName(modelData)
                        onHit: root.openForm({ type: modelData, ssid: "", sec: "wpa-psk" })
                    }
                }
            }
            Lb { topPadding: 8; text: "or import a file" }
            Pick { opts: root.vpnTypes; cur: root.importAt; onPicked: i => root.importAt = i }
            Field { width: 466; label: "file"; hint: root.vpnTypes[root.importAt] === "wireguard" ? "~/wg0.conf · ↵" : "~/client.ovpn · ↵"; onAccepted: root.importFile(text) }
        }
    }

    Loader {
        active: root.form
        visible: active
        onLoaded: item.nextItemInFocusChain(true)?.forceActiveFocus()
        sourceComponent: Edit {
            width: 620
            uuid: root.draft.uuid ?? ""
            type: root.draft.type ?? "802-11-wireless"
            ssid: root.draft.ssid ?? ""
            sec: root.draft.sec ?? "wpa-psk"
            extra: root.draft.extra ?? ({})
            onOpen: d => root.reopen(d)
            onDone: u => {
                root.form = false;
                root.refresh();
                if (u) root.pickProf(u);
                Qt.callLater(() => root.hot?.forceActiveFocus());
            }
        }
    }

    Lb { visible: !root.form; topPadding: 8; bottomPadding: 4; text: "network" }
    Opt {
        visible: !root.form
        title: "Wi-Fi"
        hint: "Wireless networks."
        about: "Off disconnects from Wi-Fi and stops scanning. Wired connections keep working."
        value: root.wifiOn ? "on" : "off"
        Switch { on: Networking.wifiEnabled; onFlip: Networking.wifiEnabled = !Networking.wifiEnabled }
    }
    Opt {
        visible: !root.form && root.wwanHw
        title: "Mobile data"
        hint: "The built-in modem with a SIM card."
        about: "Uses your mobile plan when there's no Wi-Fi. Data may cost money."
        value: root.wwanOn ? "on" : "off"
        Switch { on: root.wwanOn; onFlip: { root.wwanOn = !root.wwanOn; root.nm(["radio", "wwan", root.wwanOn ? "on" : "off"]); } }
    }
    Opt {
        visible: !root.form
        wide: true
        title: "Computer name"
        hint: "How this computer shows up on the network."
        about: "Other devices see this name, for example when sharing files. Letters, digits and dashes. Renaming asks for your password."
        value: root.host.length <= 14 ? root.host : ""
        Field { id: hostField; width: 466; label: "hostname"; hint: "↵ to rename"; onAccepted: root.rename(text) }
    }
    Lb { visible: !root.form && !!root.msg; width: 620; topPadding: 8; wrapMode: Text.Wrap; text: root.msg; color: Theme.red }

    Column {
        visible: !root.form
        width: parent.width
        // a password, when the picked network needs one: the card's «connect» brings you here
        Opt {
            visible: root.askPw
            wide: true
            title: "Password"
            hint: `For ${root.selSsid}.`
            about: "The Wi-Fi password, often on a sticker on the router. ↵ connects."
            value: ""
            Field { id: pw; width: 466; label: "password"; secret: true; hint: "type it, then ↵"; onAccepted: if (text) root.connect() }
        }
        Lb { topPadding: 40; bottomPadding: 4; text: !root.wifiOn ? "wi-fi off" : netK.out.length ? `in range · ${netK.out.length} · → to connect` : "scanning…" }
        Repeater {
            model: netK.out
            Opt {
                required property string modelData
                readonly property string ssid: modelData
                readonly property var n: root.nets.find(x => x.name === modelData) ?? null
                title: modelData
                hint: n ? root.status(n) : ""
                about: n?.connected ? "The network you're on. → for its address, settings, or to disconnect."
                    : n?.known ? "A network you've used before. → to connect." : "A network in range. → to connect; it asks for the password if there is one."
                value: n ? `${Math.round(n.signalStrength * 100)} %` : ""
                preview: root.card
            }
        }
        Lb { visible: awayK.out.length > 0; topPadding: 40; bottomPadding: 4; text: `saved · away · ${awayK.out.length}` }
        Repeater {
            model: awayK.out
            Opt {
                required property string modelData
                readonly property string uuid: modelData
                readonly property var p: root.profiles.find(x => x.uuid === modelData) ?? null
                title: p?.name ?? ""
                hint: !p ? "" : p.name === p.ssid ? "Out of range." : `${p.ssid} · out of range.`
                about: "A saved Wi-Fi network that isn't around. It connects by itself when it is. → to change or forget it."
                value: "away"
                preview: root.card
            }
        }
        Lb { visible: otherK.out.length > 0; topPadding: 40; bottomPadding: 4; text: `other connections · ${otherK.out.length}` }
        Repeater {
            model: otherK.out
            Opt {
                required property string modelData
                readonly property string uuid: modelData
                readonly property var p: root.profiles.find(x => x.uuid === modelData) ?? null
                title: p?.name ?? ""
                hint: p ? `${root.kind(p.type)} · ${p.active ? "connected" : "off"}` : ""
                about: "A wired, VPN or other saved connection. → to connect, change or forget it."
                value: p?.active ? "on" : "off"
                preview: root.card
            }
        }
        Lb { topPadding: 40; bottomPadding: 4; text: "add" }
        Opt {
            title: "Add a connection"
            hint: "Wired, VPN, hidden Wi-Fi, or import a file."
            about: "Pick a type to fill in its settings, or import a WireGuard or OpenVPN file. → to choose."
            value: ""
            preview: root.adder
        }
    }
}
