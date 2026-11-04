import QtQuick
import Quickshell
import Quickshell.Services.Polkit
import Quickshell.Wayland
import qs
import qs.components
import "../prefs"

// the password prompt for polkit (pkexec, nmcli hostname, firewall, battery…) — the shell's own agent, a card on the overlay
// layer, so it shows above System and the other panels and gets the keyboard. ↵ — authenticate, esc — cancel.
// polkit-gnome is the fallback: hypr starts it when glyph isn't the shell, and we start it ourselves if our agent didn't register
PanelWindow {
    id: root

    PolkitAgent { id: agent }
    readonly property var flow: agent.isActive ? agent.flow : null
    property string err

    Timer {
        running: true
        interval: 4000
        onTriggered: if (!agent.isRegistered) Quickshell.execDetached(["sh", "-c", "pgrep -f polkit-gnome-authentication-agent >/dev/null || exec /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"])
    }
    Connections {
        target: root.flow
        ignoreUnknownSignals: true
        function onAuthenticationFailed() {
            root.err = "wrong password · try again";
            pw.text = "";
        }
        function onIsResponseRequiredChanged() { if (root.flow?.isResponseRequired) pw.focusIn(); }
    }
    onFlowChanged: {
        err = "";
        pw.text = "";
        if (flow) Qt.callLater(() => pw.focusIn());
    }
    function submit() {
        if (!flow?.isResponseRequired) return;
        err = "";
        flow.submit(pw.text);
        pw.text = "";
    }
    function cancel() { flow?.cancelAuthenticationRequest(); }

    visible: !!flow
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "glyph-agent"

    Rectangle { anchors.fill: parent; color: Theme.dim; opacity: 0.5 }

    Stage {
        Rectangle {
            anchors.centerIn: parent
            width: 620
            height: col.height + 72
            radius: 40
            color: Theme.s1
            border { width: 1; color: Theme.s2 }
            Keys.onEscapePressed: root.cancel()

            Column {
                id: col
                x: 36
                y: 36
                width: parent.width - 72
                spacing: 18
                Lb { text: "authentication · needs your password" }
                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: root.flow?.message ?? ""
                    font { family: Theme.ui; pixelSize: 22; weight: Font.DemiBold }
                    color: Theme.fg
                }
                Lb { text: `as ${root.flow?.selectedIdentity?.displayName || root.flow?.selectedIdentity?.name || Quickshell.env("USER")}` }
                Field {
                    id: pw
                    width: parent.width
                    label: (root.flow?.inputPrompt ?? "password").replace(/:\s*$/, "") || "password"
                    secret: !(root.flow?.responseVisible ?? false)
                    onAccepted: root.submit()
                }
                Lb {
                    width: parent.width
                    wrapMode: Text.Wrap
                    visible: !!root.err || !!root.flow?.supplementaryMessage
                    text: root.err || root.flow?.supplementaryMessage || ""
                    color: root.err || root.flow?.supplementaryIsError ? Theme.red : Theme.grey
                }
                Row {
                    spacing: 14
                    Act { icon: "\u{F0341}"; text: "authenticate"; onHit: root.submit() }
                    Act { icon: "\u{F0156}"; text: "cancel"; onHit: root.cancel() }
                }
            }
        }
    }
}
