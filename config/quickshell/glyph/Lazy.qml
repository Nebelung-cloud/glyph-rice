import QtQuick
import Quickshell
import qs

// a panel built the first time it's needed and freed a while after it closes (a minute; Lite mode — 10 s).
// get() builds it if needed and returns it. Saves the memory and the startup time of panels nobody has opened yet
Scope {
    id: root
    property Component component
    readonly property var item: loader.item
    function get() {
        loader.active = true;
        return loader.item;
    }

    LazyLoader { id: loader; component: root.component }
    Timer {
        id: drop
        interval: Theme.state.lite ? 10000 : 60000
        onTriggered: if (loader.item && !loader.item.visible) loader.active = false
    }
    Connections {
        target: loader.item
        ignoreUnknownSignals: true
        function onVisibleChanged() {
            if (loader.item.visible) drop.stop();
            else drop.restart();
        }
    }
}
