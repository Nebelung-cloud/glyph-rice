import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Wayland
import "lock"

// блокировка — отдельный процесс, как в demonshot: qs -p …/glyph/lock.qml (его зовёт `rice lock`). Разблокировались — выходим.
// Упал шелл — лок живёт; упал лок — Hyprland держит экран закрытым, SUPER+ALT+L поднимает его заново
ShellRoot {
    id: shell
    // hot-reload пересоздаёт WlSessionLock: старый умирает, процесс висит без экрана
    settings.watchFiles: false

    QtObject {
        id: gate
        property string buffer: ""
        property bool fail: false
        property bool leaving: false // пароль принят: поверхность доигрывает уход, потом unlockT снимает лок
        property string note: ""     // что PAM сказал, кроме вопроса: faillock — «account is locked… minutes left», иначе пусто
        readonly property bool busy: pam.active
        function submit() {
            if (!buffer || pam.active || leaving) return;
            note = "";
            pam.start();
        }
    }

    PamContext {
        id: pam
        config: "lock"
        configDirectory: Quickshell.shellPath("pam")
        onResponseRequiredChanged: if (responseRequired) respond(gate.buffer)
        onPamMessage: if (!responseRequired) gate.note = (gate.note + " " + message).trim()
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
        // ponytail: lockedChanged после locked = false не приходит (quickshell 0.3.2), а secure падает — выходим по нему
        onSecureChanged: if (!secure) Qt.quit()

        LockSurface { auth: gate; layout: shell.layout }
    }
}
