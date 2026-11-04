import QtQuick
import Quickshell.Services.UPower
import qs
import qs.components
import qs.settings
import "../prefs"

// ---- POWER: power modes (Rules.modes) — four circles, the ring lit by strength, the selected one white.
// ultra — power saver plus 60 Hz, no animations, blur or shadows over the settings ----
Page {
    caption: `power · ${Rules.modes[Rules.mode].what} · ${Rules.hz} hz`

    Row {
        spacing: 32
        Repeater {
            model: Rules.modes.slice(0, Rules.modeCount)
            Rectangle {
                id: pc
                required property var modelData
                required property int index
                readonly property bool on: Rules.mode === index
                width: 230
                height: 230
                radius: 115
                color: on ? Theme.fg : Theme.s1
                border { width: activeFocus ? 2 : 1; color: activeFocus || on ? Theme.fg : Theme.s2 }
                Behavior on color { ColorAnimation { duration: Theme.t } }
                activeFocusOnTab: true
                Keys.onPressed: e => {
                    if (e.key !== Qt.Key_Return && e.key !== Qt.Key_Enter && e.key !== Qt.Key_Space) return;
                    Rules.setMode(index);
                    e.accepted = true;
                }
                Ring { anchors { fill: parent; margins: 14 } n: 40; dot: 6; f: (pc.index + 1) / 4; on: pc.on ? Theme.ink : Theme.fg; off: pc.on ? Theme.mute : Theme.s3 }
                Column {
                    anchors.centerIn: parent
                    spacing: 10
                    Num { anchors.horizontalCenter: parent.horizontalCenter; text: pc.modelData.short; font.pixelSize: 54; color: pc.on ? Theme.ink : Theme.fg }
                    Lb { anchors.horizontalCenter: parent.horizontalCenter; text: pc.modelData.name; color: pc.on ? Theme.ink : Theme.grey }
                }
                TapHandler { onTapped: Rules.setMode(pc.index) }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
            }
        }
    }
    Lb { text: Rules.store.ultra ? `ultra · ${Rules.rates[0]} hz, no motion, no blur, no shadows — your settings come back when you leave` : "cpu profile only · hz, motion and looks stay yours" }
    Lb { visible: !PowerProfiles.hasPerformanceProfile; text: "no performance profile on this machine" }
    // Lite mode: fewer effects for slower machines (Theme.state.lite); turned on by itself on first run under ~7.5 GB of RAM
    Row {
        spacing: 24
        Toggle { text: "lite mode"; on: Theme.state.lite; onFlip: { Theme.state.lite = !Theme.state.lite; Theme.state.liteSet = true; } }
        Lb { anchors.verticalCenter: parent.verticalCenter; width: 620; wrapMode: Text.Wrap; text: "for slower machines · no blur or shadows, a still wallpaper and orb, no cat or cava, overview snapshots instead of live, no background terminal" }
    }
}
