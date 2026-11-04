import QtQuick
import qs
import qs.components
import qs.settings
import "../prefs"

// ---- INPUT: you hold a key — the first dot at once, a delay pause, then rate per second; from the live rings ----
Page {
    id: inp
    property bool live
    caption: "input · keyboard · touchpad"
    property int n: 0 // how many are «typed»; 0 — the key is released
    Timer {
        running: inp.live
        repeat: true
        interval: inp.n === 0 ? 700 : inp.n === 1 ? delay.v : 1000 / rate.v
        onTriggered: inp.n = (inp.n + 1) % 41
    }

    Row {
        spacing: 30
        Rectangle {
            width: 110
            height: 110
            radius: 30
            color: inp.n ? Theme.fg : Theme.s1
            border { width: 1; color: Theme.s2 }
            Num { anchors.centerIn: parent; text: "A"; font.pixelSize: 54; color: inp.n ? Theme.ink : Theme.fg }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 16
            Row {
                spacing: 6
                Repeater {
                    model: 40
                    Rectangle {
                        required property int index
                        width: 14
                        height: 14
                        radius: 7
                        color: index < inp.n ? Theme.fg : Theme.s2
                    }
                }
            }
            Lb { text: `hold a key · first, ${delay.v} ms, then ${rate.v} a second` }
        }
    }
    Row {
        spacing: 40
        Dial { id: delay; label: "delay · ms"; from: 150; to: 600; step: 10; value: Rules.store.repeatDelay; onMoved: v => { Rules.store.repeatDelay = v; Rules.input(); } }
        Dial { id: rate; label: "rate · /s"; from: 10; to: 60; value: Rules.store.repeatRate; onMoved: v => { Rules.store.repeatRate = v; Rules.input(); } }
        Dial { label: "scroll · %"; from: 10; to: 100; step: 5; value: Rules.store.scroll; onMoved: v => { Rules.store.scroll = v; Rules.input(); } }
        Dial { label: "pointer"; from: -100; to: 100; step: 5; value: Rules.store.sens; onMoved: v => { Rules.store.sens = v; Rules.input(); } }
    }
    Row {
        spacing: 20
        Toggle { text: "natural scroll"; on: Rules.store.natural; onFlip: { Rules.store.natural = !Rules.store.natural; Rules.input(); } }
        Toggle { text: "tap to click"; on: Rules.store.tap; onFlip: { Rules.store.tap = !Rules.store.tap; Rules.input(); } }
        Toggle { text: "off while typing"; on: Rules.store.typingOff; onFlip: { Rules.store.typingOff = !Rules.store.typingOff; Rules.input(); } }
        Toggle { text: "flat accel"; on: Rules.store.flat; onFlip: { Rules.store.flat = !Rules.store.flat; Rules.input(); } }
    }
    Pick { label: "layout switch"; opts: Rules.switches.map(s => s[0]); cur: Rules.store.kbSwitch; onPicked: i => { Rules.store.kbSwitch = i; Rules.input(); } }
}
