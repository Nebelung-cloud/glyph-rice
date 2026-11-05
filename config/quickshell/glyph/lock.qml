import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import "lock"

// lock — a separate process, like in demonshot: qs -p …/glyph/lock.qml (`rice lock` calls it). Unlocked — we exit.
// The shell crashed — the lock lives on; the lock crashed — Hyprland keeps the screen closed, SUPER+ALT+L brings it back
ShellRoot {
    id: shell
    // hot-reload recreates WlSessionLock: the old one dies, the process hangs without a screen
    settings.watchFiles: false

    QtObject {
        id: gate
        property string buffer: ""
        property bool fail: false
        property bool leaving: false // password accepted: the surface finishes its exit, then unlockT removes the lock
        property string why: "" // what PAM said, like how long the account is locked for
        readonly property bool busy: pam.active
        function submit() {
            if (!buffer || pam.active || leaving) return;
            why = "";
            pam.start();
        }
    }

    PamContext {
        id: pam
        config: "lock"
        configDirectory: Quickshell.shellPath("pam")
        onResponseRequiredChanged: if (responseRequired) respond(gate.buffer)
        onPamMessage: if (!responseRequired && message) gate.why = message.trim().replace(/\s*\n\s*/g, " · ")
        onCompleted: res => {
            gate.buffer = "";
            if (res === PamResult.Success) {
                gate.leaving = true;
                unlockT.start();
            } else gate.fail = true;
        }
    }
    Timer { id: unlockT; interval: 470; onTriggered: lock.locked = false }

    property string layout: "en"
    function short(name) { return name.slice(0, 2).toLowerCase(); }
    Process {
        running: true
        command: ["sh", "-c", "hyprctl devices -j | jq -r '.keyboards[] | select(.main) | .active_keymap'"]
        stdout: StdioCollector { onStreamFinished: if (text.trim()) shell.layout = shell.short(text.trim()) }
    }
    Connections {
        target: Hyprland
        function onRawEvent(e) { if (e.name === "activelayout") shell.layout = shell.short(e.data.split(",").pop()); }
    }

    WlSessionLock {
        id: lock
        locked: true
        // ponytail: lockedChanged doesn't arrive after locked = false (quickshell 0.3.2), but secure drops — we exit on that
        onSecureChanged: if (!secure) Qt.quit()

        LockSurface { auth: gate; layout: shell.layout }
    }
}
