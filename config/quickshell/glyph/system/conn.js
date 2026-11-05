.pragma library

// a NetworkManager connection like in nmtui: the fields by group, what's visible when, and what to write to nmcli.
// The values — a flat object "setting.key" → string, as `nmcli -t -f … connection show` gives it. nmcli doesn't give out passwords
// (<hidden>): an empty password field means «don't touch». Our own keys without a dot: sec, allUsers, x8021, bond:*

const WIFI = "802-11-wireless", WIRED = "802-3-ethernet";

// the types nmtui handles (+ vpn: editing general and ip, the vpn itself — by import), labels for the screen
const types = [WIFI, WIRED, "pppoe", "infiniband", "bond", "bridge", "team", "vlan", "ip-tunnel", "wireguard", "vpn"];
const typeNames = { [WIFI]: "wi-fi", [WIRED]: "ethernet", pppoe: "dsl", infiniband: "infiniband", bond: "bond", bridge: "bridge",
    team: "team", vlan: "vlan", "ip-tunnel": "ip tunnel", wireguard: "wireguard", vpn: "vpn" };
function typeName(t) { return typeNames[t] ?? t; }

// wifi security: one «sec» field instead of key-mgmt + auth-alg + wep-key-type, like the choice in nmtui
const secs = ["none", "wep", "wep-pass", "dynamic-wep", "leap", "wpa-psk", "sae", "wpa-eap", "suite-b", "owe"];
const secNames = ["none", "wep 40/128-bit key", "wep 128-bit passphrase", "dynamic wep · 802.1x", "leap",
    "wpa & wpa2 personal", "wpa3 personal", "wpa & wpa2 enterprise", "wpa3 enterprise", "enhanced open"];

function sec(v) {
    const km = v["802-11-wireless-security.key-mgmt"] || "";
    if (!km) return "none";
    if (km === "none") return /^(2|passphrase)/.test(v["802-11-wireless-security.wep-key-type"] || "") ? "wep-pass" : "wep";
    if (km === "ieee8021x") return v["802-11-wireless-security.auth-alg"] === "leap" ? "leap" : "dynamic-wep";
    if (km === "wpa-eap-suite-b-192") return "suite-b";
    return secs.includes(km) ? km : "wpa-psk";
}
// 802.1x is needed: wifi with dynamic wep / enterprise, wired — when turned on
function eapOn(t, v) {
    return t === WIFI ? ["dynamic-wep", "wpa-eap", "suite-b"].includes(v.sec) : t === WIRED && v.x8021 === "yes";
}
// a port of a bridge, bond or team: no ip of its own
const port = v => v["connection.port-type"] || v["connection.slave-type"] || "";

const eap = k => (t, v) => eapOn(t, v) && k.split(" ").includes(v["802-1x.eap"]);
const wifi = t => t === WIFI;
const is = ts => t => ts.split(" ").includes(t);
const ip = (n, ms) => (t, v) => ms.split(" ").includes(v[`${n}.method`]);
const bond = (k, when) => (t, v) => !when || when(v);
const gre = (t, v) => /gre/.test(v["ip-tunnel.mode"] || "");

// ---- bond.options "mode=…,miimon=100,…" ↔ the bond:* fields; foreign keys (xmit_hash_policy…) are kept as is ----
const bondKeys = ["mode", "primary", "miimon", "updelay", "downdelay", "arp_interval", "arp_ip_target"];
function bondParse(v) {
    const o = {};
    for (const p of (v["bond.options"] || "").split(",")) {
        const i = p.indexOf("=");
        if (i > 0) o[p.slice(0, i).trim()] = p.slice(i + 1).trim();
    }
    for (const k of bondKeys) v[`bond:${k}`] = o[k] ?? "";
    v["bond:monitor"] = +(o.arp_interval || 0) > 0 ? "arp" : "mii";
    v["bond:rest"] = Object.keys(o).filter(k => !bondKeys.includes(k)).map(k => `${k}=${o[k]}`).join(",");
}
function bondOptions(v) {
    const ab = v["bond:mode"] === "active-backup", arp = v["bond:monitor"] === "arp";
    const want = ["mode"].concat(ab ? ["primary"] : [], arp ? ["arp_interval", "arp_ip_target"] : ["miimon", "updelay", "downdelay"]);
    const a = want.filter(k => v[`bond:${k}`]).map(k => `${k}=${k === "arp_ip_target" ? v[`bond:${k}`].trim().split(/[\s,]+/).join("\\,") : v[`bond:${k}`].trim()}`);
    return a.concat(v["bond:rest"] ? [v["bond:rest"]] : []).join(",");
}

