.pragma library

// ufw without root: the rules — "### tuple ### …" lines in /etc/ufw/user{,6}.rules (readable by everyone). From here — the list for the screen
// and what to give `ufw delete …`. Adding — args(): checked before pkexec

const anyAddr = a => a === "0.0.0.0/0" || a === "::/0";

// "### tuple ### allow tcp 22 0.0.0.0/0 any 0.0.0.0/0 in" — action proto dport dst sport src [dapp sapp] dir [comment=…]
function rules(text) {
    const seen = {}, out = [];
    for (const l of text.split("\n")) {
        if (!l.startsWith("### tuple ### ")) continue;
        const t = l.slice(14).split(" ").filter(x => !x.startsWith("comment="));
        if (t.length !== 7 && t.length !== 9) continue;
        const [action, proto, dport, dst, sport, src] = t;
        const apps = t.length === 9 ? [t[6], t[7]] : ["-", "-"]; // dapp sapp
        const [dir, iface] = t[t.length - 1].split("_");
        const spec = [action.split("_")[0], dir]
            .concat(iface ? ["on", iface] : [])
            .concat(proto !== "any" && apps[0] === "-" && apps[1] === "-" ? ["proto", proto] : [])
            .concat(["from", anyAddr(src) ? "any" : src])
            .concat(apps[1] !== "-" ? ["app", apps[1].replace(/%20/g, " ")] : sport !== "any" ? ["port", sport] : [])
            .concat(["to", anyAddr(dst) ? "any" : dst])
            .concat(apps[0] !== "-" ? ["app", apps[0].replace(/%20/g, " ")] : dport !== "any" ? ["port", dport] : []);
        const key = spec.join(" ");
        if (seen[key]) continue; // v4 and v6 of one rule — one row
        seen[key] = true;
        const what = apps[0] !== "-" ? apps[0].replace(/%20/g, " ") : dport === "any" ? "any port" : `${dport}${proto === "any" ? "" : "/" + proto}`;
        out.push({ spec, action: spec[0], dir, what, from: anyAddr(src) ? "anywhere" : src, iface: iface ?? "" });
    }
    return out;
}

const v4 = /^(\d{1,3}\.){3}\d{1,3}(\/\d{1,2})?$/, v6 = /^[0-9a-fA-F:]+(\/\d{1,3})?$/;

// a new rule: { action, dir, port, proto, from } → ufw arguments or an error string
function args(r) {
    const port = r.port.trim(), from = r.from.trim() || "any";
    if (port && !/^\d{1,5}(:\d{1,5})?$/.test(port)) return "port · a number like 22 or a range like 6000:6100";
    if (port.includes(":") && r.proto === "any") return "a port range needs tcp or udp";
    if (from !== "any" && !v4.test(from) && !(v6.test(from) && from.includes(":"))) return "from · any, an ip or a network like 192.168.1.0/24";
    if (!port && from === "any") return "give a port or an address";
    return [r.action, r.dir].concat(r.proto !== "any" ? ["proto", r.proto] : [], ["from", from, "to", "any"], port ? ["port", port] : []);
}

// "KEY=value" and "KEY="value"" from ufw.conf and /etc/default/ufw
function conf(text) {
    const m = {};
    for (const l of text.split("\n")) {
        const x = /^([A-Z_]+)="?([^"]*)"?$/.exec(l.trim());
        if (x) m[x[1]] = x[2];
    }
    return m;
}
