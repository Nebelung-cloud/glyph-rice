import QtQuick
import Quickshell
import qs

Scope {
    id: root

    required property string directory
    readonly property var deadlines: Theme.state.noteReminders
    property double now: Date.now()

    function pending(name) { return !!name && deadlines[name] > 0; }

    function remaining(name) {
        const seconds = Math.max(0, Math.ceil((deadlines[name] - now) / 1000));
        return Math.floor(seconds / 60) + ":" + String(seconds % 60).padStart(2, "0");
    }

    function schedule(name, minutes) {
        if (!name || !Number.isInteger(minutes) || minutes < 1 || minutes > 1440) return;
        Theme.state.noteReminders = Object.assign({}, deadlines, { [name]: Date.now() + minutes * 60000 });
    }

    function cancel(name) {
        if (!pending(name)) return;
        const next = Object.assign({}, deadlines);
        delete next[name];
        Theme.state.noteReminders = next;
    }

    onDeadlinesChanged: now = Date.now()

    Timer {
        interval: 1000
        repeat: true
        running: root.directory !== "" && Object.keys(root.deadlines).length > 0
        onTriggered: {
            root.now = Date.now();
            const due = Object.keys(root.deadlines).filter(name => root.deadlines[name] <= root.now);
            if (!due.length) return;
            const next = Object.assign({}, root.deadlines);
            for (const name of due) delete next[name];
            Theme.state.noteReminders = next;
            Quickshell.execDetached(["python3", Quickshell.shellPath("note/notes.py"), "remind", root.directory, ...due]);
        }
    }
}
