import QtQuick
import qs
import qs.components
import qs.settings
import "../prefs"

// display, formerly the DISPLAY section in Prefs: brightness as a big ring (live, from sysfs), the screen as dots — with scale the dots get larger
// and sparser, scale, hertz, vrr, night light. Below — other screens: which side of this one each sits on (the mouse crosses over at
// that edge), mirror or off; with none connected — where a new one goes. Everything — Rules (rules.json), Rules.monitor() applies it
Sheet {
    id: root
    caption: `display · ${Rules.mon.name.toLowerCase()} · ${Rules.hz} hz`

    // ---- other screens. The one being arranged: picked, or the first connected; none — «any new screen» (newSide) ----
    property string pickName: ""
    readonly property var others: Rules.screens.filter(x => x.name !== Rules.mon.name)
    readonly property var target: others.find(x => x.name === pickName) ?? others[0] ?? null
    readonly property string choice: target ? (Rules.store.screens[target.name] ?? Rules.store.newSide) : Rules.store.newSide
    readonly property bool extend: ["left", "right", "up", "down"].includes(choice)
    readonly property var sides: ["left", "right", "up", "down"]
    function choose(x) {
        if (target) Rules.setScreen(target.name, x);
        else Rules.setNewSide(x);
    }

    // the screen as dots: with scale the dots get larger and sparser
    readonly property Component dots: Component {
        Column {
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
            Lb { text: `${Math.round(Rules.mon.w / Rules.scale)} × ${Math.round(Rules.mon.h / Rules.scale)} logical · native ${Rules.mon.w} × ${Rules.mon.h}` }
        }
    }
    // the layout: this screen in the middle, a slot on each side; the lit slot — where the other screen sits. A click picks it
    readonly property Component layout: Component {
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
    }

    Lb { topPadding: 8; bottomPadding: 4; text: "this screen" }
    Opt {
        visible: Sys.hasBri
        title: "Brightness"
        hint: "How bright the screen is."
        about: "Changes as you turn the dial. The brightness keys change it too."
        value: `${bri.v} %`
        Dial { id: bri; size: 72; n: 30; live: true; value: Math.round(Sys.bri * 100); onMoved: v => Sys.setBri(v / 100) }
    }
    // the brightness key step: divisions per scale (Backlight.steps)
    Opt {
        visible: Sys.hasBri
        title: "Brightness key step"
        hint: "How much one press of a brightness key changes."
        about: "Smaller steps give finer control, bigger steps get from dark to bright in fewer presses."
        value: ["2.5 %", "5 %", "10 %"][[40, 20, 10].indexOf(Theme.state.briSteps)] ?? ""
        Pick { opts: ["2.5%", "5%", "10%"]; cur: [40, 20, 10].indexOf(Theme.state.briSteps); onPicked: i => Theme.state.briSteps = [40, 20, 10][i] }
    }
    Opt {
        wide: true
        title: "Scale"
        hint: "How big everything looks."
        about: "Larger scale makes text and windows bigger but fits less on screen. Auto picks one from the screen's size and resolution."
        value: Rules.scales[Rules.scaleIdx] === "auto" ? "auto" : `${Rules.scales[Rules.scaleIdx]} ×`
        preview: root.dots
        Pick { opts: Rules.scales; cur: Rules.scaleIdx; onPicked: i => Rules.setScale(i) }
    }
    Opt {
        wide: Rules.rates.length > 3
        title: "Refresh rate"
        hint: "How many times a second the picture updates."
        about: "Higher feels smoother, especially scrolling and games, and uses a bit more battery. Ultra power mode drops to the lowest while it's on."
        value: `${Rules.refreshHz} Hz`
        Pick { opts: Rules.rates.map(String); cur: Rules.rates.indexOf(Rules.refreshHz); onPicked: i => { Rules.store.refresh = Rules.rates[i]; Rules.monitor(); } }
    }
    // vrr: the screen adapts its rate to the game — no stutter or tearing. fullscreen — only for a fullscreen window
    Opt {
        title: "Variable refresh"
        hint: "Match the screen to the game's frame rate."
        about: "Stops stutter and tearing when a game can't keep up with the refresh rate. Fullscreen turns it on only for a fullscreen window, which avoids flicker on the desktop."
        value: ["off", "on", "fullscreen"][Rules.store.vrr] ?? ""
        Pick { opts: ["off", "on", "fullscreen"]; cur: Rules.store.vrr; onPicked: i => { Rules.store.vrr = i; Rules.monitor(); } }
    }

    Lb { topPadding: 40; bottomPadding: 4; text: "night light" }
    Opt {
        title: "Night light"
        hint: "Warmer colors, easier on the eyes at night."
        about: "Cuts blue light by tinting the screen orange. The warmth below sets how strong it is."
        value: Sys.night ? "on" : "off"
        Switch { on: Sys.night; onFlip: Sys.toggleNight() }
    }
    Opt {
        title: "Warmth"
        hint: "How orange the night light is."
        about: "In kelvin: lower is warmer and more orange, 6500 is neutral daylight."
        value: `${warm.v} K`
        Dial { id: warm; size: 72; from: 2500; to: 6500; step: 100; value: Rules.store.warmth; onMoved: v => { Rules.store.warmth = v; if (Rules.store.night) Rules.night(); } }
    }

    Lb { topPadding: 40; bottomPadding: 4; text: "other screens" }
    Opt {
        visible: root.others.length > 1
        title: "Screen"
        hint: "Which connected screen to arrange."
        about: root.target?.desc ?? ""
        value: root.target?.name ?? ""
        Choose { names: root.others.map(x => x.name); cur: root.others.indexOf(root.target); onPicked: i => root.pickName = root.others[i].name }
    }
    Opt {
        visible: !!root.target
        title: "Use as"
        hint: root.target ? `${root.target.name}${root.target.desc ? " · " + root.target.desc : ""}` : ""
        about: "Extend gives you more desktop. Mirror shows the same picture on both. Off ignores the screen."
        value: root.extend ? "extend" : root.choice
        preview: root.layout
        Pick {
            opts: ["extend", "mirror", "off"]
            cur: root.choice === "mirror" ? 1 : root.choice === "off" ? 2 : 0
            onPicked: i => root.choose(i === 1 ? "mirror" : i === 2 ? "off" : root.extend ? root.choice : Rules.store.newSide)
        }
    }
    Opt {
        visible: root.extend || !root.target
        title: root.target ? "Side" : "New screens go"
        hint: root.target ? "Where it sits next to this one." : "None connected. Pick where a new one will sit."
        about: "The mouse crosses between the screens at that edge. Click a slot on the right, or pick it here."
        value: ["left", "right", "above", "below"][root.sides.indexOf(root.choice)] ?? ""
        preview: root.layout
        Pick { opts: ["left", "right", "above", "below"]; cur: root.sides.indexOf(root.choice); onPicked: i => root.choose(root.sides[i]) }
    }
}