// ---- wireguard.peers "key attr=… attr=…, key …" ↔ [{ key, endpoint, ips, psk, keepalive }] ----
function peers(s) {
    return (s || "").split(",").map(x => x.trim()).filter(Boolean).map(x => {
        const [key, ...as] = x.split(/\s+/);
        const a = {};
        for (const p of as) {
            const i = p.indexOf("=");
            if (i > 0) a[p.slice(0, i)] = p.slice(i + 1);
        }
        return { key, endpoint: a.endpoint ?? "", ips: (a["allowed-ips"] ?? "").split(";").filter(Boolean).join(", "),
            psk: a["preshared-key"] ?? "", keepalive: a["persistent-keepalive"] ?? "" };
    });
}
function peersText(list) {
    // commas and spaces inside a peer would break the list: allowed-ips — separated by ;
    return list.filter(p => p.key.trim()).map(p => [p.key.trim()]
        .concat(p.endpoint.trim() ? [`endpoint=${p.endpoint.trim()}`] : [])
        .concat(p.ips.trim() ? [`allowed-ips=${p.ips.trim().split(/[\s,;]+/).join(";")}`] : [])
        .concat(p.keepalive.trim() ? [`persistent-keepalive=${p.keepalive.trim()}`] : [])
        .concat(p.psk.trim() ? [`preshared-key=${p.psk.trim()}`] : []).join(" ")).join(", ");
}

