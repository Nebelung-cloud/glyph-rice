import QtQuick
import Quickshell.Io
import qs
import qs.components
import "../prefs"
import "fw.js" as Fw

// ufw: on/off, what to do with incoming, outgoing and routed traffic, logging, rules (a click removes one), a new rule.
// We read ufw's files without root, change them via pkexec ufw — asks for the password. No ufw — no section (System)
Page {
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

    Row {
        spacing: 20
        Toggle { text: "firewall"; on: root.conf.ENABLED === "yes"; onFlip: root.ufw(on ? ["disable"] : ["--force", "enable"]) }
        Pick { label: "logging"; opts: ["off", "low", "medium", "high", "full"]; cur: ["off", "low", "medium", "high", "full"].indexOf(root.conf.LOGLEVEL ?? "off"); onPicked: i => root.ufw(["logging", ["off", "low", "medium", "high", "full"][i]]) }
    }
    Column {
        spacing: 12
        Repeater {
            model: [["incoming", "DEFAULT_INPUT_POLICY"], ["outgoing", "DEFAULT_OUTPUT_POLICY"], ["routed", "DEFAULT_FORWARD_POLICY"]]
            Pick {
                required property var modelData
                label: modelData[0]
                opts: root.polNames
                cur: root.pols.indexOf(root.conf[modelData[1]] ?? "")
                onPicked: i => root.ufw(["default", root.polNames[i], modelData[0]])
            }
        }
    }

    Row {
        spacing: 50
        Flickable {
            width: 440
            height: Math.min(contentHeight, 360)
            contentHeight: rl.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: rl
                width: parent.width
                spacing: 4
                Lb { x: 8; bottomPadding: 6; text: root.list.length ? `rules · ${root.list.length} · click to remove` : "rules · none yet" }
                Repeater {
                    model: root.list
                    Line {
                        required property var modelData
                        icon: modelData.action === "allow" ? "\u{F0E1E}" : modelData.action === "limit" ? "\u{F0E1A}" : "\u{F0E1C}"
                        title: `${modelData.action} ${modelData.what}`
                        sub: `${modelData.dir === "out" ? "to" : "from"} ${modelData.from}${modelData.iface ? ` · on ${modelData.iface}` : ""} · ${modelData.dir}`
                        onHit: root.ufw(["delete"].concat(modelData.spec))
                    }
                }
            }
        }
        // ---- a new rule ----
        Column {
            id: add
            width: 466
            spacing: 12
            property int action: 0
            property int dir: 0
            property int proto: 0
            Lb { text: "new rule" }
            Pick { label: "do"; opts: ["allow", "deny", "reject", "limit"]; cur: add.action; onPicked: i => add.action = i }
            Pick { label: "traffic"; opts: ["in", "out"]; cur: add.dir; onPicked: i => add.dir = i }
            Pick { label: "proto"; opts: ["any", "tcp", "udp"]; cur: add.proto; onPicked: i => add.proto = i }
            Field { id: port; width: 466; label: "port"; hint: "22 · 6000:6100" }
            Field { id: from; width: 466; label: "from"; hint: "any · 192.168.1.0/24" }
            Act {
                icon: "\u{F0415}"
                text: "add rule"
                onHit: {
                    const a = Fw.args({ action: ["allow", "deny", "reject", "limit"][add.action], dir: ["in", "out"][add.dir], proto: ["any", "tcp", "udp"][add.proto], port: port.text, from: from.text });
                    if (typeof a === "string") return root.msg = a;
                    root.ufw(a);
                    port.text = from.text = "";
                }
            }
        }
    }
    Lb { visible: !!root.msg; text: root.msg; color: root.msg.startsWith("asking") ? Theme.fg : Theme.red }
}
