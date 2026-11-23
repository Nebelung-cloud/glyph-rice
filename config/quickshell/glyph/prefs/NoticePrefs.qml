import QtQuick
import QtQuick.Controls
import Quickshell
import qs
import qs.components

Row {
    id: root

    property bool active: false
    readonly property var modes: ["all", "quiet", "off"]
    spacing: 54

    function stepMode(app, step, wrap = false) {
        const next = modes.indexOf(Notes.mode(app.key)) + step;
        const index = wrap ? next % modes.length : Math.max(0, Math.min(next, modes.length - 1));
        Notes.setMode(app, modes[index]);
    }

    Column {
        width: 390
        spacing: 12
        Lb { text: "pop-ups" }
        Toggle { width: parent.width; text: "Caps Lock"; on: Theme.state.notifyCapsLock; onFlip: Theme.state.notifyCapsLock = !on }
        Toggle { width: parent.width; text: "Keyboard layout"; on: Theme.state.notifyLayout; onFlip: Theme.state.notifyLayout = !on }
        Toggle { width: parent.width; text: "Num Lock"; on: Theme.state.notifyNumLock; onFlip: Theme.state.notifyNumLock = !on }
        Row {
            width: parent.width
            spacing: 12
            Toggle {
                width: (parent.width - parent.spacing) / 2
                text: "Charging"
                on: Theme.state.notifyPower
                onFlip: {
                    if (Theme.state.notifyLowBattery === null) Theme.state.notifyLowBattery = on;
                    Theme.state.notifyPower = !on;
                }
            }
            Toggle {
                width: (parent.width - parent.spacing) / 2
                text: "Low battery"
                on: Theme.state.notifyLowBattery ?? Theme.state.notifyPower
                onFlip: Theme.state.notifyLowBattery = !on
            }
        }
        Toggle { width: parent.width; text: "Over fullscreen"; on: Theme.state.notifyFullscreen; onFlip: Theme.state.notifyFullscreen = !on }
        Toggle { width: parent.width; text: "Do not disturb"; on: Theme.state.dnd; onFlip: Theme.state.dnd = !on }
    }

    Column {
        width: 530
        spacing: 12
        Lb { text: "app notifications" }

        Rectangle {
            width: parent.width
            height: 56
            radius: Theme.corner(28)
            color: Theme.s2
            border { width: search.activeFocus ? 1 : 0; color: Theme.fg }
            Icon { x: 18; anchors.verticalCenter: parent.verticalCenter; text: "\u{F0349}"; color: Theme.grey }
            TextInput {
                id: search
                anchors { left: parent.left; leftMargin: 50; right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                activeFocusOnTab: true
                clip: true
                font { family: Theme.ui; pixelSize: 19 }
                color: Theme.fg
                selectionColor: Theme.mute
                onTextChanged: {
                    apps.currentIndex = 0;
                    apps.positionViewAtBeginning();
                }
                Keys.onDownPressed: apps.forceActiveFocus()
                Text { visible: !search.text; text: "Search apps"; font: search.font; color: Theme.grey }
            }
        }

        ListView {
            id: apps
            width: parent.width
            height: 388
            spacing: 5
            clip: true
            activeFocusOnTab: count > 0
            boundsBehavior: Flickable.StopAtBounds
            keyNavigationEnabled: false
            readonly property var matches: {
                if (!root.active) return [];
                const known = Object.assign({}, Notes.sources);
                for (const entry of DesktopEntries.applications.values) {
                    const app = Notes.desktopApp(entry);
                    if (!entry.noDisplay || known[app.key]) known[app.key] = app;
                }
                const query = search.text.trim().toLowerCase();
                return Object.values(known).filter(a => a.name.toLowerCase().includes(query) || a.key.slice(a.key.indexOf(":") + 1).toLowerCase().includes(query))
                    .sort((a, b) => a.name.localeCompare(b.name) || a.key.localeCompare(b.key));
            }
            model: []
            onMatchesChanged: {
                // Добавление уже видимого приложения в список отправителей не должно сбрасывать прокрутку.
                if (JSON.stringify(matches) !== JSON.stringify(model)) model = matches;
            }
            Keys.onPressed: e => {
                const app = currentItem?.modelData;
                if (e.key === Qt.Key_Up) {
                    if (currentIndex <= 0) search.forceActiveFocus();
                    else decrementCurrentIndex();
                } else if (e.key === Qt.Key_Down) incrementCurrentIndex();
                else if (app && (e.key === Qt.Key_Space || e.key === Qt.Key_Return || e.key === Qt.Key_Enter))
                    root.stepMode(app, 1, true);
                else if (app && (e.key === Qt.Key_Left || e.key === Qt.Key_Right))
                    root.stepMode(app, e.key === Qt.Key_Left ? 1 : -1);
                else return;
                e.accepted = true;
            }
            ScrollBar.vertical: ScrollBar {}
            Lb { anchors.centerIn: parent; visible: apps.count === 0; text: search.text ? "no matching apps" : "no apps found" }

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property string mode: Notes.mode(modelData.key)
                readonly property bool selected: ListView.isCurrentItem && apps.activeFocus
                width: apps.width - 12
                height: 51
                radius: Theme.corner(13)
                color: hovered.hovered || selected ? Theme.s2 : Theme.s1
                border { width: row.selected ? 1 : 0; color: Theme.fg }

                Image {
                    id: icon
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 24
                    source: Quickshell.iconPath(row.modelData.icon || "application-x-executable", "application-x-executable")
                }
                Text {
                    anchors { left: icon.right; leftMargin: 13; right: toggle.left; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    text: row.modelData.name
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    font { family: Theme.ui; pixelSize: 18 }
                    color: Theme.fg
                }
                Rectangle {
                    id: toggle
                    anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    width: 88
                    height: 24
                    radius: 12
                    color: row.mode === "all" ? Theme.fg : Theme.s3
                    Lb {
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.mode
                        px: 10
                        color: row.mode === "all" ? Theme.ink : row.mode === "quiet" ? Theme.fg : Theme.grey
                    }
                    Rectangle {
                        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        width: 6
                        height: width
                        radius: width / 2
                        color: row.mode === "all" ? Theme.ink : row.mode === "quiet" ? Theme.fg : Theme.grey
                    }
                }
                HoverHandler { id: hovered; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: {
                        apps.currentIndex = row.index;
                        apps.forceActiveFocus();
                        root.stepMode(row.modelData, 1, true);
                    }
                }
            }
        }
    }
}
