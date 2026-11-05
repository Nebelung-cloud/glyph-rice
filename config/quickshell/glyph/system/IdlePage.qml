import QtQuick
import qs
import qs.components
import qs.settings
import "../prefs"

// ---- IDLE: a scale of minutes without input. The dots dim at each event: awake → locked → screen off → asleep.
// The marks drag along it, past 60 — never ----
Page {
    id: idle
    caption: "idle · minutes without input · hypridle"

    Item {
        id: line
        width: 940
        height: 300
        readonly property var at: [lk.v, dpms.v, zz.v]

        Repeater {
            model: 61
            Rectangle {
                required property int index
                readonly property int lvl: line.at.filter(m => m && m <= index).length
                x: index * 14 - 4
                y: 246
                width: 8
                height: 8
                radius: 4
                color: [Theme.fg, Theme.grey, Theme.mute, Theme.s3][lvl]
            }
        }
        // never — an empty ring past the scale
        Rectangle { x: 62 * 14 - 7; y: 243; width: 14; height: 14; radius: 7; color: "transparent"; border { width: 1; color: Theme.mute } }
        Repeater {
            model: [0, 15, 30, 45, 60]
            Lb { required property int modelData; x: modelData * 14 - width / 2; y: 272; text: modelData; px: 10 }
        }
        Lb { x: 62 * 14 - width / 2; y: 272; text: "never"; px: 10 }

        Mark { line: line; step: 14; id: lk; row: 0; label: "lock"; value: Rules.store.lockAfter; onMoved: v => { Rules.store.lockAfter = v; Rules.idle(); } }
        Mark { line: line; step: 14; id: dpms; row: 1; label: "screen off"; value: Rules.store.dpmsAfter; onMoved: v => { Rules.store.dpmsAfter = v; Rules.idle(); } }
        Mark { line: line; step: 14; id: zz; row: 2; label: Rules.hibernateOn ? "sleep · hibernate" : "sleep"; value: Rules.store.sleepAfter; onMoved: v => { Rules.store.sleepAfter = v; Rules.idle(); } }
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
    Row {
        spacing: 24
        Pick { label: "sleep into"; visible: Rules.canHibernate; opts: ["suspend", "hibernate"]; cur: Rules.store.hibernate ? 1 : 0; onPicked: i => { Rules.store.hibernate = i === 1; Rules.idle(); } }
        Toggle { text: "caffeine"; on: Sys.caffeine; onFlip: Sys.caffeine = !Sys.caffeine }
    }
    // lid: sleep — as logind decides; the rest — we hold logind, hypr catches the closing (Sys.lid)
    Row {
        visible: Sys.hasLid
        spacing: 24
        Pick { label: "lid closed"; opts: ["sleep", "lock", "screen off", "nothing"]; cur: ["sleep", "lock", "screen off", "nothing"].indexOf(Rules.store.lid); onPicked: i => Rules.store.lid = ["sleep", "lock", "screen off", "nothing"][i] }
    }
}