const mac = "default · random · stable · permanent";
// kind: text · secret · pick (opts — nmcli values, names — labels) · flag (yes/no) · peers · ports. when(t, v) — whether it's visible.
// out(x) — what to turn it into before writing
const groups = [
    { name: "general", fields: [
        { k: "connection.id", label: "name", kind: "text" },
        { k: "connection.interface-name", label: "device", kind: "text", hint: "any · wlan0 · bond0" },
        { k: "connection.autoconnect", label: "auto-connect", kind: "flag" },
        { k: "allUsers", label: "all users", kind: "flag" },
        { k: "connection.metered", label: "metered", kind: "pick", opts: ["unknown", "yes", "no"], names: ["auto", "yes", "no"] },
    ] },
    { name: "wi-fi", when: wifi, fields: [
        { k: "802-11-wireless.ssid", label: "ssid", kind: "text" },
        { k: "802-11-wireless.mode", label: "mode", kind: "pick", opts: ["infrastructure", "ap", "adhoc"], names: ["client", "hotspot", "ad-hoc"] },
        { k: "802-11-wireless.band", label: "band", kind: "pick", opts: ["", "a", "bg"], names: ["auto", "5 ghz", "2.4 ghz"] },
        { k: "802-11-wireless.channel", label: "channel", kind: "text", hint: "0 · auto", when: (t, v) => !!v["802-11-wireless.band"] },
        { k: "802-11-wireless.bssid", label: "bssid", kind: "text", hint: "any access point" },
        { k: "802-11-wireless.hidden", label: "hidden", kind: "flag" },
        { k: "802-11-wireless.mac-address", label: "device mac", kind: "text", hint: "any" },
        { k: "802-11-wireless.cloned-mac-address", label: "cloned mac", kind: "text", hint: mac },
        { k: "802-11-wireless.mtu", label: "mtu", kind: "text", hint: "auto" },
    ] },
    // wired and everything on top of ethernet: dsl, bond, bridge, team, vlan — cloned mac and mtu, like in nmtui
    { name: "ethernet", when: is(`${WIRED} pppoe bond bridge team vlan`), fields: [
        { k: "802-3-ethernet.mac-address", label: "device mac", kind: "text", hint: "any", when: is(`${WIRED} pppoe`) },
        { k: "802-3-ethernet.cloned-mac-address", label: "cloned mac", kind: "text", hint: mac },
        { k: "802-3-ethernet.mtu", label: "mtu", kind: "text", hint: "auto" },
        { k: "x8021", label: "802.1x security", kind: "flag", when: (t, v) => t === WIRED && !port(v) },
    ] },
    { name: "dsl", when: is("pppoe"), fields: [
        { k: "pppoe.username", label: "username", kind: "text" },
        { k: "pppoe.password", label: "password", kind: "secret" },
        { k: "pppoe.service", label: "service", kind: "text", hint: "usually empty" },
        { k: "pppoe.parent", label: "parent device", kind: "text", hint: "enp2s0" },
    ] },
    { name: "infiniband", when: is("infiniband"), fields: [
        { k: "infiniband.transport-mode", label: "transport", kind: "pick", opts: ["datagram", "connected"], names: ["datagram", "connected"] },
        { k: "infiniband.mtu", label: "mtu", kind: "text", hint: "auto" },
        { k: "infiniband.mac-address", label: "device mac", kind: "text", hint: "any" },
        { k: "infiniband.p-key", label: "p-key", kind: "text", hint: "-1 · default" },
        { k: "infiniband.parent", label: "parent", kind: "text", hint: "with a p-key" },
    ] },
    { name: "bond", when: is("bond"), fields: [
        { k: "ports", kind: "ports" },
        { k: "bond:mode", label: "mode", kind: "pick", opts: ["balance-rr", "active-backup", "balance-xor", "broadcast", "802.3ad", "balance-tlb", "balance-alb"],
            names: ["round-robin", "active backup", "xor", "broadcast", "802.3ad", "adaptive tx", "adaptive lb"] },
        { k: "bond:primary", label: "primary", kind: "text", hint: "eth0", when: bond("", v => v["bond:mode"] === "active-backup") },
        { k: "bond:monitor", label: "link monitoring", kind: "pick", opts: ["mii", "arp"], names: ["mii", "arp"] },
        { k: "bond:miimon", label: "frequency · ms", kind: "text", hint: "100", when: bond("", v => v["bond:monitor"] === "mii") },
        { k: "bond:updelay", label: "link up delay · ms", kind: "text", hint: "0", when: bond("", v => v["bond:monitor"] === "mii") },
        { k: "bond:downdelay", label: "link down delay · ms", kind: "text", hint: "0", when: bond("", v => v["bond:monitor"] === "mii") },
        { k: "bond:arp_interval", label: "frequency · ms", kind: "text", hint: "100", when: bond("", v => v["bond:monitor"] === "arp") },
        { k: "bond:arp_ip_target", label: "arp targets", kind: "text", hint: "192.168.1.1 …", when: bond("", v => v["bond:monitor"] === "arp") },
    ] },
    { name: "bridge", when: is("bridge"), fields: [
        { k: "ports", kind: "ports" },
        { k: "bridge.ageing-time", label: "aging time · s", kind: "text", hint: "300" },
        { k: "bridge.multicast-snooping", label: "igmp snooping", kind: "flag" },
        { k: "bridge.stp", label: "stp", kind: "flag" },
        { k: "bridge.priority", label: "priority", kind: "text", hint: "32768", when: (t, v) => v["bridge.stp"] === "yes" },
        { k: "bridge.forward-delay", label: "forward delay · s", kind: "text", hint: "15", when: (t, v) => v["bridge.stp"] === "yes" },
        { k: "bridge.hello-time", label: "hello time · s", kind: "text", hint: "2", when: (t, v) => v["bridge.stp"] === "yes" },
        { k: "bridge.max-age", label: "max age · s", kind: "text", hint: "20", when: (t, v) => v["bridge.stp"] === "yes" },
        { k: "bridge.group-forward-mask", label: "group forward mask", kind: "text", hint: "0" },
    ] },
    { name: "team", when: is("team"), fields: [
        { k: "ports", kind: "ports" },
        { k: "team.config", label: "json config", kind: "text", hint: "{\"runner\": {\"name\": \"activebackup\"}}" },
    ] },
    { name: "vlan", when: is("vlan"), fields: [
        { k: "vlan.parent", label: "parent", kind: "text", hint: "enp2s0" },
        { k: "vlan.id", label: "vlan id", kind: "text", hint: "1 – 4094" },
    ] },
    { name: "ip tunnel", when: is("ip-tunnel"), fields: [
        { k: "ip-tunnel.mode", label: "mode", kind: "pick", opts: ["ipip", "gre", "sit", "isatap", "vti", "ip6ip6", "ipip6", "ip6gre", "vti6", "gretap", "ip6gretap"],
            names: ["ipip", "gre", "sit", "isatap", "vti", "ip6ip6", "ipip6", "ip6gre", "vti6", "gretap", "ip6gretap"] },
        { k: "ip-tunnel.parent", label: "parent", kind: "text", hint: "any" },
        { k: "ip-tunnel.local", label: "local ip", kind: "text", hint: "any" },
        { k: "ip-tunnel.remote", label: "remote ip", kind: "text" },
        { k: "ip-tunnel.input-key", label: "input key", kind: "text", when: gre },
        { k: "ip-tunnel.output-key", label: "output key", kind: "text", when: gre },
        { k: "ip-tunnel.mtu", label: "mtu", kind: "text", hint: "0 · auto" },
    ] },
    { name: "wireguard", when: is("wireguard"), fields: [
        { k: "wireguard.private-key", label: "private key", kind: "secret" },
        { k: "wireguard.listen-port", label: "listen port", kind: "text", hint: "0 · random" },
        { k: "wireguard.fwmark", label: "fwmark", kind: "text", hint: "0x0" },
        { k: "wireguard.mtu", label: "mtu", kind: "text", hint: "0 · auto" },
        { k: "wireguard.peer-routes", label: "add peer routes", kind: "flag" },
        { k: "wireguard.peers", kind: "peers" },
    ] },
    // vpn from an import: the plugin data as is (key = value, …) and the password; openvpn wants password-flags = 0 in the data
    { name: "vpn", when: is("vpn"), fields: [
        { k: "vpn.data", label: "data", kind: "text", hint: "remote = …, username = …" },
        { k: "vpn.secrets", label: "password", kind: "secret", out: x => `password=${x}` },
    ] },
    { name: "bridge port", when: (t, v) => port(v) === "bridge", fields: [
        { k: "bridge-port.priority", label: "priority", kind: "text", hint: "32" },
        { k: "bridge-port.path-cost", label: "path cost", kind: "text", hint: "100" },
        { k: "bridge-port.hairpin-mode", label: "hairpin mode", kind: "flag" },
    ] },
    { name: "team port", when: (t, v) => port(v) === "team", fields: [
        { k: "team-port.config", label: "json config", kind: "text", hint: "{\"prio\": 100}" },
    ] },
    { name: "security", when: wifi, fields: [
        { k: "sec", label: "security", kind: "pick", opts: secs, names: secNames },
        { k: "802-11-wireless-security.psk", label: "password", kind: "secret", when: (t, v) => ["wpa-psk", "sae"].includes(v.sec) },
        { k: "802-11-wireless-security.wep-key0", label: (t, v) => v.sec === "wep" ? "key" : "passphrase", kind: "secret", when: (t, v) => /^wep/.test(v.sec) },
        { k: "802-11-wireless-security.wep-tx-keyidx", label: "wep index", kind: "pick", opts: ["0", "1", "2", "3"], names: ["1", "2", "3", "4"], when: (t, v) => /^wep/.test(v.sec) },
        { k: "802-11-wireless-security.auth-alg", label: "auth", kind: "pick", opts: ["open", "shared"], names: ["open system", "shared key"], when: (t, v) => /^wep/.test(v.sec) },
        { k: "802-11-wireless-security.leap-username", label: "username", kind: "text", when: (t, v) => v.sec === "leap" },
        { k: "802-11-wireless-security.leap-password", label: "password", kind: "secret", when: (t, v) => v.sec === "leap" },
    ] },
    { name: "802.1x", when: eapOn, fields: [
        { k: "802-1x.eap", label: "authentication", kind: "pick", opts: ["tls", "leap", "pwd", "fast", "ttls", "peap"], names: ["tls", "leap", "pwd", "fast", "tunneled tls", "protected eap"] },
        { k: "802-1x.identity", label: (t, v) => v["802-1x.eap"] === "tls" ? "identity" : "username", kind: "text" },
        { k: "802-1x.password", label: "password", kind: "secret", when: eap("leap pwd fast ttls peap") },
        { k: "802-1x.anonymous-identity", label: "anonymous id", kind: "text", when: eap("fast ttls peap") },
        { k: "802-1x.domain-suffix-match", label: "domain", kind: "text", when: eap("tls ttls peap") },
        { k: "802-1x.ca-cert", label: "ca cert", kind: "text", hint: "none · /path/to/ca.pem", when: eap("tls ttls peap") },
        { k: "802-1x.ca-cert-password", label: "ca cert password", kind: "secret", when: eap("tls ttls peap") },
        { k: "802-1x.system-ca-certs", label: "system ca certs", kind: "flag", when: eap("tls ttls peap") },
        { k: "802-1x.phase1-peapver", label: "peap version", kind: "pick", opts: ["", "0", "1"], names: ["auto", "0", "1"], when: eap("peap") },
        { k: "802-1x.phase2-auth", label: "inner auth", kind: "pick", opts: ["mschapv2", "md5", "gtc"], names: ["mschapv2", "md5", "gtc"], when: eap("peap") },
        { k: "802-1x.phase2-auth", label: "inner auth", kind: "pick", opts: ["pap", "chap", "mschap", "mschapv2", "gtc", "md5"], names: ["pap", "chap", "mschap", "mschapv2", "gtc", "md5"], when: eap("ttls") },
        { k: "802-1x.phase2-auth", label: "inner auth", kind: "pick", opts: ["gtc", "mschapv2"], names: ["gtc", "mschapv2"], when: eap("fast") },
        { k: "802-1x.phase1-fast-provisioning", label: "pac provisioning", kind: "pick", opts: ["0", "1", "2", "3"], names: ["off", "anonymous", "authenticated", "both"], when: eap("fast") },
        { k: "802-1x.pac-file", label: "pac file", kind: "text", hint: "/path/to/file.pac", when: eap("fast") },
        { k: "802-1x.client-cert", label: "user cert", kind: "text", hint: "/path/to/cert.pem", when: eap("tls") },
        { k: "802-1x.private-key", label: "user key", kind: "text", hint: "/path/to/key.pem", when: eap("tls") },
        { k: "802-1x.private-key-password", label: "key password", kind: "secret", when: eap("tls") },
    ] },
].concat(["ipv4", "ipv6"].map(n => ({ name: n, when: (t, v) => !port(v), fields: [
    n === "ipv4"
        ? { k: "ipv4.method", label: "method", kind: "pick", opts: ["disabled", "auto", "link-local", "manual", "shared"], names: ["off", "auto", "link-local", "manual", "shared"] }
        : { k: "ipv6.method", label: "method", kind: "pick", opts: ["ignore", "disabled", "auto", "dhcp", "link-local", "manual", "shared"], names: ["ignore", "off", "auto", "dhcp only", "link-local", "manual", "shared"] },
    { k: `${n}.addresses`, label: "addresses", kind: "text", hint: n === "ipv4" ? "192.168.1.50/24, …" : "fd00::50/64, …", when: ip(n, "manual auto dhcp") },
    { k: `${n}.gateway`, label: "gateway", kind: "text", hint: n === "ipv4" ? "192.168.1.1" : "fd00::1", when: ip(n, "manual auto dhcp") },
    { k: `${n}.dns`, label: "dns", kind: "text", hint: n === "ipv4" ? "1.1.1.1, 8.8.8.8" : "2606:4700::1111", when: ip(n, "manual auto dhcp") },
    { k: `${n}.dns-search`, label: "search domains", kind: "text", hint: "lan, example.com", when: ip(n, "manual auto dhcp") },
    { k: `${n}.routes`, label: "routes", kind: "text", hint: n === "ipv4" ? "10.0.0.0/8 192.168.1.1 100, …" : "fd01::/64 fd00::1, …", when: ip(n, "manual auto dhcp link-local") },
    { k: `${n}.never-default`, label: "never default route", kind: "flag", when: ip(n, "manual auto dhcp") },
    { k: `${n}.ignore-auto-routes`, label: "ignore auto routes", kind: "flag", when: ip(n, "auto dhcp") },
    { k: `${n}.ignore-auto-dns`, label: "ignore auto dns", kind: "flag", when: ip(n, "auto dhcp") },
    { k: `${n}.may-fail`, label: "may fail · not required", kind: "flag", when: ip(n, "manual auto dhcp link-local") },
].concat(n === "ipv6" ? [{ k: "ipv6.ip6-privacy", label: "privacy", kind: "pick", opts: ["-1", "0", "1", "2"], names: ["default", "off", "prefer public", "prefer temporary"], when: ip(n, "auto dhcp") }] : []) })));

