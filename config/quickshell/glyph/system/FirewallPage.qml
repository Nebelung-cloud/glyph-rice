import QtQuick
import Quickshell.Io
import qs
import qs.components
import "../prefs"
import "fw.js" as Fw

// ufw: on/off, what to do with incoming, outgoing and routed traffic, logging, rules (a click removes one), a new rule.
// We read ufw's files without root, change them via pkexec ufw — asks for the password. No ufw — no section (System)
Sheet {
    id: root
    property bool live
    caption: `firewall · ufw · ${conf.ENABLED === "yes" ? "on" : "off"}`

    property var conf: ({})
    property var list: []
    function read() { files.running = true; }
    onLiveChanged: if (live) read()
    Process {
        id: files
        command: ["sh", "-c", "cat /etc/ufw/ufw.conf /etc/default/ufw; echo '#--'; cat /etc/ufw/user.rules /etc/ufw/user6.rules 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [c, r] = text.split("#--");
                root.conf = Fw.conf(c);
                root.list = Fw.rules(r ?? "");
            }
        }
    }

    property string msg
    function ufw(a) {
        msg = "asking for your password…";
        run.command = ["pkexec", "ufw"].concat(a);
        run.running = true;
    }
    Process {
        id: run
        stderr: StdioCollector { id: err }
        onExited: code => {
            root.msg = code === 0 ? "" : code === 126 || code === 127 ? "not changed · password dialog closed" : (err.text.trim().split("\n").pop() || "ufw failed");
            root.read();
        }
    }

    // DROP/ACCEPT/REJECT → the way ufw says it
    readonly property var pols: ["DROP", "ACCEPT", "REJECT"]
    readonly property var polNames: ["deny", "allow", "reject"]

    readonly property string pw: " Changing it asks for your password."
    readonly property var dirs: [["incoming", "DEFAULT_INPUT_POLICY", "Connections other devices start to this computer. Deny is the safe default: nothing reaches you unless a rule below allows it."],
        ["outgoing", "DEFAULT_OUTPUT_POLICY", "Connections this computer starts, like browsing. Allow is normal; deny blocks everything not allowed by a rule."],
        ["routed", "DEFAULT_FORWARD_POLICY", "Traffic passing through this computer to somewhere else. Only matters if it shares its connection or runs virtual machines."]]

    Lb { topPadding: 8; bottomPadding: 4; text: "firewall" }
    Opt {
        title: "Firewall"
        hint: "Block network connections you didn't ask for."
        about: "Filters traffic by the policies and rules below. Keep it on, especially on public Wi-Fi." + root.pw
        value: root.conf.ENABLED === "yes" ? "on" : "off"
        Switch { on: root.conf.ENABLED === "yes"; onFlip: root.ufw(on ? ["disable"] : ["--force", "enable"]) }
    }
    Repeater {
        model: root.dirs
        Opt {
            id: pol
            required property var modelData
            title: modelData[0][0].toUpperCase() + modelData[0].slice(1)
            hint: `What happens to ${modelData[0]} traffic no rule matches.`
            about: modelData[2] + " Reject also tells the other side it was refused; deny stays silent."
            value: root.polNames[root.pols.indexOf(root.conf[modelData[1]] ?? "")] ?? ""
            Pick { opts: root.polNames; cur: root.pols.indexOf(root.conf[pol.modelData[1]] ?? ""); onPicked: i => root.ufw(["default", root.polNames[i], pol.modelData[0]]) }
        }
    }
    Opt {
        wide: true
        title: "Logging"
        hint: "How much blocked traffic gets written to the system log."
        about: "Low logs blocked connections, higher levels log more and fill the log faster. Off logs nothing." + root.pw
        value: root.conf.LOGLEVEL ?? "off"
        Pick { opts: ["off", "low", "medium", "high", "full"]; cur: ["off", "low", "medium", "high", "full"].indexOf(root.conf.LOGLEVEL ?? "off"); onPicked: i => root.ufw(["logging", ["off", "low", "medium", "high", "full"][i]]) }
    }

    Lb { topPadding: 40; bottomPadding: 4; text: root.list.length ? `rules · ${root.list.length}` : "rules · none yet" }
    Repeater {
        model: root.list
        Opt {
            id: rule
            required property var modelData
            title: `${modelData.action} ${modelData.what}`
            hint: `${modelData.dir === "out" ? "to" : "from"} ${modelData.from}${modelData.iface ? ` · on ${modelData.iface}` : ""} · ${modelData.dir}`
            about: "An exception to the policies above: matching traffic is " + ({ allow: "let through", deny: "dropped", reject: "refused", limit: "let through, but an address making many connections in a short time is blocked" }[modelData.action] ?? modelData.action) + "." + root.pw
            value: modelData.action
            Act { icon: "\u{F0A7A}"; text: "remove"; onHit: root.ufw(["delete"].concat(rule.modelData.spec)) }
        }
    }

    // ---- a new rule ----
    QtObject { id: add; property int action: 0; property int dir: 0; property int proto: 0 }
    Lb { topPadding: 40; bottomPadding: 4; text: "new rule" }
    Opt {
        title: "Do"
        hint: "What happens to matching traffic."
        about: "Allow lets it through, deny drops it silently, reject refuses it openly. Limit allows it but blocks an address that connects too often, good for SSH."
        value: ["allow", "deny", "reject", "limit"][add.action]
        Pick { opts: ["allow", "deny", "reject", "limit"]; cur: add.action; onPicked: i => add.action = i }
    }
    Opt {
        title: "Traffic"
        hint: "Coming in, or going out."
        about: "In matches connections to this computer, out matches the ones it starts."
        value: ["in", "out"][add.dir]
        Pick { opts: ["in", "out"]; cur: add.dir; onPicked: i => add.dir = i }
    }
    Opt {
        title: "Protocol"
        hint: "TCP, UDP or both."
        about: "Most services use TCP. Games, calls and DNS often use UDP. Any matches both."
        value: ["any", "tcp", "udp"][add.proto]
        Pick { opts: ["any", "tcp", "udp"]; cur: add.proto; onPicked: i => add.proto = i }
    }
    Opt {
        wide: true
        title: "Port"
        hint: "One port, or a range like 6000:6100."
        about: "Which service the rule is about: 22 is SSH, 80 and 443 are websites. A range needs a protocol."
        value: port.text || "any"
        Field { id: port; width: 466; label: "port"; hint: "22 · 6000:6100" }
    }
    Opt {
        wide: true
        title: "From"
        hint: "One address, a network, or any."
        about: "Limits the rule to some devices, for example 192.168.1.0/24 for your home network. Empty means any."
        value: from.text || "any"
        Field { id: from; width: 466; label: "from"; hint: "any · 192.168.1.0/24" }
    }
    Opt {
        title: "Add the rule"
        hint: "Saves it and applies it right away."
        about: "Adds the rule built above." + root.pw
        value: ["allow", "deny", "reject", "limit"][add.action]
        Act {
            icon: "\u{F0415}"
            text: "add"
            onHit: {
                const a = Fw.args({ action: ["allow", "deny", "reject", "limit"][add.action], dir: ["in", "out"][add.dir], proto: ["any", "tcp", "udp"][add.proto], port: port.text, from: from.text });
                if (typeof a === "string") return root.msg = a;
                root.ufw(a);
                port.text = from.text = "";
            }
        }
    }
    Lb { visible: !!root.msg; topPadding: 16; text: root.msg; color: root.msg.startsWith("asking") ? Theme.fg : Theme.red }
}
