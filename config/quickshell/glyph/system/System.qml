import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs
import qs.components
import "../prefs"

// the system, like «Settings» on android: network, bluetooth, sound, display, power, battery, input, idle, firewall, apps,
// about. Super+I; the rice look — Prefs, «customize the rice» leads there. Built like Prefs: Doto words on the left, the selected one
// large with a red dot, the section on the right. Battery — if there is one, firewall — if ufw is installed.
// ↑↓ — sections, Tab — through the objects, esc — back out of details, then close
PanelWindow {
    id: root

    signal customizeRequested
    property int sel: 0
    property bool hasUfw: false
    Process { running: true; command: ["sh", "-c", "command -v ufw"]; onExited: code => root.hasUfw = code === 0 }
    readonly property var sections: ["NETWORK", "BLUETOOTH", "SOUND", "DISPLAY", "WORKSPACES", "POWER"]
        .concat(UPower.displayDevice?.isLaptopBattery ? ["BATTERY"] : [], ["INPUT", "IDLE"], hasUfw ? ["FIREWALL"] : [], ["APPS", "ABOUT"])
    readonly property string cur: sections[sel] ?? ""
    readonly property var pages: ({ NETWORK: net, BLUETOOTH: bt, SOUND: sound, DISPLAY: disp, WORKSPACES: wsp, POWER: power, BATTERY: battery, INPUT: input, IDLE: idle, FIREWALL: fw, APPS: apps, ABOUT: about })

    property bool shown: false
    // the window appears a moment before it moves: its first frame (creating the surface) is the slow one, so it lands
    // while nothing is moving yet
    property bool mapped: false
    Timer { running: root.visible && !root.mapped; interval: 20; onTriggered: root.mapped = true }
    Connections { target: root; function onVisibleChanged() { if (!root.visible) root.mapped = false; } }
    property real t: shown && mapped ? 1 : 0
    Behavior on t { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
    function open() {
        shown = true;
        stage.forceActiveFocus();
    }
    function close() { shown = false; }
    // open straight at a section (overview → «workspace settings»)
    function openAt(name) {
        const i = sections.indexOf(name);
        if (i >= 0) sel = i;
        open();
    }
    function toggle() { shown ? close() : open(); }
    function go(i) {
        sel = (i + sections.length) % sections.length;
        stage.forceActiveFocus();
    }
    function back() {
        if (pages[cur]?.back()) return stage.forceActiveFocus();
        close();
    }

    visible: t > 0 || shown
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "glyph-system"

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        opacity: root.t
        MouseArea { anchors.fill: parent; onClicked: stage.forceActiveFocus() }
    }

    Stage {
        id: stage
        opacity: root.t
        focus: true
        // esc and ↑↓ reach here if the focused object didn't eat them
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Up) root.go(root.sel - 1);
            else if (e.key === Qt.Key_Down) root.go(root.sel + 1);
            else if (e.key === Qt.Key_Right && stage.activeFocus) stage.nextItemInFocusChain(true)?.forceActiveFocus();
            else if (e.key === Qt.Key_Escape) root.back();
            else return;
            e.accepted = true;
        }

        Act {
            x: 150
            y: 70
            icon: "\u{F03D8}"
            text: "customize the rice"
            onHit: {
                root.close();
                root.customizeRequested();
            }
        }

        Column {
            x: 150 - 30 * (1 - root.t)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14
            Repeater {
                model: root.sections
                Row {
                    id: word
                    required property string modelData
                    required property int index
                    readonly property bool on: root.sel === index
                    spacing: 22
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: word.on
                        width: 22
                        height: 22
                        radius: 11
                        color: Theme.red
                    }
                    Grow { text: word.modelData; on: word.on; big: 80; small: 38; anchors.verticalCenter: parent.verticalCenter }
                    TapHandler { onTapped: root.go(word.index) }
                }
            }
        }

        Row {
            x: 150
            anchors { bottom: parent.bottom; bottomMargin: 70 }
            spacing: 34
            Lb { text: "↑↓ section" }
            Lb { text: "tab · ↵ pick" }
            Lb { text: "esc back"; TapHandler { onTapped: root.back() } }
        }

        NetPage { id: net; on: root.cur === "NETWORK"; live: root.shown && on }
        BtPage { id: bt; on: root.cur === "BLUETOOTH"; live: root.shown && on }
        SoundPage { id: sound; on: root.cur === "SOUND"; live: root.shown && on }
        DisplayPage { id: disp; on: root.cur === "DISPLAY" }
        WorkspacesPage { id: wsp; on: root.cur === "WORKSPACES"; live: root.shown && on; onDone: root.close() }
        PowerPage { id: power; on: root.cur === "POWER" }
        BatteryPage { id: battery; on: root.cur === "BATTERY"; live: root.shown && on }
        InputPage { id: input; on: root.cur === "INPUT"; live: root.shown && on }
        IdlePage { id: idle; on: root.cur === "IDLE" }
        FirewallPage { id: fw; on: root.cur === "FIREWALL"; live: root.shown && on }
        AppsPage { id: apps; on: root.cur === "APPS"; live: root.shown && on }
        AboutPage { id: about; on: root.cur === "ABOUT"; live: root.shown && on }
    }
}
