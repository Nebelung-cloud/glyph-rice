import QtQuick
import Quickshell.Services.UPower
import qs
import qs.components
import qs.settings
import "../prefs"

// ---- POWER: rows — the power mode (Rules.modes), lite mode. The inspector shows the four modes as circles, the ring lit by
// strength, the set one white. ultra — power saver plus 60 Hz, no animations, blur or shadows over the settings ----
Sheet {
    id: pw
    caption: "power"
    readonly property var modes: Rules.modes.slice(0, Rules.modeCount)
    readonly property Component circles: Component {
        Row {
            spacing: 20
            Repeater {
                model: pw.modes
                Rectangle {
                    id: pc
                    required property var modelData
                    required property int index
                    readonly property bool on: Rules.mode === index
                    width: 160
                    height: 160
                    radius: 80
                    color: on ? Theme.fg : Theme.s1
                    border { width: 1; color: on ? Theme.fg : Theme.s2 }
                    Behavior on color { ColorAnimation { duration: Theme.t } }
                    Ring { anchors { fill: parent; margins: 10 } n: 32; dot: 5; f: (pc.index + 1) / 4; on: pc.on ? Theme.ink : Theme.fg; off: pc.on ? Theme.mute : Theme.s3 }
                    Column {
                        anchors.centerIn: parent
                        spacing: 8
                        Num { anchors.horizontalCenter: parent.horizontalCenter; text: pc.modelData.short; font.pixelSize: 38; color: pc.on ? Theme.ink : Theme.fg }
                        Lb { anchors.horizontalCenter: parent.horizontalCenter; text: pc.modelData.name; px: 10; color: pc.on ? Theme.ink : Theme.grey }
                    }
                    TapHandler { onTapped: Rules.setMode(pc.index) }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }
            }
        }
    }

    Opt {
        title: "Power mode"
        hint: PowerProfiles.hasPerformanceProfile ? "Trade speed for battery life." : "Trade speed for battery life. This machine has no performance profile."
        about: Rules.store.ultra ? `Ultra saves the most: power saver, ${Rules.rates[0]} Hz, no animations, blur or shadows. Your own settings come back when you leave it.`
            : "Sets how hard the processor may work. Only the CPU changes: refresh rate, animations and looks stay as you set them. Ultra also drops to " + Rules.rates[0] + " Hz and turns effects off."
        value: Rules.modes[Rules.mode].name
        preview: pw.circles
        Pick { opts: pw.modes.map(m => m.short.toLowerCase()); cur: Rules.mode; onPicked: i => Rules.setMode(i) }
    }
    // Lite mode: fewer effects for slower machines (Theme.state.lite); turned on by itself on first run under ~7.5 GB of RAM
    Opt {
        title: "Lite mode"
        hint: "Fewer effects, for slower machines."
        about: "Turns off blur and shadows, stills the wallpaper and the orb, hides the cat and cava, uses snapshots instead of live previews in the overview, and skips the background terminal. It turns on by itself on machines with little memory."
        value: Theme.state.lite ? "on" : "off"
        Switch { on: Theme.state.lite; onFlip: { Theme.state.lite = !Theme.state.lite; Theme.state.liteSet = true; } }
    }
}