// parsing `nmcli -t -f …`: "key:value", \: and \\ in the value. <hidden> — a password, there isn't one
function parse(text) {
    const v = {};
    for (const l of text.split("\n")) {
        const i = l.indexOf(":");
        if (i < 0) continue;
        const raw = l.slice(i + 1).replace(/\\(.)/g, "$1");
        v[l.slice(0, i)] = raw === "<hidden>" ? "" : raw.replace(/ \(.*\)$/, ""); // "0 (default)" → "0"
    }
    v.sec = sec(v);
    v.allUsers = v["connection.permissions"] ? "no" : "yes";
    v.x8021 = v["802-1x.eap"] ? "yes" : "no";
    for (const k of ["802-1x.ca-cert", "802-1x.client-cert", "802-1x.private-key", "802-1x.pac-file"])
        if (v[k]) v[k] = v[k].replace(/^file:\/\//, "");
    for (const k of ["802-11-wireless.mtu", "802-3-ethernet.mtu"])
        if (v[k] === "0") v[k] = "auto";
    if (v["connection.type"] === "bond") bondParse(v);
    return v;
}

// the visible fields of type t at values v: [{ group } | a field with a string label]
function visible(t, v) {
    const out = [];
    for (const g of groups) {
        if (g.when && !g.when(t, v)) continue;
        const fs = g.fields.filter(f => !f.when || f.when(t, v));
        if (!fs.length) continue;
        out.push({ group: g.name });
        for (const f of fs) out.push(Object.assign({}, f, { label: typeof f.label === "function" ? f.label(t, v) : f.label ?? "" }));
    }
    return out;
}

// what to write: { set: [k, v, k, v…] for `nmcli connection modify|add`, drop: settings for `remove` }.
// We write only visible fields that differ from what was there (new — was = {}), and passwords if they were typed. user — for «not all users»
function writes(t, was, v, user) {
    const set = [], drop = [];
    const put = (k, x) => set.push(k, x);
    let bondChanged = false;
    for (const f of visible(t, v)) {
        if (!f.k || f.k === "sec" || f.k === "x8021" || f.kind === "ports") continue;
        const x = v[f.k] ?? "";
        if (f.kind === "secret") {
            if (x) put(f.k, f.out ? f.out(x) : x);
            continue;
        }
        if (x === (was[f.k] ?? "")) continue;
        if (f.k.startsWith("bond:")) bondChanged = true;
        else if (f.k === "allUsers") put("connection.permissions", x === "yes" ? "" : `user:${user}`);
        else put(f.k, x);
    }
    if (bondChanged) put("bond.options", bondOptions(v));
    if (t === WIFI && v.sec !== (was.sec ?? "none")) {
        const km = { "wep": "none", "wep-pass": "none", "dynamic-wep": "ieee8021x", "leap": "ieee8021x", "suite-b": "wpa-eap-suite-b-192" }[v.sec] ?? v.sec;
        if (v.sec === "none") drop.push("802-11-wireless-security");
        else put("802-11-wireless-security.key-mgmt", km);
        if (/^wep/.test(v.sec)) put("802-11-wireless-security.wep-key-type", v.sec === "wep" ? "1" : "2");
        if (v.sec === "leap") put("802-11-wireless-security.auth-alg", "leap");
        if (v.sec === "dynamic-wep" && !set.includes("802-11-wireless-security.auth-alg")) put("802-11-wireless-security.auth-alg", "open");
    }
    // there was 802.1x, it's no longer needed — remove it, otherwise NM complains about the extra
    if (was["802-1x.eap"] && !eapOn(t, v)) drop.push("802-1x");
    return { set, drop };
}

// a new one's defaults, like nmtui's. extra — what's set from outside (a port: controller, port-type)
function fresh(t, ssid, s, extra) {
    const name = { [WIFI]: ssid || "Wi-Fi", [WIRED]: "Wired", pppoe: "DSL", infiniband: "InfiniBand", bond: "bond0", bridge: "bridge0",
        team: "team0", vlan: "VLAN", "ip-tunnel": "tunnel0", wireguard: "wg0" }[t] ?? t;
    const v = { "connection.id": name, "connection.autoconnect": "yes", allUsers: "yes", "connection.metered": "unknown",
        "ipv4.method": "auto", "ipv6.method": "auto", "ipv4.may-fail": "yes", "ipv6.may-fail": "yes", sec: "none", x8021: "no" };
    // virtual ones need a device name
    if (["bond", "bridge", "team", "ip-tunnel", "wireguard"].includes(t)) v["connection.interface-name"] = name;
    if (t === WIFI) Object.assign(v, { "802-11-wireless.ssid": ssid || "", "802-11-wireless.mode": "infrastructure", sec: s || "wpa-psk" });
    if (["dynamic-wep", "wpa-eap", "suite-b"].includes(v.sec)) Object.assign(v, { "802-1x.eap": "peap", "802-1x.phase2-auth": "mschapv2" });
    if (t === "bond") Object.assign(v, { "bond:mode": "balance-rr", "bond:monitor": "mii", "bond:miimon": "100" });
    if (t === "bridge") Object.assign(v, { "bridge.stp": "yes", "bridge.multicast-snooping": "yes" });
    if (t === "infiniband") v["infiniband.transport-mode"] = "datagram";
    if (t === "ip-tunnel") v["ip-tunnel.mode"] = "gre";
    if (t === "wireguard") Object.assign(v, { "wireguard.peer-routes": "yes", "ipv4.method": "disabled", "ipv6.method": "disabled" });
    return Object.assign(v, extra || {});
}
