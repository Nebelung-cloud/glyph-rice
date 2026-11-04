pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// notifications: a new one — the island at the top and a Glyph flash, history — as cards in quick settings
Singleton {
    id: root

    readonly property var list: server.trackedNotifications.values
    property var times: ({}) // id → when it arrived: Notification has no time of its own
    signal arrived(var n)

    // progress of long tasks — the hint value (notify-send -h int:value:64 …): the bottom Glyph bar. One that reached 100 is no longer
    // a task: otherwise a notification left by an app would keep the bar lit until closed
    readonly property var task: list.slice().reverse().find(n => n.hints?.value !== undefined && n.hints.value < 100) ?? null

    NotificationServer {
        id: server
        actionsSupported: true
        imageSupported: true
        keepOnReload: false
        onNotification: n => {
            n.tracked = true;
            root.times = Object.assign({}, root.times, { [n.id]: Date.now() });
            if (!Theme.state.dnd || n.urgency === NotificationUrgency.Critical) root.arrived(n);
        }
    }

    function clear() { for (const n of list.slice()) n.dismiss(); }
    function ago(n, now) {
        const m = Math.floor((now - (times[n.id] ?? now)) / 60000);
        return m < 1 ? "now" : m < 60 ? `${m} min` : `${Math.floor(m / 60)} h`;
    }

    // the count — into the state: the lock shows «3 notifications»
    onListChanged: if (Theme.state.unread !== list.length) Theme.state.unread = list.length
}
