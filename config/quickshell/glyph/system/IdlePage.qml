import QtQuick
import qs
import qs.components
import qs.settings
import "../prefs"

// ---- IDLE: rows of minutes without input: lock, screen off, sleep (61 on the dial — never, stored as 0). The inspector shows
// the scale: the dots dim at each event, awake → locked → screen off → asleep ----
Sheet {
    id: idle
    caption: "idle · minutes without input"
    function set(k, v) { Rules.store[k] = v > 60 ? 0 : v; Rules.idle(); }
    readonly property Component scale: Component {
        Column {
            spacing: 18
            Item {
                id: line
                width: 66 * 11 + 14
                height: 30
                readonly property var at: [Rules.store.lockAfter, Rules.store.dpmsAfter, Rules.store.sleepAfter]
                Repeater {
                    model: 61
                    Rectangle {
                        required property int index
                        readonly property int lvl: line.at.filter(m => m && m <= index).length
                        x: index * 11
                        width: 7
                        height: 7
                        radius: 3.5
                        color: [Theme.fg, Theme.grey, Theme.mute, Theme.s3][lvl]
                    }
                }
                // never — an empty ring past the scale
                Rectangle { x: 66 * 11 - 3; y: -3; width: 13; height: 13; radius: 6.5; color: "transparent"; border { width: 1; color: Theme.mute } }
                Repeater {
                    model: [0, 15, 30, 45, 60]
                    Lb { required property int modelData; x: modelData * 11 + 3 - width / 2; y: 18; text: modelData; px: 10 }
                }
                Lb { x: 66 * 11 + 3 - width / 2; y: 18; text: "never"; px: 10 }
            }
            Row {
                spacing: 26
                Repeater {
                    model: [["awake", Theme.fg], ["locked", Theme.grey], ["dark", Theme.mute], ["asleep", Theme.s3]]
                    Row {
                        required property var modelData
                        spacing: 10
                        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 4; color: parent.modelData[1] }
                        Lb { text: parent.modelData[0]; px: 10 }
                    }
                }
            }
        }
    }

    Lb { topPadding: 8; bottomPadding: 4; text: "when idle" }
    Opt {
        title: "Lock after"
        hint: "Minutes without input before the screen locks."
        about: "After this long without touching the keyboard or mouse, the lock screen comes up. Turn the dial all the way for never."
        value: lk.v > 60 ? "never" : `${lk.v} min`
        preview: idle.scale
        Dial { id: lk; size: 72; from: 1; to: 61; n: 30; text: v > 60 ? "—" : Math.round(v); value: Rules.store.lockAfter || 61; onMoved: v => idle.set("lockAfter", v) }
    }
    Opt {
        title: "Screen off after"
        hint: "Minutes without input before the screen goes dark."
        about: "The display turns off to save power and wear. Any key or movement wakes it. Turn the dial all the way for never."
        value: dp.v > 60 ? "never" : `${dp.v} min`
        preview: idle.scale
        Dial { id: dp; size: 72; from: 1; to: 61; n: 30; text: v > 60 ? "—" : Math.round(v); value: Rules.store.dpmsAfter || 61; onMoved: v => idle.set("dpmsAfter", v) }
    }
    Opt {
        title: "Sleep after"
        hint: Rules.hibernateOn ? "Minutes without input before the computer hibernates." : "Minutes without input before the computer sleeps."
        about: "The computer suspends to save battery. Open apps stay as they were. Turn the dial all the way for never."
        value: zz.v > 60 ? "never" : `${zz.v} min`
        preview: idle.scale
        Dial { id: zz; size: 72; from: 1; to: 61; n: 30; text: v > 60 ? "—" : Math.round(v); value: Rules.store.sleepAfter || 61; onMoved: v => idle.set("sleepAfter", v) }
    }
    Opt {
        visible: Rules.canHibernate
        title: "Sleep into"
        hint: "Light sleep, or save everything to disk."
        about: "Suspend wakes in a second but still uses a little battery. Hibernate saves your session to disk and turns off fully: no battery use, slower to wake."
        value: Rules.store.hibernate ? "hibernate" : "suspend"
        Pick { opts: ["suspend", "hibernate"]; cur: Rules.store.hibernate ? 1 : 0; onPicked: i => { Rules.store.hibernate = i === 1; Rules.idle(); } }
    }
    Opt {
        title: "Caffeine"
        hint: "Stay awake for now, whatever the times above."
        about: "While this is on, the screen never locks, dims or sleeps on its own. Handy for a film or a long download. It isn't saved: it turns off when the shell restarts."
        value: Sys.caffeine ? "on" : "off"
        Switch { on: Sys.caffeine; onFlip: Sys.caffeine = !Sys.caffeine }
    }
    // lid: sleep — as logind decides; the rest — we hold logind, hypr catches the closing (Sys.lid)
    Opt {
        visible: Sys.hasLid
        title: "Closing the lid"
        hint: "What happens when you shut the laptop."
        about: "Sleep suspends as usual. Lock and screen off keep the computer running, handy with an external monitor. Nothing ignores the lid."
        value: Rules.store.lid
        Pick { opts: ["sleep", "lock", "screen off", "nothing"]; cur: ["sleep", "lock", "screen off", "nothing"].indexOf(Rules.store.lid); onPicked: i => Rules.store.lid = ["sleep", "lock", "screen off", "nothing"][i] }
    }
}
