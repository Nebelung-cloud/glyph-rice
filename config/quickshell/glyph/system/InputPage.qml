import QtQuick
import qs
import qs.components
import qs.settings
import "../prefs"

// ---- INPUT: rows for the keyboard and the pointer. The repeat rows preview a held key: the first dot at once, a delay pause,
// then rate per second, from the live dials ----
Sheet {
    id: inp
    property bool live
    caption: "input · keyboard · touchpad"
    property int n: 0 // how many are «typed»; 0 — the key is released
    Timer {
        running: inp.live
        repeat: true
        interval: inp.n === 0 ? 700 : inp.n === 1 ? delay.v : 1000 / rate.v
        onTriggered: inp.n = (inp.n + 1) % 31
    }
    function set(k, v) { Rules.store[k] = v; Rules.input(); }
    readonly property Component held: Component {
        Row {
            spacing: 24
            Rectangle {
                width: 96
                height: 96
                radius: Theme.corner(26)
                color: inp.n ? Theme.fg : Theme.s1
                border { width: 1; color: Theme.s2 }
                Num { anchors.centerIn: parent; text: "A"; font.pixelSize: 48; color: inp.n ? Theme.ink : Theme.fg }
            }
            Grid {
                anchors.verticalCenter: parent.verticalCenter
                columns: 15
                spacing: 8
                Repeater {
                    model: 30
                    Rectangle {
                        required property int index
                        width: 14
                        height: 14
                        radius: 7
                        color: index < inp.n ? Theme.fg : Theme.s2
                    }
                }
            }
        }
    }

    Lb { topPadding: 8; bottomPadding: 4; text: "keyboard" }
    Opt {
        title: "Repeat delay"
        hint: "How long to hold a key before it repeats."
        about: "When you hold a key, one letter appears at once. After this pause it starts repeating. Shorter feels snappier, longer avoids accidental repeats."
        value: `${delay.v} ms`
        preview: inp.held
        Dial { id: delay; size: 72; from: 150; to: 600; step: 10; value: Rules.store.repeatDelay; onMoved: v => inp.set("repeatDelay", v) }
    }
    Opt {
        title: "Repeat rate"
        hint: "How fast a held key repeats."
        about: "Letters per second once repeating has started. Higher is faster, handy for deleting or moving through text."
        value: `${rate.v} /s`
        preview: inp.held
        Dial { id: rate; size: 72; from: 10; to: 60; value: Rules.store.repeatRate; onMoved: v => inp.set("repeatRate", v) }
    }
    Opt {
        title: "Layout switch"
        hint: "The keys that change keyboard layout."
        about: "Press these to swap between your keyboard layouts, for example from English to another language."
        value: Rules.switches[Rules.store.kbSwitch]?.[0] ?? ""
        Pick { opts: Rules.switches.map(s => s[0]); cur: Rules.store.kbSwitch; onPicked: i => inp.set("kbSwitch", i) }
    }

    Lb { topPadding: 40; bottomPadding: 4; text: "pointer" }
    Opt {
        title: "Pointer speed"
        hint: "How fast the pointer moves."
        about: "0 is the default. Negative is slower, positive is faster."
        value: `${sens.v}`
        Dial { id: sens; size: 72; from: -100; to: 100; step: 5; value: Rules.store.sens; onMoved: v => inp.set("sens", v) }
    }
    Opt {
        title: "Flat acceleration"
        hint: "The pointer moves the same however fast you swipe."
        about: "Off, quick movements carry the pointer further. On, the distance only depends on how far you move, which many people prefer for games."
        value: Rules.store.flat ? "on" : "off"
        Switch { on: Rules.store.flat; onFlip: inp.set("flat", !Rules.store.flat) }
    }
    Opt {
        title: "Scroll speed"
        hint: "How far one swipe or wheel notch scrolls."
        about: "100 % is the full default distance. Lower scrolls less per movement."
        value: `${scr.v} %`
        Dial { id: scr; size: 72; from: 10; to: 100; step: 5; value: Rules.store.scroll; onMoved: v => inp.set("scroll", v) }
    }
    Opt {
        title: "Natural scroll"
        hint: "Content follows your fingers, like a phone."
        about: "On, swiping up moves the page up. Off, it works like a classic mouse wheel."
        value: Rules.store.natural ? "on" : "off"
        Switch { on: Rules.store.natural; onFlip: inp.set("natural", !Rules.store.natural) }
    }
    Opt {
        title: "Tap to click"
        hint: "A light tap on the touchpad clicks."
        about: "Off, you have to press the touchpad down to click."
        value: Rules.store.tap ? "on" : "off"
        Switch { on: Rules.store.tap; onFlip: inp.set("tap", !Rules.store.tap) }
    }
    Opt {
        title: "Off while typing"
        hint: "The touchpad ignores touches while you type."
        about: "Stops your palm from moving the pointer or clicking by accident while you write."
        value: Rules.store.typingOff ? "on" : "off"
        Switch { on: Rules.store.typingOff; onFlip: inp.set("typingOff", !Rules.store.typingOff) }
    }
}
