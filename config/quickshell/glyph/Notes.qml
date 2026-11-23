pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// уведомления: новое — остров сверху и вспышка Glyph, история — карточками в быстрых настройках
Singleton {
    id: root

    readonly property var list: server.trackedNotifications.values
    property var times: ({}) // id → когда пришло: у Notification своего времени нет
    property var sources: ({}) // в том числе отправители без .desktop, даже если история очищена
    signal arrived(var n)

    // прогресс долгих задач — hint value (notify-send -h int:value:64 …): нижняя полоса Glyph
    readonly property var task: list.slice().reverse().find(n => n.hints?.value !== undefined && mode(source(n).key) === "all") ?? null

    function desktopApp(entry) {
        return { key: "desktop:" + entry.id, name: entry.name || entry.id, icon: entry.icon };
    }
    function source(n) {
        const id = n.desktopEntry.trim().replace(/\.desktop$/i, "");
        const name = n.appName.trim();
        if (id) {
            const entry = DesktopEntries.byId(id);
            return entry ? desktopApp(entry) : { key: "desktop:" + id, name: name || id };
        }
        if (name) {
            const entry = DesktopEntries.heuristicLookup(name);
            if (entry) return desktopApp(entry);
            const matches = DesktopEntries.applications.values.filter(e => e.name.toLowerCase() === name.toLowerCase());
            if (matches.length === 1) return desktopApp(matches[0]);
        }
        return { key: "name:" + name.toLowerCase(), name: name || "Unknown app" };
    }
    function remember(app) {
        if (!sources[app.key]) sources = Object.assign({}, sources, { [app.key]: app });
    }
    function rememberMuted() {
        for (const [key, rule] of Object.entries(Theme.state.mutedNoteApps))
            remember({ key, name: typeof rule === "string" ? rule : rule.name });
    }
    function mode(key) {
        const rule = Theme.state.mutedNoteApps[key];
        return typeof rule === "string" ? "off" : rule?.mode ?? "all";
    }
    function setMode(app, mode) {
        remember(app);
        const apps = Object.assign({}, Theme.state.mutedNoteApps);
        if (mode === "all") delete apps[app.key];
        else apps[app.key] = { name: app.name, mode };
        Theme.state.mutedNoteApps = apps;
    }

    Component.onCompleted: rememberMuted()
    Connections {
        target: Theme.state
        function onMutedNoteAppsChanged() {
            root.rememberMuted();
            // Quickshell обновляет tracked-уведомление по ID в обход onNotification.
            for (const n of root.list.slice()) {
                if (root.mode(root.source(n).key) === "off") n.dismiss();
            }
        }
    }

    NotificationServer {
        id: server
        actionsSupported: true
        imageSupported: true
        keepOnReload: false
        onNotification: n => {
            const app = root.source(n);
            root.remember(app);
            const mode = root.mode(app.key);
            if (mode === "off") return;
            n.tracked = true;
            root.times = Object.assign({}, root.times, { [n.id]: Date.now() });
            if (mode === "all" && (!Theme.state.dnd || n.urgency === NotificationUrgency.Critical)) root.arrived(n);
        }
    }

    function clear() { for (const n of list.slice()) n.dismiss(); }
    function ago(n, now) {
        const m = Math.floor((now - (times[n.id] ?? now)) / 60000);
        return m < 1 ? "now" : m < 60 ? `${m} min` : `${Math.floor(m / 60)} h`;
    }

    // счёт — в состояние: лок пишет «3 notifications»
    onListChanged: if (Theme.state.unread !== list.length) Theme.state.unread = list.length
}
