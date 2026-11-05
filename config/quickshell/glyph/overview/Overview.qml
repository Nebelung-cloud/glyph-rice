import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.components
import "../prefs"

// overview, Super+Tab: the workspaces of the current group of ten (how many — Theme.state.wsCount, −/+ right here) as dot tiles, on them
// the windows — live snapshots. The rest about workspaces — System → workspaces («workspace settings»).
// The windows live in one layer above the tiles: a window changed workspace — it moves to its tile by itself (both when dragged and when
// the Super+Alt+N bind fired with the overview open). Drag a window onto a tile — move it (quietly, without going there), click a window —
// focus, a tile — go there, middle click a window — close. ←→↑↓ / 1–0 — a tile, ↵ — go, esc — close
PanelWindow {
    id: root

    signal settingsRequested
    readonly property int n: Theme.state.wsCount

    property bool open: false
    function toggle() { open ? close() : show(); }
    function show() {
        Hyprland.refreshToplevels();
        Hyprland.refreshMonitors();
        sel = Math.max(0, Math.min(n - 1, (Hyprland.focusedWorkspace?.id ?? 1) - 1 - base));
        open = true;
    }
    function close() { open = false; }

    // the window appears a moment before it moves: its first frame (creating the surface) is the slow one, so it lands
    // while nothing is moving yet
    property bool mapped: false
    Timer { running: root.visible && !root.mapped; interval: 20; onTriggered: root.mapped = true }
    Connections { target: root; function onVisibleChanged() { if (!root.visible) root.mapped = false; } }
    property real t: open && mapped ? 1 : 0
    Behavior on t { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
    visible: t > 0 || open
    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "glyph-overview"

    // the group of ten we're in now (1–10, 11–20…), like the Super+N bind
    readonly property int base: Math.floor(((Hyprland.focusedWorkspace?.id ?? 1) - 1) / 10) * 10
    property int sel: 0
    function go(id) {
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${id} })`);
        close();
    }
    // the window address for hl: with 0x (in Quickshell it sometimes comes without)
    function addr(w) { const a = String(w.address); return `address:${a.startsWith("0x") ? a : "0x" + a}`; }
    function moveTo(w, id) { Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${id}, window = "${addr(w)}", follow = false })`); }

    // windows moved, opened, closed — the geometry from hyprctl (lastIpcObject) is fresh only after a refresh
    Connections {
        target: Hyprland
        enabled: root.open
        function onRawEvent(e) { if (/^(openwindow|closewindow|movewindow|changefloatingmode|resizewindow|fullscreen)/.test(e.name)) refresh.restart(); }
    }
    Timer { id: refresh; interval: 60; onTriggered: Hyprland.refreshToplevels() }

    // ---- tiles: up to five in a row at 300 × 169 (16:9) on the 1920 × 1080 canvas, as many rows as needed ----
    readonly property real tw: 300
    readonly property real th: 169
    readonly property real gap: 30
    readonly property int cols: Math.min(5, n)
    readonly property real gx: (1920 - cols * tw - (cols - 1) * gap) / 2
    readonly property real lx: (1920 - 5 * tw - 4 * gap) / 2 // the left edge of the header and hints — like the full grid's
    readonly property real gy: 330
    function tileX(i) { return gx + i % cols * (tw + gap); }
    function tileY(i) { return gy + Math.floor(i / cols) * (th + 80); }
    function tileAt(x, y) {
        for (let i = 0; i < n; i++)
            if (x >= tileX(i) && x <= tileX(i) + tw && y >= tileY(i) && y <= tileY(i) + th) return i;
        return -1;
    }

    function setCount(c) { Theme.state.wsCount = Math.max(1, Math.min(10, c)); sel = Math.min(sel, Theme.state.wsCount - 1); }
    // windows on workspaces past the limit (it was lowered) — not visible on the tiles, we say how many
    readonly property int away: Hyprland.toplevels.values.filter(t => (t.workspace?.id ?? 0) > base + n && (t.workspace?.id ?? 0) <= base + 10).length

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        opacity: root.t // solid, like Prefs: bright windows showing through were distracting
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    Stage {
        id: stage
        opacity: root.t
        focus: root.open
        Keys.onPressed: e => {
            const k = e.key;
            if (k === Qt.Key_Escape) root.close();
            else if (k === Qt.Key_Left) root.sel = (root.sel + root.n - 1) % root.n;
            else if (k === Qt.Key_Right || k === Qt.Key_Tab) root.sel = (root.sel + 1) % root.n;
            else if (k === Qt.Key_Up || k === Qt.Key_Down) root.sel = root.sel < 5 ? Math.min(root.sel + 5, root.n - 1) : root.sel - 5; // the second row, if there is one
            else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) root.go(root.base + root.sel + 1);
            else if (k >= Qt.Key_0 && k <= Qt.Key_9 && ((k - Qt.Key_0) || 10) <= root.n) root.go(root.base + ((k - Qt.Key_0) || 10));
            else if (k === Qt.Key_Minus) root.setCount(root.n - 1);
            else if (k === Qt.Key_Plus || k === Qt.Key_Equal) root.setCount(root.n + 1);
            else return;
            e.accepted = true;
        }

        Column {
            x: root.lx
            y: 150
            spacing: 10
            Lb { text: `overview · ${root.base + 1}–${root.base + root.n}` }
            Num { text: `${String(Hyprland.focusedWorkspace?.id ?? 1).padStart(2, "0")}`; font.pixelSize: 96 }
        }
        // how many workspaces: − 05 +, and everything else — in System
        Row {
            anchors { right: parent.right; rightMargin: root.lx }
            y: 186
            spacing: 14
            Lb { anchors.verticalCenter: parent.verticalCenter; rightPadding: 6; text: "workspaces" }
            Nudge { icon: "\u{F0374}"; on: root.n > 1; onHit: root.setCount(root.n - 1) }
            Num { anchors.verticalCenter: parent.verticalCenter; text: String(root.n).padStart(2, "0"); font.pixelSize: 54 }
            Nudge { icon: "\u{F0415}"; on: root.n < 10; onHit: root.setCount(root.n + 1) }
            Item { width: 14; height: 1 }
            Act { anchors.verticalCenter: parent.verticalCenter; icon: "\u{F0493}"; text: "workspace settings"; onHit: { root.close(); root.settingsRequested(); } }
        }
        Row {
            x: root.lx
            anchors { bottom: parent.bottom; bottomMargin: 70 }
            spacing: 34
            Lb { text: "drag a window to move it" }
            Lb { text: "click · go" }
            Lb { text: "middle click · close" }
            Lb { text: "←→ · ↵ · 1–0 · −/+ count" }
            Lb { visible: root.away > 0; text: `${root.away} window${root.away > 1 ? "s" : ""} past ${String(root.n).padStart(2, "0")}`; color: Theme.fg }
            Lb { text: "esc close"; TapHandler { onTapped: root.close() } }
        }

        // ---- tiles ----
        Repeater {
            model: root.n
            Item {
                id: tile
                required property int index
                readonly property int ws: root.base + index + 1
                readonly property var w: Hyprland.workspaces.values.find(x => x.id === ws) ?? null
                readonly property bool cur: Hyprland.focusedWorkspace?.id === ws
                readonly property bool hot: root.sel === index || stage.drop === index
                // they appear one after another, from the bottom up
                readonly property real show: Math.max(0, Math.min(1, root.t * 2.2 - index * 0.12))
                x: root.tileX(index)
                y: root.tileY(index) + 24 * (1 - show)
                width: root.tw
                height: root.th
                opacity: show

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.corner(22)
                    color: Theme.s1
                    border { width: tile.cur || tile.hot ? 2 : 1; color: tile.cur ? Theme.fg : tile.hot ? Theme.grey : Theme.s2 }
                    Behavior on border.color { ColorAnimation { duration: Theme.t } }
                    // an empty tile — a field of dots, like the screen in DISPLAY
                    Image {
                        anchors { fill: parent; margins: 12 }
                        fillMode: Image.Tile
                        opacity: 0.7
                        source: "data:image/svg+xml," + encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><circle cx="5" cy="5" r="1.4" fill="#${Theme.hex(Theme.s3)}"/></svg>`)
                    }
                }
                Row {
                    y: root.th + 12
                    spacing: 12
                    Num { text: String(tile.ws).padStart(2, "0"); font.pixelSize: 30; color: tile.cur ? Theme.fg : Theme.mute }
                    Lb { anchors.verticalCenter: parent.verticalCenter; text: (tile.w?.toplevels.values.length ?? 0) ? `${tile.w.toplevels.values.length} open` : "empty"; px: 10 }
                }
                TapHandler { onTapped: root.go(tile.ws) }
                HoverHandler { cursorShape: Qt.PointingHandCursor; onHoveredChanged: if (hovered) root.sel = tile.index }
            }
        }
        // the tile a window is being dragged over right now
        property int drop: -1

        // ---- windows: one layer, coordinates — from the tile of their workspace ----
        Repeater {
            model: Hyprland.toplevels.values.filter(t => {
                const id = t.workspace?.id ?? 0;
                return id > root.base && id <= root.base + root.n;
            })
            Item {
                id: win
                required property var modelData
                readonly property var o: modelData.lastIpcObject ?? {}
                readonly property var mon: modelData.monitor?.lastIpcObject ?? {}
                readonly property int idx: (modelData.workspace?.id ?? 1) - root.base - 1
                // the screen's logical size — Hyprland computes the window's at/size in it
                readonly property real mw: (mon.width ?? 1920) / (mon.scale ?? 1)
                readonly property real mh: (mon.height ?? 1080) / (mon.scale ?? 1)
                readonly property real sx: root.tw / mw
                readonly property real sy: root.th / mh
                readonly property real hx: root.tileX(idx) + ((o.at?.[0] ?? 0) - (mon.x ?? 0)) * sx
                readonly property real hy: root.tileY(idx) + ((o.at?.[1] ?? 0) - (mon.y ?? 0)) * sy
                readonly property bool dragging: drag.active
                property bool ready: false // the first layout — without the flight
                // the finger offset: while dragging — follows the cursor, released — smoothly to 0 (into its own or a new tile)
                property real dx: 0
                property real dy: 0

                x: hx + dx
                y: hy + dy
                width: Math.max(18, (o.size?.[0] ?? 400) * sx)
                height: Math.max(12, (o.size?.[1] ?? 300) * sy)
                z: dragging ? 10 : modelData.activated ? 2 : 1
                opacity: Math.max(0, Math.min(1, root.t * 2.2 - idx * 0.12))
                scale: dragging ? 1.06 : 1
                Behavior on x { enabled: win.ready && !win.dragging; NumberAnimation { duration: Theme.t * 1.4; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
                Behavior on y { enabled: win.ready && !win.dragging; NumberAnimation { duration: Theme.t * 1.4; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
                Behavior on dx { enabled: !win.dragging; NumberAnimation { duration: Theme.t * 1.4; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
                Behavior on dy { enabled: !win.dragging; NumberAnimation { duration: Theme.t * 1.4; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
                Behavior on width { enabled: win.ready; NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
                Behavior on height { enabled: win.ready; NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
                Behavior on scale { NumberAnimation { duration: 120 } }
                Component.onCompleted: Qt.callLater(() => ready = true)

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: Theme.s2
                    clip: true
                    // the window snapshot as is — you can see what's where; didn't work (no frame yet) — the app icon
                    ScreencopyView {
                        id: shot
                        anchors.fill: parent
                        captureSource: root.open ? win.modelData.wayland : null
                        live: root.open && !Theme.state.lite // Lite: one snapshot, not a live stream
                        constraintSize: Qt.size(win.width * 2, win.height * 2)
                    }
                    Image {
                        visible: !shot.hasContent
                        anchors.centerIn: parent
                        width: Math.min(32, parent.height * 0.6)
                        height: width
                        sourceSize: Qt.size(64, 64)
                        source: Quickshell.iconPath(win.o.class ?? "", true) || Quickshell.iconPath("application-x-executable", true)
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: "transparent"
                    border { width: win.modelData.activated || hov.hovered ? 2 : 1; color: win.modelData.activated || hov.hovered ? Theme.fg : Theme.s3 }
                }

                HoverHandler { id: hov; cursorShape: win.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor }
                DragHandler {
                    id: drag
                    target: null
                    onTranslationChanged: {
                        if (!active) return;
                        win.dx = translation.x;
                        win.dy = translation.y;
                        stage.drop = root.tileAt(win.x + win.width / 2, win.y + win.height / 2);
                    }
                    onActiveChanged: {
                        if (active) return;
                        const to = root.tileAt(win.x + win.width / 2, win.y + win.height / 2);
                        stage.drop = -1;
                        if (to >= 0 && to !== win.idx) root.moveTo(win.modelData, root.base + to + 1);
                        // back into its tile (or a new one, when the event arrives) — in flight
                        win.dx = 0;
                        win.dy = 0;
                    }
                }
                TapHandler {
                    onTapped: {
                        Hyprland.dispatch(`hl.dsp.focus({ window = "${root.addr(win.modelData)}" })`);
                        root.close();
                    }
                }
                TapHandler { acceptedButtons: Qt.MiddleButton; onTapped: Hyprland.dispatch(`hl.dsp.window.close({ window = "${root.addr(win.modelData)}" })`) }
            }
        }
    }

}
