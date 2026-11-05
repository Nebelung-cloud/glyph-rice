import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.components
import "../prefs"

// the agent window (system/agent.py): bluetooth asks for a code when pairing, the network — a password. Questions in turn, one at a time.
// ↵ — yes, esc — no. «show» — show a code, no answer expected: dismissed by the button, after a minute or by a cancel
PanelWindow {
    id: root

    property var asks: []
    readonly property var cur: asks[0] ?? null
    function take(m) {
        if (m.kind === "cancel") asks = asks.filter(a => a.id !== m.id);
        else if (m.kind === "show") asks = asks.filter(a => !(a.kind === "show" && a.device === m.device)).concat([m]);
        else asks = asks.concat([m]);
    }
    function reply(ok) {
        const a = cur;
        if (!a) return;
        asks = asks.slice(1);
        if (a.kind === "show") return;
        const values = {};
        if (ok && a.kind === "secret") a.fields.forEach((f, i) => values[f.key] = fields.itemAt(i)?.text ?? "");
        if (ok && (a.kind === "pin" || a.kind === "passkey")) values.pin = pin.text.trim();
        agent.write(JSON.stringify({ id: a.id, ok, values }) + "\n");
    }

    // crashed (no python-dbus, the bus) — five tries with a pause, then without the agent
    property int fails: 0
    Process {
        id: agent
        running: true
        stdinEnabled: true
        command: ["python3", Quickshell.shellPath("system/agent.py")]
        stdout: SplitParser { onRead: l => { try { root.take(JSON.parse(l)); } catch (e) {} } }
        onExited: {
            root.asks = [];
            if (++root.fails < 5) again.start();
        }
    }
    Timer { id: again; interval: 3000; onTriggered: agent.running = true }
    Timer { running: root.cur?.kind === "show"; interval: 60000; onTriggered: root.reply(false) }

    // a new question — the fields are clean, focus in the first one
    onCurChanged: if (cur) Qt.callLater(() => {
        pin.text = "";
        for (let i = 0; i < fields.count; i++) fields.itemAt(i).text = "";
        if (cur.kind === "pin" || cur.kind === "passkey") pin.focusIn();
        else if (fields.count) fields.itemAt(0).focusIn();
        else card.forceActiveFocus();
    })

    readonly property bool bt: !!cur && cur.kind !== "secret"
    readonly property string head: !cur ? "" : bt ? "bluetooth · pairing"
        : `${cur.type === "vpn" ? "vpn" : cur.type === "802-3-ethernet" ? "ethernet" : cur.type === "802-11-wireless" ? "wi-fi" : "network"} · password`
    readonly property string title: !cur ? "" : bt ? cur.device : cur.title
    readonly property string what: !cur ? "" : ({
        "confirm": "does this code match the one on the device?",
        "pin": "enter the pin for this device · often 0000 or 1234",
        "passkey": "enter the code shown on the device",
        "authorize": "allow this device to pair?",
        "service": `allow it to use a service · ${(cur.service ?? "").slice(0, 8)}`,
        "show": "type this code on the device, then press enter there",
        "secret": cur.retry ? "that didn't work · try again" : cur.user ? `signing in as ${cur.user}` : "this network needs a password"
    })[cur.kind] ?? ""

    visible: !!cur
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "glyph-agent"

    Rectangle { anchors.fill: parent; color: Theme.dim; opacity: 0.5 }

    Stage {
        Rectangle {
            id: card
            anchors.centerIn: parent
            width: 620
            height: col.height + 72
            radius: Theme.corner(40)
            color: Theme.s1
            border { width: 1; color: Theme.s2 }
            focus: true
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Escape) root.reply(false);
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.reply(true);
                else return;
                e.accepted = true;
            }

            Column {
                id: col
                x: 36
                y: 36
                width: parent.width - 72
                spacing: 18
                Lb { text: root.head }
                Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText; text: root.title; font { family: Theme.ui; pixelSize: 30; weight: Font.DemiBold } color: Theme.fg }
                Num { visible: !!root.cur?.code; text: root.cur?.code ?? ""; font.pixelSize: 96; font.letterSpacing: 8 }
                Lb { width: parent.width; wrapMode: Text.Wrap; text: root.what; color: root.cur?.retry ? Theme.red : Theme.grey }

                Field { id: pin; visible: root.cur?.kind === "pin" || root.cur?.kind === "passkey"; width: parent.width; label: "code"; onAccepted: root.reply(true) }
                Repeater {
                    id: fields
                    model: root.cur?.kind === "secret" ? root.cur.fields : []
                    Field {
                        required property var modelData
                        required property int index
                        width: col.width
                        label: modelData.label
                        secret: true
                        // the last field — ↵ submits, earlier ones — to the next
                        onAccepted: index === fields.count - 1 ? root.reply(true) : fields.itemAt(index + 1).focusIn()
                    }
                }

                Row {
                    spacing: 14
                    Act {
                        visible: root.cur?.kind !== "show"
                        icon: "\u{F012C}"
                        text: { const k = root.cur?.kind; return k === "secret" ? "connect" : k === "confirm" ? "codes match" : k === "service" || k === "authorize" ? "allow" : "pair"; }
                        onHit: root.reply(true)
                    }
                    Act { icon: "\u{F0156}"; text: root.cur?.kind === "show" ? "done" : "cancel"; onHit: root.reply(false) }
                }
            }
        }
    }
}
