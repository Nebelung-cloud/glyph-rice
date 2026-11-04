import QtQuick
import qs
import qs.components
import qs.settings
import "../prefs"

// display, formerly the DISPLAY section in Prefs: brightness as a big ring (live, from sysfs), the screen as dots — with scale the dots get larger
// and sparser, scale, hertz, vrr, night light. Below — other screens: which side of this one each sits on (the mouse crosses over at
// that edge), mirror or off; with none connected — where a new one goes. Everything — Rules (rules.json), Rules.monitor() applies it
Page {
    id: root
    caption: `display · ${Rules.mon.name.toLowerCase()} · ${Rules.hz} hz`
    spacing: 20

    Row {
        spacing: 50
        Column {
            visible: Sys.hasBri
            spacing: 18
            Dial { anchors.horizontalCenter: parent.horizontalCenter; size: 220; n: 60; live: true; label: "brightness"; value: Math.round(Sys.bri * 100); onMoved: v => Sys.setBri(v / 100) }
            // the brightness key step: divisions per scale (Backlight.steps)
            Pick { anchors.horizontalCenter: parent.horizontalCenter; label: "step"; opts: ["2.5%", "5%", "10%"]; cur: [40, 20, 10].indexOf(Theme.state.briSteps); onPicked: i => Theme.state.briSteps = [40, 20, 10][i] }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 18
            Rectangle {
                width: 340
                height: 190
                radius: Theme.corner(22)
                color: Theme.bg
                border { width: 1; color: Theme.s3 }
                Image {
                    readonly property real p: 5 * Rules.scale
                    anchors { fill: parent; margins: 14 }
                    fillMode: Image.Tile
                    source: "data:image/svg+xml," + encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="${p}" height="${p}"><circle cx="${p / 2}" cy="${p / 2}" r="${p * 0.2}" fill="#${Theme.hex(Theme.mute)}"/></svg>`)
                }
            }
            Row {
                spacing: 12
                Num { id: resW; text: Math.round(Rules.mon.w / Rules.scale); font.pixelSize: 52 }
                Num { anchors.baseline: resW.baseline; text: "×"; font.pixelSize: 30; color: Theme.mute }
                Num { anchors.baseline: resW.baseline; text: Math.round(Rules.mon.h / Rules.scale); font.pixelSize: 52 }
            }
            Lb { text: `logical pixels · native ${Rules.mon.w}×${Rules.mon.h}` }
        }
    }
    Pick { label: "scale"; opts: Rules.scales; cur: Rules.scaleIdx; onPicked: i => Rules.setScale(i) }
    Row {
        spacing: 24
        Pick { label: "hz"; opts: Rules.rates.map(String); cur: Rules.rates.indexOf(Rules.refreshHz); onPicked: i => { Rules.store.refresh = Rules.rates[i]; Rules.monitor(); } }
        // vrr: the screen adapts its rate to the game — no stutter or tearing. fullscreen — only for a fullscreen window
        Pick { label: "vrr"; opts: ["off", "on", "fullscreen"]; cur: Rules.store.vrr; onPicked: i => { Rules.store.vrr = i; Rules.monitor(); } }
    }
    Row {
        spacing: 40
        Toggle { anchors.verticalCenter: parent.verticalCenter; text: "night light"; on: Sys.night; onFlip: Sys.toggleNight() }
        Dial { size: 110; label: "warmth · k"; from: 2500; to: 6500; step: 100; value: Rules.store.warmth; onMoved: v => { Rules.store.warmth = v; if (Rules.store.night) Rules.night(); } }
    }

    // ---- other screens. The one being arranged: picked, or the first connected; none — «any new screen» (newSide) ----
    property string pickName: ""
    readonly property var others: Rules.screens.filter(x => x.name !== Rules.mon.name)
    readonly property var target: others.find(x => x.name === pickName) ?? others[0] ?? null
    readonly property string choice: target ? (Rules.store.screens[target.name] ?? Rules.store.newSide) : Rules.store.newSide
    readonly property bool extend: ["left", "right", "up", "down"].includes(choice)
    function choose(x) {
        if (target) Rules.setScreen(target.name, x);
        else Rules.setNewSide(x);
    }

    Row {
        spacing: 40
        // the layout: this screen in the middle, a slot on each side; the lit slot — where the other screen sits
        Item {
            width: 380
            height: 210
            opacity: root.extend ? 1 : 0.4
            Rectangle {
                x: 120
                y: 65
                width: 140
                height: 80
                radius: Theme.corner(14)
                color: Theme.s2
                border { width: 1; color: Theme.s3 }
                Lb { anchors.centerIn: parent; px: 10; text: Rules.mon.name; color: Theme.fg }
            }
            Repeater {
                model: [["left", "left", 8, 75, 100, 60], ["right", "right", 272, 75, 100, 60], ["up", "above", 140, 4, 100, 52], ["down", "below", 140, 154, 100, 52]]
                Rectangle {
                    required property var modelData
                    readonly property bool on: root.choice === modelData[0]
                    x: modelData[2]
                    y: modelData[3]
                    width: modelData[4]
                    height: modelData[5]
                    radius: Theme.corner(12)
                    color: on ? Theme.fg : hov.hovered ? Theme.s1 : "transparent"
                    border { width: 1; color: on ? Theme.fg : Theme.s3 }
                    Behavior on color { ColorAnimation { duration: Theme.t } }
                    Lb { anchors.centerIn: parent; px: 9; text: parent.on ? (root.target?.name ?? "new screen") : parent.modelData[1]; color: parent.on ? Theme.ink : Theme.grey }
                    HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.choose(parent.modelData[0]) }
                }
            }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12
            Lb { text: "other screens" }
            Lb {
                width: 480
                wrapMode: Text.Wrap
                text: !root.target ? "none connected · a new screen goes on the side you pick, the mouse crosses over at that edge"
                    : `${root.target.name}${root.target.desc ? " · " + root.target.desc : ""} · the mouse crosses over at the lit edge`
                color: Theme.fg
            }
            Choose { visible: root.others.length > 1; label: "screen"; names: root.others.map(x => x.name); cur: root.others.indexOf(root.target); onPicked: i => root.pickName = root.others[i].name }
            Pick {
                visible: !!root.target
                label: "use as"
                opts: ["extend", "mirror", "off"]
                cur: root.choice === "mirror" ? 1 : root.choice === "off" ? 2 : 0
                onPicked: i => root.choose(i === 1 ? "mirror" : i === 2 ? "off" : root.extend ? root.choice : Rules.store.newSide)
            }
        }
    }
}
