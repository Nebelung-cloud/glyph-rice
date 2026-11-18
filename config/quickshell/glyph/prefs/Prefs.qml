import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs
import qs.components
import qs.services
import qs.settings
import "../bento.js" as Bento

// the glyph rice look: from System («customize the rice»; Super+I opens System). Not a form, but objects. On the left a column of Doto words, like in the power menu, — the selected one large, with a red
// dot. On the right the section, live: home — a 3 × 3 bento layout, deck — a screen with a panel at the edge, windows — a desktop with gaps,
// idle — a scale of minutes along which the screen dims. Numbers — rings of dots (drag around the circle, the wheel), toggles — pills
// where the white slides out. ↑↓ — sections, Tab — through the objects, ←→ — change, esc — close.
// Everything takes effect at once: Theme.state (glyph.json) and Rules.store (rules.json, shared with demonshot) + the right apply.
// Gaps/border/blur/shadows — via Theme.apply: Rules.windows() would give the windows demonshot's look
PanelWindow {
    id: root

    property int sel: 0
    signal wallRequested // wallpapers — their own screen (wall/Walls), shell.qml opens it
    readonly property var sections: ["HOME", "DECK", "BAR", "LOOK", "STYLE", "WINDOWS", "SHELL"]
    readonly property string moves: "shift ←→ move · ↵ swap · del drop · drag"
    readonly property var hints: ["shift + arrows move · ↵ swap · del drop · drag", moves, moves, "", "", "", ""]
    readonly property var r: Rules.store
    // the shown page (each is a Sheet); none while it loads
    readonly property Item page: [home, deck, bar, look, tint, win, shl][sel] ?? null

    // glyphs for the home widgets, deck sections and the bar tray
    readonly property var icons: ({
        weather: "\u{F0595}", calendar: "\u{F00ED}", cpu: "\u{F061A}", ram: "\u{F035B}", gpu: "\u{F08AE}", disk: "\u{F02CA}",
        battery: "\u{F0079}", buds: "\u{F02CB}", player: "\u{F040A}", system: "\u{F0128}", cat: "\u{F011B}", cava: "\u{F0EA2}", photo: "\u{F02E9}",
        clock: "\u{F0150}", perf: "\u{F04C5}", net: "\u{F05A9}", media: "\u{F075A}",
        layout: "\u{F030C}", wifi: "\u{F05A9}", bluetooth: "\u{F00AF}", sound: "\u{F057E}", notes: "\u{F009A}",
        mode: "\u{F04C5}", power: "\u{F0425}"
    })
    // round home widgets, the rest — a 40 square. ponytail: ram/gpu/disk/battery — a guess (rings); if Home decides otherwise — fix it
    readonly property var rounds: ["weather", "cpu", "ram", "gpu", "disk", "battery", "buds", "cava"]

    // ---- opening: its own animation (glyph layers have no_anim in hypr). The section is remembered between openings ----
    property bool shown: false
    // the window appears a moment before it moves: its first frame (creating the surface) is the slow one, so it lands
    // while nothing is moving yet
    property bool mapped: false
    Timer { running: root.visible && !root.mapped; interval: 20; onTriggered: root.mapped = true }
    Connections { target: root; function onVisibleChanged() { if (!root.visible) root.mapped = false; } }
    property real t: shown && mapped ? 1 : 0
    Behavior on t { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
    function open() {
        Hyprland.refreshToplevels(); // the minis place windows from hyprctl geometry
        shown = true;
        stage.forceActiveFocus();
    }
    function close() { shown = false; }
    Timer { id: reflow; interval: 400; onTriggered: Hyprland.refreshToplevels() } // windows make room for the moved bar, then re-read
    Connections { target: Theme.state; function onBarAtChanged() { reflow.restart(); } }
    // opened from System — esc goes back there instead of out to the desktop
    property bool fromSystem: false
    signal backRequested
    function leave() {
        close();
        if (fromSystem) backRequested();
        fromSystem = false;
    }
    function toggle() { shown ? close() : open(); }
    function go(i) {
        sel = (i + sections.length) % sections.length;
        stage.forceActiveFocus(); // focus in a hidden section would be lost
    }

    // ---- id lists in Theme.state: home widgets, deck sections, the bar tray. We edit a copy — JsonAdapter writes the file on assignment.
    // All return the new cursor ----
    function edit(key, f) {
        const a = Theme.state[key].slice();
        f(a);
        Theme.state[key] = a;
    }
    function move(key, i, to) {
        if (to < 0 || to >= Theme.state[key].length || to === i) return i;
        edit(key, a => a.splice(to, 0, a.splice(i, 1)[0]));
        return to;
    }
    function cut(key, i) {
        const n = Theme.state[key].length;
        if (i >= n) return i;
        edit(key, a => a.splice(i, 1));
        return Math.max(0, Math.min(i, n - 2));
    }
    // ↵ on the selected one: the next from all that isn't there yet. In an empty list — the first free one
    function cycle(key, i, all) {
        const a = Theme.state[key];
        if (all.every(k => a.includes(k))) return i;
        i = Math.min(i, a.length);
        let j = all.indexOf(a[i]);
        do j = (j + 1) % all.length; while (a.includes(all[j]));
        edit(key, b => b[i] = all[j]);
        return i;
    }
    // the tray: present — remove, absent — put it after the selected one
    function flip(key, w, cur) {
        const a = Theme.state[key], i = a.indexOf(w);
        if (i >= 0) {
            edit(key, b => b.splice(i, 1));
            return Math.max(0, Math.min(i < cur ? cur - 1 : cur, a.length - 2));
        }
        const at = Math.min(cur + 1, a.length);
        edit(key, b => b.splice(at, 0, w));
        return at;
    }
    // the list's keys in focus: ←→ select, shift ←→ reorder, ↵/space — change the kind, del — remove. -1 — not our key
    function nav(e, key, cur, all) {
        const n = Theme.state[key].length, d = e.key === Qt.Key_Left ? -1 : e.key === Qt.Key_Right ? 1 : 0;
        if (d && (e.modifiers & Qt.ShiftModifier)) return move(key, cur, cur + d);
        if (d) return n ? (cur + d + n) % n : 0;
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) return cycle(key, cur, all);
        if (e.key === Qt.Key_Delete || e.key === Qt.Key_Backspace) return cut(key, cur);
        return -1;
    }
    SystemClock { id: clock; enabled: root.visible; precision: SystemClock.Minutes }
    readonly property string hello: { const h = clock.date.getHours(); return h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"; }
    readonly property string who: (Theme.state.name || Quickshell.env("USER")).replace(/&/g, "&amp;").replace(/</g, "&lt;")

    // the current shell's name and tagline — from its rice.json (the same the Rice app draws)
    property var meta: ({})
    FileView { path: Quickshell.shellPath("rice.json"); onLoaded: try { root.meta = JSON.parse(text()); } catch (e) {} }
    // «switch shell» — only when there's something to choose from: other shells, folders with rice.json alongside (Demon's Shot…)
    property int shells: 1
    Process {
        running: root.visible
        command: [Quickshell.env("HOME") + "/.config/quickshell/rice/rice", "list"]
        stdout: StdioCollector { onStreamFinished: root.shells = text.trim().split("\n").length }
    }

    visible: t > 0 || shown
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "glyph-prefs"

    Rectangle {
        anchors.fill: parent
        color: Theme.bg // solid: bright bits of the windows behind showed through 5%
        opacity: root.t
        MouseArea { anchors.fill: parent; onClicked: stage.forceActiveFocus() } // outside — only drop focus; esc closes
    }

    Stage {
        id: stage
        opacity: root.t
        focus: true
        // the rail has the keys while the stage itself is focused; inside a page ↑↓ walk its rows and esc comes back here
        Keys.onPressed: e => {
            const up = e.key === Qt.Key_Up || e.key === Qt.Key_K, down = e.key === Qt.Key_Down || e.key === Qt.Key_J;
            if ((up || down) && root.page && !stage.activeFocus) {
                root.page.walk(stage.Window.activeFocusItem, down)?.forceActiveFocus();
            }
            else if (up) root.go(root.sel - 1);
            else if (down) root.go(root.sel + 1);
            else if ((e.key === Qt.Key_Right || e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && stage.activeFocus) stage.nextItemInFocusChain(true)?.forceActiveFocus();
            else if (e.key === Qt.Key_Escape && root.page?.editing && root.page.hot) root.page.hot.forceActiveFocus();
            else if (e.key === Qt.Key_Escape && root.page && !stage.activeFocus) stage.forceActiveFocus();
            else if (e.key === Qt.Key_Escape) root.leave();
            else return;
            e.accepted = true;
        }

        // sections. The dot: red — the rail has the keys, grey — inside a page, white — the name is being typed (the red is the caret)
        Rail {
            x: 72 - 30 * (1 - root.t)
            model: root.sections
            sel: root.sel
            dot: name.activeFocus ? Theme.fg : stage.activeFocus ? Theme.accent : Theme.mute
            onPicked: i => root.go(i)
        }

        Row {
            x: 72
            anchors { bottom: parent.bottom; bottomMargin: 70 }
            spacing: 34
            Lb { text: root.page?.editing ? "↑↓ part · ←→ pick" : root.page && !stage.activeFocus ? "↑↓ setting · ←→ change" : "↑↓ section · → enter" }
            Lb { visible: !!text && !!root.page?.editing; text: root.hints[root.sel] }
            Lb { text: root.page?.editing ? "esc rows" : root.page && !stage.activeFocus ? "esc sections" : root.fromSystem ? "esc back" : "esc close"; TapHandler { onTapped: root.leave() } }
        }

        // ---- HOME: rows for the layout and the widgets' own options. The layout's editor lives in the inspector: home at a 104/220
        // scale, the same kinds, order and layout. Click — select, another click or ↵ — the next kind, drag — take the place of the one
        // it's dropped on. What doesn't fit in 3 × 3 — faded, beside the grid; the tray under it adds and removes kinds ----
        Sheet {
            id: home
            on: root.sel === 0
            caption: "home"
            readonly property var cells: Bento.layout(Theme.state.widgets, Theme.state.widgetAt, Theme.kinds)
            readonly property var placed: cells.filter(c => c.fits)
            readonly property var off: cells.filter(c => !c.fits)
            readonly property int used: placed.reduce((a, c) => a + c.span, 0)
            // which cell each grid cell belongs to (an index into cells, -1 — empty)
            readonly property var occ: {
                const g = Array(9).fill(-1);
                cells.forEach((o, n) => { if (o.fits) for (let k = 0; k < o.span; k++) g[o.row * 3 + o.col + k] = n; });
                return g;
            }
            property int cur: 0 // the selected grid cell, 0–8; a widget is selected when it covers it
            readonly property var cur_: cells[occ[cur]] ?? null
            readonly property var all: Object.keys(Theme.kinds)

            // save the widgets and where they sit; everything placed is pinned, so later edits don't reflow it. `first` wins its cell
            function save(ids, at, first) {
                Theme.state.widgetAt = Bento.cellsOf(Bento.layout(ids, at, Theme.kinds, first));
                if (ids !== Theme.state.widgets) Theme.state.widgets = ids;
            }
            function moveTo(id, c) {
                const at = Bento.move(Theme.state.widgets, Theme.state.widgetAt, Theme.kinds, id, c);
                Theme.state.widgetAt = at;
                if (at[id] !== undefined) cur = at[id];
            }
            // put kind id into cell c (it flows elsewhere if it doesn't fit there)
            function add(id, c) {
                if (!id || Theme.state.widgets.includes(id)) return;
                save(Theme.state.widgets.concat([id]), Object.assign(Bento.cellsOf(cells), { [id]: c }), id);
                const at = Theme.state.widgetAt[id];
                if (at !== undefined) cur = at;
            }
            function drop(id) { save(Theme.state.widgets.filter(w => w !== id), Bento.cellsOf(cells)); }
            // ↵ or a second click: the next kind not on home yet, in the same cell
            function swapKind(o) {
                const a = Theme.state.widgets;
                if (all.every(k => a.includes(k))) return;
                let j = all.indexOf(o.id);
                do j = (j + 1) % all.length; while (a.includes(all[j]));
                const at = Bento.cellsOf(cells);
                if (at[o.id] !== undefined) at[all[j]] = at[o.id];
                delete at[o.id];
                save(a.map(w => w === o.id ? all[j] : w), at, all[j]);
            }
            function tap(i) {
                const o = cells.find(x => x.i === i);
                grid?.forceActiveFocus();
                if (!o?.fits) return;
                if (cur_?.id === o.id) swapKind(o);
                else cur = o.row * 3 + o.col;
            }
            function keys(e) {
                const l = e.key === Qt.Key_Left, r = e.key === Qt.Key_Right, u = e.key === Qt.Key_Up, d = e.key === Qt.Key_Down;
                const o = cur_, start = o ? o.row * 3 + o.col : cur;
                if ((e.modifiers & Qt.ShiftModifier) && (l || r || u || d)) {
                    // move the selected widget a cell or a row, never across a row's end
                    if (o && !(l && o.col === 0) && !(r && o.col + o.span >= 3) && !(u && o.row === 0) && !(d && o.row === 2))
                        moveTo(o.id, start + (l ? -1 : r ? 1 : u ? -3 : 3));
                }
                else if (r) cur = (o ? start + o.span : cur + 1) % 9;
                else if (l) {
                    const n = ((o ? start : cur) + 8) % 9, w = cells[occ[n]];
                    cur = w ? w.row * 3 + w.col : n;
                }
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) {
                    if (o) swapKind(o);
                    else add(all.find(k => !Theme.state.widgets.includes(k)), cur);
                }
                else if (o && (e.key === Qt.Key_Delete || e.key === Qt.Key_Backspace)) drop(o.id);
                else return;
                e.accepted = true;
            }
            property Item grid: null // the editor's grid, while the inspector shows it (Tile reaches it from outside that component)
            readonly property real cell: 104
            readonly property real gap: 12
            readonly property real u: cell + gap // one grid step

            // dropped with its center at grid point p: its left end goes to the nearest cell (outside the grid — nothing)
            function land(i, p) {
                const o = cells.find(x => x.i === i);
                if (!o || p.x < -u / 2 || p.y < -u / 2 || p.x > grid.width + u / 2 || p.y > grid.height + u / 2) return;
                const col = Math.round((p.x - (o.span * u - gap) / 2) / u), row = Math.round((p.y - cell / 2) / u);
                moveTo(o.id, Math.max(0, Math.min(2, row)) * 3 + Math.max(0, Math.min(2, col)));
            }

            Lb { topPadding: 8; bottomPadding: 4; text: "layout" }
            Opt {
                title: "Widgets"
                hint: "Which widgets sit on home, and where. → to edit it on the right."
                about: "Home is a 3 × 3 grid, and any widget can go in any cell. Drag a tile where you want it, or select it and use Shift with the arrows. Landing on another widget swaps the two. Pick an empty cell and press ↵, or click a circle in the tray, to add one there. Del removes it."
                value: `${home.used}/9`
                preview: Component {
                    Column {
                        spacing: 16
                        Row {
                            spacing: 30
                            Item {
                                id: g
                                width: 3 * home.u - home.gap
                                height: width
                                activeFocusOnTab: true
                                Component.onCompleted: home.grid = g
                                Component.onDestruction: if (home.grid === g) home.grid = null
                                Keys.onPressed: e => home.keys(e)
                                Repeater {
                                    model: 9
                                    Dots {
                                        required property int index
                                        x: index % 3 * home.u
                                        y: Math.floor(index / 3) * home.u
                                        scale: home.cell / 168 // Dots is drawn for a 168 cell
                                        transformOrigin: Item.TopLeft
                                        // an empty cell: a click selects it, ↵ then adds a widget there
                                        TapHandler {
                                            onTapped: {
                                                g.forceActiveFocus();
                                                if (home.occ[parent.index] < 0) home.cur = parent.index;
                                            }
                                        }
                                    }
                                }
                                // the cursor on an empty cell
                                Rectangle {
                                    visible: !home.cur_
                                    x: home.cur % 3 * home.u
                                    y: Math.floor(home.cur / 3) * home.u
                                    width: home.cell
                                    height: home.cell
                                    radius: Theme.corner(home.cell * 0.18)
                                    color: "transparent"
                                    border { width: g.activeFocus ? 2 : 1; color: g.activeFocus ? Theme.fg : Theme.mute }
                                }
                                Repeater {
                                    model: home.placed
                                    Tile {
                                        cell: home.cell
                                        gap: home.gap
                                        x: modelData.col * home.u
                                        y: modelData.row * home.u
                                    }
                                }
                            }
                            Column {
                                width: 300
                                spacing: 12
                                Lb {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: !home.cur_ ? "empty cell · ↵ adds one" : `${home.cur_.id} · ${home.cur_.span} cell${home.cur_.span > 1 ? "s" : ""}${home.cur_.fits ? "" : " · off grid"}`
                                    color: Theme.fg
                                }
                                Lb { topPadding: 16; text: home.off.length ? `off grid · ${home.off.length}` : "everything fits" }
                                Flow {
                                    width: parent.width
                                    spacing: 10
                                    Repeater {
                                        model: home.off
                                        Tile { cell: 84; gap: 8 }
                                    }
                                }
                            }
                        }
                        Tray {
                            room: 740
                            ids: Object.keys(Theme.kinds)
                            icons: root.icons
                            used: Theme.state.widgets
                            dim: home.off.map(c => c.id)
                            widths: Theme.kinds
                            onToggled: key => Theme.state.widgets.includes(key) ? home.drop(key) : home.add(key, home.cur)
                        }
                    }
                }
            }

            Lb {
                visible: Theme.state.widgets.includes("cat") || Theme.state.widgets.includes("photo")
                topPadding: 40
                bottomPadding: 4
                text: "widgets"
            }
            // the cat's gif (services/Gifs). ←→ step, a click picks
            Opt {
                visible: Theme.state.widgets.includes("cat")
                wide: true
                title: "Cat animation"
                hint: "What the cat widget plays."
                about: "Your own GIFs show up here too, drawn in dots like the cat. ←→ steps through them, a click picks one."
                value: Gifs.name(Gifs.cur)
                preview: Component {
                    Rectangle {
                        width: 260
                        height: 260
                        radius: Theme.corner(46)
                        color: Theme.s1
                        GifDots { anchors { fill: parent; margins: 24 } path: Gifs.cur; bg: parent.color; playing: home.on && root.visible }
                    }
                }
                ListView {
                    id: gifStrip
                    width: 404
                    height: 58
                    orientation: ListView.Horizontal
                    spacing: (width - 6 * 58) / 5 // exactly six in a row
                    clip: true
                    snapMode: ListView.SnapToItem
                    boundsBehavior: Flickable.StopAtBounds
                    keyNavigationEnabled: false
                    activeFocusOnTab: true
                    model: Gifs.list
                    currentIndex: Gifs.sel
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                    Keys.onPressed: e => {
                        if (e.key === Qt.Key_Left) Gifs.step(-1);
                        else if (e.key === Qt.Key_Right) Gifs.step(1);
                        else return;
                        e.accepted = true;
                    }
                    delegate: Rectangle {
                        id: th
                        required property string modelData
                        required property int index
                        readonly property bool on: index === Gifs.sel
                        width: 58
                        height: 58
                        radius: Theme.corner(width * 0.18)
                        color: Theme.s1
                        border { width: on ? 2 : gifStrip.activeFocus ? 1 : 1; color: on ? Theme.fg : Theme.s2 }
                        GifDots { anchors { fill: parent; margins: 6 } path: th.modelData; bg: th.color; playing: home.on && root.visible }
                        TapHandler {
                            onTapped: {
                                Gifs.pick(th.modelData);
                                gifStrip.forceActiveFocus();
                            }
                        }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                    }
                }
            }
            // the photo widget: the shots — the first five in the folder (services/Photos)
            Opt {
                visible: Theme.state.widgets.includes("photo")
                title: "Photo shape"
                hint: `Shows ${Photos.list.length} of ${Photos.most} pictures from ${Photos.dir.replace(Quickshell.env("HOME"), "~")}.`
                about: "The photo widget cycles through the first pictures in that folder. Square fills its tile, circle crops each picture round."
                value: Theme.state.photoRound ? "circle" : "square"
                Pick { opts: ["square", "circle"]; cur: Theme.state.photoRound ? 1 : 0; onPicked: i => Theme.state.photoRound = i === 1 }
            }
            Opt {
                visible: Theme.state.widgets.includes("photo")
                title: "Photo look"
                hint: "Dots, colored dots, or the plain picture."
                about: "Dots draws the picture in white dots like the rest of home. Color dots keeps its colors. Color shows the picture as it is."
                value: ["dots", "color dots", "color"][Math.max(0, [0, 3, 2].indexOf(Theme.state.photoLook))]
                Pick { opts: ["dots", "color dots", "color"]; cur: [0, 3, 2].indexOf(Theme.state.photoLook); onPicked: i => Theme.state.photoLook = [0, 3, 2][i] }
            }
        }

        // ---- DECK: the sections as a row whose editor lives in the inspector: a screen with the deck at the bottom center, its
        // sections in order like in the panel, the tray under it — which ones exist. Then the edges that open it and quick settings ----
        Sheet {
            id: deck
            on: root.sel === 1
            caption: "deck"
            property int cur: 0
            // dragging section from (-1 — none): dx — the cursor offset in layout px, at — where it is in the strip, to — where it'll land
            property int from: -1
            property real dx: 0
            readonly property real at: Math.max(10, Math.min(10 + (Theme.state.deck.length - 1) * 104, 10 + from * 104 + dx))
            readonly property int to: Math.round((at - 10) / 104)
            readonly property Component edges: Component { Edges {} }

            Lb { topPadding: 8; bottomPadding: 4; text: "sections" }
            Opt {
                title: "Sections"
                hint: "What the deck holds, and in what order. → to edit it on the right."
                about: "The deck is the panel at the bottom of the screen. Click a circle in the tray to add or remove a section. Drag along the deck, or Shift ←→, to reorder. ↵ swaps it for another, Del drops it."
                value: `${Theme.state.deck.length}/${Theme.decks.length}`
                preview: Component {
                    Column {
                        spacing: 30
                        Edges {
                            Rectangle {
                                id: strip
                                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 30 }
                                width: Math.max(1, Theme.state.deck.length) * 104 + 20
                                height: 116
                                radius: Theme.corner(40)
                                color: Theme.s1
                                border { width: 1; color: strip.activeFocus ? Theme.fg : Theme.s2 }
                                Behavior on width { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
                                activeFocusOnTab: true
                                Keys.onPressed: e => {
                                    const c = root.nav(e, "deck", deck.cur, Theme.decks);
                                    if (c < 0) return;
                                    deck.cur = c;
                                    e.accepted = true;
                                }

                                Lb { visible: !Theme.state.deck.length; anchors.centerIn: parent; text: "empty" }
                                Repeater {
                                    model: Theme.state.deck
                                    Item {
                                        id: ds
                                        required property string modelData
                                        required property int index
                                        readonly property bool on: deck.cur === index
                                        readonly property bool hot: on && strip.activeFocus
                                        // while dragging: this one follows the cursor, the ones between it and the drop spot — a step toward its place
                                        readonly property int slot: deck.from < 0 ? index
                                            : index > deck.from && index <= deck.to ? index - 1
                                            : index < deck.from && index >= deck.to ? index + 1 : index
                                        x: dd.active ? deck.at : 10 + slot * 104
                                        width: 104
                                        height: strip.height
                                        z: dd.active ? 1 : 0
                                        Behavior on x {
                                            enabled: !dd.active
                                            NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide }
                                        }

                                        Column {
                                            anchors.centerIn: parent
                                            spacing: 10
                                            Rectangle {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                width: 56
                                                height: 56
                                                radius: 28
                                                color: ds.hot ? Theme.fg : Theme.s2
                                                border { width: ds.on && !ds.hot ? 1 : 0; color: Theme.fg }
                                                Icon { anchors.centerIn: parent; text: root.icons[ds.modelData] ?? ""; font.pixelSize: 24; color: ds.hot ? Theme.ink : Theme.fg }
                                            }
                                            Lb { anchors.horizontalCenter: parent.horizontalCenter; text: ds.modelData; px: 10; color: ds.on ? Theme.fg : Theme.grey }
                                        }
                                        TapHandler {
                                            onTapped: {
                                                strip.forceActiveFocus();
                                                deck.cur = deck.cur === ds.index ? root.cycle("deck", ds.index, Theme.decks) : ds.index;
                                            }
                                        }
                                        DragHandler {
                                            id: dd
                                            target: null
                                            yAxis.enabled: false
                                            // without a target the offset is in scene px, and Stage is scaled
                                            onActiveTranslationChanged: deck.dx = activeTranslation.x / Theme.s
                                            onActiveChanged: {
                                                if (active) {
                                                    deck.cur = ds.index;
                                                    deck.from = ds.index;
                                                    return;
                                                }
                                                // the drop — after the signal: changing the list recreates the sections, this one included
                                                const from = deck.from, to = deck.to;
                                                Qt.callLater(() => {
                                                    deck.from = -1;
                                                    deck.cur = root.move("deck", from, to);
                                                });
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        Tray {
                            room: 740
                            ids: Theme.decks
                            icons: root.icons
                            used: Theme.state.deck
                            onToggled: key => deck.cur = root.flip("deck", key, deck.cur)
                        }
                    }
                }
            }

            Lb { topPadding: 40; bottomPadding: 4; text: "open by pointing" }
            Opt {
                title: "Deck on hover"
                hint: "Rest the pointer on the bottom edge to open the deck."
                about: "When on, pushing the pointer against the middle of the bottom edge slides the deck up. Off, that edge does nothing."
                value: Theme.state.deckHover ? "on" : "off"
                preview: deck.edges
                Switch { on: Theme.state.deckHover; onFlip: Theme.state.deckHover = !Theme.state.deckHover }
            }
            Opt {
                title: "Quick settings on hover"
                hint: "Rest the pointer on the side edge to open quick settings."
                about: "When on, pushing the pointer against the screen edge opens quick settings. With the bar on the right, this edge moves to the left."
                value: Theme.state.quickHover ? "on" : "off"
                preview: deck.edges
                Switch { on: Theme.state.quickHover; onFlip: Theme.state.quickHover = !Theme.state.quickHover }
            }
        }

        // ---- BAR: rows — where it sits, the window title, auto-hide per screen, the buttons. The buttons' editor lives in the inspector:
        // like in the bar, at the side a column (labels beside it), on top a row (labels under the icon); drag along it ----
        Sheet {
            id: bar
            on: root.sel === 2
            caption: "bar"
            readonly property bool onTop: Theme.state.barAt === "top"
            readonly property real step: onTop ? 104 : 68 // a slot along the bar
            property int cur: 0
            // dragging from (-1 — none): d — the cursor offset along the bar in layout px, at — where it is, to — where it'll land
            property int from: -1
            property real d: 0
            readonly property real at: Math.max(10, Math.min(10 + (Theme.state.bar.length - 1) * step, 10 + from * step + d))
            readonly property int to: Math.round((at - 10) / step)
            readonly property var edgeNames: ["left", "right", "top"]
            readonly property Component mini: Component { Mini { width: 640; apps: true } }

            Lb { topPadding: 8; bottomPadding: 4; text: "place" }
            Opt {
                title: "Edge"
                hint: "Which side of the screen the bar sits on."
                about: "Left and right give a slim column, top gives a row across the screen. Windows always make room for it."
                value: Theme.state.barAt
                preview: Component {
                    Row {
                        id: edges
                        spacing: 20
                        Repeater {
                            model: ["left", "right", "top"]
                            Column {
                                id: ed
                                required property string modelData
                                readonly property bool on: modelData === Theme.state.barAt
                                spacing: 10
                                Mini {
                                    width: 200
                                    at: ed.modelData
                                    apps: true
                                    border { width: ed.on ? 2 : 1; color: ed.on ? Theme.fg : Theme.s3 }
                                    TapHandler { onTapped: Theme.state.barAt = ed.modelData }
                                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                                }
                                Lb { anchors.horizontalCenter: parent.horizontalCenter; text: ed.modelData; px: 10; color: ed.on ? Theme.fg : Theme.grey }
                            }
                        }
                    }
                }
                Pick {
                    height: 44
                    opts: bar.edgeNames
                    cur: bar.edgeNames.indexOf(Theme.state.barAt)
                    onPicked: i => Theme.state.barAt = bar.edgeNames[i]
                }
            }
            Opt {
                title: "Window title"
                hint: `Names the app you are in, ${bar.onTop ? "left of" : "above"} the clock.`
                about: "The title of the focused window, written along the bar. Turn it off for a quieter bar."
                value: Theme.state.barTitle ? "on" : "off"
                preview: bar.mini
                Switch { on: Theme.state.barTitle; onFlip: Theme.state.barTitle = !Theme.state.barTitle }
            }

            Lb { topPadding: 40; bottomPadding: 4; text: "outline" }
            Opt {
                title: "Outline"
                hint: "A bright edge around the bar, like a focused window's."
                about: "Draws the bar's edge in the same white as the focused window's border. 0 keeps the faint grey hairline."
                value: `${bOut.v} px`
                preview: bar.mini
                Dial { id: bOut; size: 72; to: 6; n: 24; value: Theme.state.barBorder; onMoved: v => Theme.state.barBorder = v }
            }
            Opt {
                title: "Glow"
                hint: "A soft light around the bar."
                about: "The same soft white halo the windows get from their shadow, so the bar stands out over the wallpaper and windows."
                value: Theme.state.barGlow ? "on" : "off"
                preview: bar.mini
                Switch { on: Theme.state.barGlow; onFlip: Theme.state.barGlow = !Theme.state.barGlow }
            }

            Lb { topPadding: 40; bottomPadding: 4; text: "auto-hide · experimental" }
            Repeater {
                model: Quickshell.screens
                Opt {
                    id: hideRow
                    required property var modelData
                    readonly property bool hides: Theme.state.barHide.includes(modelData.name)
                    title: Quickshell.screens.length > 1 ? `Hide on ${modelData.name}` : "Hide the bar"
                    hint: "Slides away when not in use. Push the mouse to the edge to bring it back."
                    about: "The bar tucks out of sight so windows get the whole screen. Push the pointer against its edge, or open a panel from the bar, and it comes back. Still experimental."
                    value: hides ? "on" : "off"
                    preview: bar.mini
                    Switch {
                        on: hideRow.hides
                        onFlip: {
                            const n = hideRow.modelData.name, a = Theme.state.barHide.filter(x => x !== n);
                            if (!on) a.push(n);
                            Theme.state.barHide = a;
                        }
                    }
                }
            }
            Opt {
                visible: Theme.state.barHide.length > 0
                title: "Only over windows"
                hint: "Keeps the bar on an empty desktop."
                about: "Hiding only starts once the workspace has a window on it. With nothing open, the bar stays where it is."
                value: Theme.state.barHideBusy ? "on" : "off"
                preview: bar.mini
                Switch { on: Theme.state.barHideBusy; onFlip: Theme.state.barHideBusy = !Theme.state.barHideBusy }
            }

            Lb { topPadding: 40; bottomPadding: 4; text: "buttons" }
            Opt {
                title: "Buttons in the bar"
                hint: "What sits in the bar, and in what order. → to edit it on the right."
                about: "Click a circle to add or remove it. Drag along the bar, or Shift ←→, to reorder. ↵ swaps the selected one for another, Del drops it."
                value: `${Theme.state.bar.length}/${Theme.bars.length}`
                preview: Component {
                    Grid {
                        columns: bar.onTop ? 1 : 2
                        columnSpacing: 120
                        rowSpacing: 40
                Rectangle {
                    id: col
                    readonly property int n: Math.max(1, Theme.state.bar.length)
                    width: bar.onTop ? n * 104 + 20 : 88
                    height: bar.onTop ? 116 : n * 68 + 20
                    radius: Theme.corner(bar.onTop ? 40 : 44)
                    color: Theme.s1
                    border { width: 1; color: col.activeFocus ? Theme.fg : Theme.s2 }
                    Behavior on width { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
                    Behavior on height { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
                    activeFocusOnTab: true
                    Keys.onPressed: e => {
                        const c = root.nav(e, "bar", bar.cur, Theme.bars);
                        if (c < 0) return;
                        bar.cur = c;
                        e.accepted = true;
                    }

                    Lb { visible: !Theme.state.bar.length; anchors.centerIn: parent; text: "empty"; px: 10 }
                    Repeater {
                        model: Theme.state.bar
                        Item {
                            id: bs
                            required property string modelData
                            required property int index
                            readonly property bool on: bar.cur === index
                            readonly property bool hot: on && col.activeFocus
                            readonly property int slot: bar.from < 0 ? index
                                : index > bar.from && index <= bar.to ? index - 1
                                : index < bar.from && index >= bar.to ? index + 1 : index
                            // its place along the bar: follows the cursor while dragged
                            property real pos: bd.active ? bar.at : 10 + slot * bar.step
                            Behavior on pos {
                                enabled: !bd.active
                                NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide }
                            }
                            x: bar.onTop ? pos : 0
                            y: bar.onTop ? 0 : pos
                            width: bar.onTop ? 104 : col.width
                            height: bar.onTop ? col.height : 68
                            z: bd.active ? 1 : 0

                            Rectangle {
                                id: bdot
                                x: (parent.width - width) / 2
                                y: bar.onTop ? 18 : (parent.height - height) / 2
                                width: 52
                                height: 52
                                radius: 26
                                color: bs.hot ? Theme.fg : Theme.s2
                                border { width: bs.on && !bs.hot ? 1 : 0; color: Theme.fg }
                                Icon { anchors.centerIn: parent; text: root.icons[bs.modelData] ?? ""; font.pixelSize: 22; color: bs.hot ? Theme.ink : Theme.fg }
                            }
                            Lb {
                                x: bar.onTop ? (parent.width - width) / 2 : parent.width + 24
                                y: bar.onTop ? bdot.y + bdot.height + 10 : (parent.height - height) / 2
                                text: bs.modelData
                                px: 10
                                color: bs.on ? Theme.fg : Theme.grey
                            }
                            TapHandler {
                                onTapped: {
                                    col.forceActiveFocus();
                                    bar.cur = bar.cur === bs.index ? root.cycle("bar", bs.index, Theme.bars) : bs.index;
                                }
                            }
                            DragHandler {
                                id: bd
                                target: null
                                xAxis.enabled: bar.onTop
                                yAxis.enabled: !bar.onTop
                                onActiveTranslationChanged: bar.d = (bar.onTop ? activeTranslation.x : activeTranslation.y) / Theme.s
                                onActiveChanged: {
                                    if (active) {
                                        bar.cur = bs.index;
                                        bar.from = bs.index;
                                        return;
                                    }
                                    const from = bar.from, to = bar.to;
                                    Qt.callLater(() => {
                                        bar.from = -1;
                                        bar.cur = root.move("bar", from, to);
                                    });
                                }
                            }
                        }
                    }
                }
                        Tray {
                            room: bar.onTop ? 740 : 500
                            ids: Theme.bars
                            icons: root.icons
                            used: Theme.state.bar
                            onToggled: key => bar.cur = root.flip("bar", key, bar.cur)
                        }
                    }
                }
            }
        }

        // ---- LOOK: the home screen and the lock. The inspector shows a miniature home that follows every switch ----
        Sheet {
            id: look
            on: root.sel === 3
            caption: "look"
            property bool dim: false // the colon went dark
            Timer { running: look.on && root.visible && Theme.state.blink; interval: 500; repeat: true; onTriggered: look.dim = !look.dim }
            // drawn at 760 wide, the size the positions were laid out for, then scaled into the inspector
            readonly property Component home: Component {
                Mini {
                    id: hm
                    width: 640
                    Item {
                        width: 760
                        height: 760 * hm.height / hm.width
                        scale: hm.width / 760
                        transformOrigin: Item.TopLeft
                        Orb { visible: Theme.state.orb; x: 400; y: 110; scale: 330 / 1100; transformOrigin: Item.TopLeft }
                        Row {
                            x: 60
                            y: 52
                            visible: Theme.state.homeClock
                            Num { id: hrs; text: Theme.hh(clock.date); font.pixelSize: 120 }
                            Num { text: ":"; font.pixelSize: 120; opacity: Theme.state.blink && look.dim ? 0.2 : 1 }
                            Num { text: Qt.formatTime(clock.date, "mm"); font.pixelSize: 120 }
                            Lb { visible: !Theme.state.clock24; anchors.baseline: hrs.baseline; leftPadding: 12; text: clock.date.getHours() < 12 ? "am" : "pm" }
                        }
                        Lb { x: 64; y: 172; visible: Theme.state.homeClock; text: Qt.locale("en_US").toString(clock.date, "dddd · d MMMM"); px: 11 }
                        Text {
                            x: 62
                            y: 232
                            visible: Theme.state.homeHello
                            textFormat: Text.StyledText
                            text: `${root.hello},<br><font color="${Theme.grey}">${root.who}.</font>`
                            font { family: Theme.ui; pixelSize: 30; weight: Font.Light }
                            lineHeight: 1.1
                            color: Theme.fg
                        }
                        // Glyph strips: volume on the right, progress at the bottom — or both in the island at the top
                        Seg { visible: Theme.state.edges && Theme.state.glyphLights !== 1; x: parent.width - 12; y: 140; width: 4; height: 200; n: 12; f: 0.6; vertical: true }
                        Seg { visible: Theme.state.edges && Theme.state.glyphLights !== 1; x: 230; y: parent.height - 10; width: 300; height: 4; n: 24; f: 0.4 }
                        Rectangle {
                            visible: Theme.state.edges && Theme.state.glyphLights === 1
                            x: 300; y: 10; width: 160; height: 26; radius: 13
                            color: "black"
                            border { width: 1; color: Theme.s3 }
                            Seg { anchors.centerIn: parent; width: 120; height: 4; n: 16; f: 0.5 }
                        }
                    }
                }
            }
            function flip(k) { Theme.state[k] = !Theme.state[k]; }

            Lb { topPadding: 8; bottomPadding: 4; text: "home screen" }
            Opt {
                title: "Clock"
                hint: "The big time and today's date on the desktop."
                about: "The large dotted clock with the date under it. Turn it off for a bare desktop."
                value: Theme.state.homeClock ? "on" : "off"
                preview: look.home
                Switch { on: Theme.state.homeClock; onFlip: look.flip("homeClock") }
            }
            Opt {
                title: "24-hour time"
                hint: "Shows 14:05 instead of 2:05 pm."
                about: "Changes the home and lock clocks. Off adds am or pm next to the time."
                value: Theme.state.clock24 ? "24h" : "12h"
                preview: look.home
                Switch { on: Theme.state.clock24; onFlip: look.flip("clock24") }
            }
            Opt {
                title: "Blinking colon"
                hint: "The colon in the clock pulses every second."
                about: "A slow heartbeat on the home and lock clocks. Off keeps the clock still."
                value: Theme.state.blink ? "on" : "off"
                preview: look.home
                Switch { on: Theme.state.blink; onFlip: look.flip("blink") }
            }
            Opt {
                title: "Greeting"
                hint: "Says hello to you by name, under the clock."
                about: "A line that changes with the time of day, followed by your name."
                value: Theme.state.homeHello ? "on" : "off"
                preview: look.home
                Switch { on: Theme.state.homeHello; onFlip: look.flip("homeHello") }
            }
            Opt {
                title: "Your name"
                hint: "What the greeting calls you. Empty uses your login name."
                about: "Type a name, up to 24 letters. Leave it empty and the greeting uses your login name."
                value: Theme.state.name || Quickshell.env("USER")
                preview: look.home
                Rectangle {
                    width: 240
                    height: 52
                    radius: Theme.corner(26)
                    color: Theme.s2
                    border { width: name.activeFocus ? 1 : 0; color: Theme.fg }
                    TextInput {
                        id: name
                        anchors { left: parent.left; leftMargin: 22; right: parent.right; rightMargin: 22; verticalCenter: parent.verticalCenter }
                        text: Theme.state.name
                        maximumLength: 24
                        activeFocusOnTab: true
                        font { family: Theme.ui; pixelSize: 19 }
                        color: Theme.fg
                        selectionColor: Theme.s3
                        clip: true
                        onTextEdited: Theme.state.name = text
                        cursorDelegate: Rectangle {
                            width: 2
                            color: name.activeFocus ? Theme.accent : "transparent"
                            Timer { running: name.activeFocus; interval: 500; repeat: true; onTriggered: parent.opacity = 1 - parent.opacity }
                        }
                        Text { visible: !name.text; text: Quickshell.env("USER"); font: name.font; color: Theme.mute }
                    }
                }
            }
            Opt {
                title: "Widgets"
                hint: "The tiles on the desktop. Choose which ones in HOME."
                about: "Shows the widget tiles you picked in the HOME section. Off hides them all without losing your choice."
                value: Theme.state.homeBento ? "on" : "off"
                preview: look.home
                Switch { on: Theme.state.homeBento; onFlip: look.flip("homeBento") }
            }
            Opt {
                title: "Dot grid"
                hint: "A faint grid of dots behind everything."
                about: "Shows only where the wallpaper leaves the background bare."
                value: Theme.state.grid ? "on" : "off"
                preview: look.home
                Switch { on: Theme.state.grid; onFlip: look.flip("grid") }
            }
            Opt {
                title: "Orb"
                hint: "A glowing orb at the lower right of the desktop and lock."
                about: "A decoration only. Like the dot grid, it hides behind a wallpaper that fills the screen."
                value: Theme.state.orb ? "on" : "off"
                preview: look.home
                Switch { on: Theme.state.orb; onFlip: look.flip("orb") }
            }
            Opt {
                title: "Wallpaper"
                hint: "Pick the picture behind everything."
                about: "Opens the wallpaper picker. This panel closes while you choose."
                preview: Component { Mini { width: 640 } }
                Act {
                    icon: "\u{F02E9}"
                    text: "choose"
                    onHit: {
                        root.close();
                        root.wallRequested();
                    }
                }
            }

            Lb { topPadding: 40; bottomPadding: 4; text: "lights" }
            Opt {
                title: "Edge lights"
                hint: "Thin strips of light show volume and music progress."
                about: "Like the lights on the back of a Nothing phone: they glow at the screen edges while something changes, then fade."
                value: Theme.state.edges ? "on" : "off"
                preview: look.home
                Switch { on: Theme.state.edges; onFlip: look.flip("edges") }
            }
            Opt {
                visible: Theme.state.edges
                title: "Lights in the island"
                hint: "Moves those lights into a pill at the top of the screen."
                about: "Volume and progress glow in the island at the top instead of along the edges. With the bar on the right, volume is always up there."
                value: Theme.state.glyphLights === 1 ? "island" : "edges"
                preview: look.home
                Switch { on: Theme.state.glyphLights === 1; onFlip: Theme.state.glyphLights = Theme.state.glyphLights === 1 ? 0 : 1 }
            }

            Lb { topPadding: 40; bottomPadding: 4; text: "lock screen" }
            Opt {
                title: "Atmosphere"
                hint: "The wallpaper softens and slowly breathes while locked."
                about: "While locked, the wallpaper sits in a haze, a little closer. It sharpens again as you unlock. Off in lite mode."
                value: Theme.state.atmosphere ? "on" : "off"
                Switch { on: Theme.state.atmosphere; onFlip: look.flip("atmosphere") }
            }
            Opt {
                title: "Hide password length"
                hint: "Three pulsing dots while you type, not one per letter."
                about: "Someone looking over your shoulder can't count the letters of your password."
                value: Theme.state.lockHideLen ? "on" : "off"
                Switch { on: Theme.state.lockHideLen; onFlip: look.flip("lockHideLen") }
            }
            Opt {
                title: "Lock on one screen"
                hint: "Other screens go dark; the clock and password stay on one."
                about: "With more than one screen, only the one you were using shows the lock. The rest stay blank."
                value: Theme.state.lockOneScreen ? "on" : "off"
                Switch { on: Theme.state.lockOneScreen; onFlip: look.flip("lockOneScreen") }
            }
        }

        // ---- STYLE: where color comes from and the theme as rows; what the source has (tones, variants, palettes) as rows of swatches
        // under their title. The inspector shows a desktop in the palette of the focused or hovered swatch (none — the current one): bar,
        // quick settings, kitty, player, the Glyph bar, with the roles as callouts. The same choice as style in the launcher (Theme.styles).
        // Swatches by index: a new Theme.styles on every pick doesn't recreate the circles, and focus stays where it was ----
        Sheet {
            id: tint
            on: root.sel === 4
            property Item sw: null // the swatch under the cursor or focused
            readonly property var p: sw?.item.pal ?? Theme.pal
            readonly property string src: Theme.state.paint === "scheme" ? (Theme.pal.group === "more" ? "" : Theme.pal.group + " ") + Theme.pal.name
                : Theme.state.paint === "wall" && Theme.tones.length ? `wallpaper · ${Theme.pal.name}` : "nothing"
            caption: `style · ${src} · ${Theme.light ? "light" : "dark"}` + (sw && !sw.item.now ? `   →   ${sw.item.name} · ↵ sets it` : "")
            function block(h) { return Theme.styles.find(b => b.head === h)?.items ?? []; }
            function peek(s) {
                if (s.peek) sw = s;
                else if (sw === s) sw = null;
            }
            // the mock is laid out 1040 wide (desk + callouts); scaled into the inspector
            readonly property Component desk: Component {
                Item {
                    width: 740
                    height: 388 * 740 / 1040
                    Desk { p: tint.p; scale: 740 / 1040; transformOrigin: Item.TopLeft }
                }
            }

            Lb { topPadding: 8; bottomPadding: 4; text: "color" }
            Opt {
                title: "Colors from"
                hint: "Where the shell gets its colors."
                about: "Nothing keeps the plain look: black, white dots and one red. Wallpaper takes the colors from your picture. Palette lets you pick a ready-made color scheme."
                value: ["nothing", "wallpaper", "palette"][Math.max(0, ["", "wall", "scheme"].indexOf(Theme.state.paint))]
                preview: tint.desk
                Pick {
                    opts: ["nothing", "wall", "palette"]
                    cur: ["", "wall", "scheme"].indexOf(Theme.state.paint)
                    onPicked: i => Theme.state.paint = ["", "wall", "scheme"][i]
                }
            }
            Opt {
                title: "Theme"
                hint: "Dark or light background."
                about: "Light swaps black for white across the shell, the terminal and apps that follow it."
                value: Theme.light ? "light" : "dark"
                preview: tint.desk
                Pick { opts: ["dark", "light"]; cur: Theme.light ? 1 : 0; onPicked: i => Theme.setLight(i === 1) }
            }
            Opt {
                visible: !Theme.light
                title: "Extra dark"
                hint: "Pure black instead of dark grey."
                about: "Panels and the background go fully black. Looks best on OLED screens, where black pixels are switched off."
                value: Theme.state.extraDark ? "on" : "off"
                preview: tint.desk
                Switch { on: Theme.state.extraDark; onFlip: Theme.state.extraDark = !Theme.state.extraDark }
            }

            Lb { visible: Theme.state.paint === "wall"; topPadding: 40; bottomPadding: 4; text: "from the wallpaper" }
            Opt {
                visible: Theme.state.paint === "wall"
                title: "Wallpaper"
                hint: "The picture the colors come from."
                about: "Opens the wallpaper picker. This panel closes while you choose."
                preview: Component { Mini { width: 640 } }
                Act {
                    icon: "\u{F02E9}"
                    text: "choose"
                    onHit: {
                        root.close();
                        root.wallRequested();
                    }
                }
            }
            Opt {
                visible: Theme.state.paint === "wall"
                wide: Theme.tones.length > 0
                activeFocusOnTab: !Theme.tones.length
                title: "Tone"
                hint: Theme.tones.length ? "The main colors found in your wallpaper. Pick one." : "This wallpaper has no strong color. Choose another one above."
                about: "Each circle is a color taken from the picture. The one you pick becomes the accent, and the greys lean towards it."
                value: tint.block("tones").find(t => t.now)?.name ?? "none" // pal.name is the variant's
                preview: tint.desk
                Flow {
                    width: 620
                    Repeater {
                        model: tint.block("tones").length
                        Swatch { id: tw; item: tint.block("tones")[index] ?? ({ name: "" }); onPeekChanged: tint.peek(tw) }
                    }
                }
            }
            Opt {
                visible: Theme.state.paint === "wall" && Theme.tones.length > 0
                title: "Saturation"
                hint: "How strong the wallpaper's colors come out."
                about: "100 % uses the colors as found. Lower is calmer and greyer, higher is more vivid."
                value: `${sat.v} %`
                preview: tint.desk
                Dial { id: sat; size: 72; from: 50; to: 200; step: 25; n: 24; value: Theme.state.paintSat; onMoved: v => Theme.state.paintSat = v }
            }
            Opt {
                visible: Theme.state.paint === "wall" && Theme.tones.length > 0
                wide: true
                title: "Variant"
                hint: "How much color spreads beyond the accent."
                about: "Like Material You: the ring around each circle shows how much color it uses. The first ones stay nearly grey, the last ones tint everything."
                value: tint.block("variant").find(v => v.now)?.name ?? ""
                preview: tint.desk
                Flow {
                    width: 620
                    Repeater {
                        model: tint.block("variant").length
                        Swatch { id: vw; item: tint.block("variant")[index] ?? ({ name: "" }); onPeekChanged: tint.peek(vw) }
                    }
                }
            }

            // palettes by group: the blocks between source and theme
            Lb { visible: Theme.state.paint === "scheme"; topPadding: 40; bottomPadding: 4; text: "palettes" }
            Repeater {
                model: Theme.state.paint === "scheme" ? Theme.styles.length - 2 : 0
                Opt {
                    id: sb
                    required property int index
                    readonly property var block: Theme.styles[index + 1] ?? ({ head: "", items: [] })
                    wide: true
                    title: sb.block.head === "more" ? "More" : sb.block.head.charAt(0).toUpperCase() + sb.block.head.slice(1)
                    hint: sb.block.head === "more" ? "Other well-known color schemes." : `The ${sb.block.head} family of color schemes.`
                    about: "Hover or focus a circle to see it on the desktop. Click or ↵ sets it. Some palettes are light and switch the theme with them."
                    value: sb.block.items.find(v => v.now)?.name ?? ""
                    preview: tint.desk
                    Flow {
                        width: 620
                        Repeater {
                            model: sb.block.items.length
                            Swatch { id: pw; item: sb.block.items[index] ?? ({ name: "" }); onPeekChanged: tint.peek(pw) }
                        }
                    }
                }
            }
        }

        // ---- WINDOWS: Hyprland's spacing and shape as dials in the rows; the inspector shows a desktop with two windows that follows them live
        Sheet {
            id: win
            on: root.sel === 5
            caption: "windows"
            function set(k, v, motion) { root.r[k] = v; if (motion) Rules.motion(); else Theme.apply(); }
            function flip(k, motion) { win.set(k, !root.r[k], motion); }
            readonly property Component desk: Component {
                Mini {
                    id: desk
                    width: 640
                    Repeater {
                        model: 2
                        Rectangle {
                            id: wnd
                            required property int index
                            readonly property real o: gOut.v * desk.k
                            readonly property real l: 78 * Theme.s * desk.k + o // bar 64 + a 14 gap, in logical px
                            readonly property string at: Theme.state.barAt
                            readonly property real w: (desk.width - (at === "top" ? o : l) - o - 2 * gIn.v * desk.k) / 2
                            x: (at === "top" || at === "right" ? o : l) + (index ? w + 2 * gIn.v * desk.k : 0)
                            y: at === "top" ? l : o
                            width: w
                            height: desk.height - (at === "top" ? l : o) - o
                            radius: rnd.v * desk.k
                            color: Theme.s1
                            border { width: bord.v ? Math.max(1, bord.v * desk.k) : 0; color: index ? Theme.s3 : Theme.fg }
                            Behavior on x { enabled: root.r.motion; NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
                            Behavior on y { enabled: root.r.motion; NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
                            Behavior on width { enabled: root.r.motion; NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
                            Behavior on height { enabled: root.r.motion; NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
                            Column {
                                x: 16
                                y: 16
                                spacing: 8
                                Lb { text: wnd.index ? "zen" : "kitty"; px: 10; color: wnd.index ? Theme.mute : Theme.grey }
                                Repeater {
                                    model: [0.7, 0.45, 0.85, 0.3, 0.6, 0.5]
                                    Rectangle {
                                        required property real modelData
                                        width: (wnd.width - 32) * modelData
                                        height: 4
                                        radius: 2
                                        color: Theme.s3
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Lb { topPadding: 8; bottomPadding: 4; text: "spacing and shape" }
            Opt {
                title: "Gap between windows"
                hint: "Space between windows that sit side by side."
                about: "Half of it goes on each side, so two windows end up this far apart twice over. 0 lets them touch."
                value: `${gIn.v} px`
                preview: win.desk
                Dial { id: gIn; size: 72; to: 30; value: root.r.gapsIn; onMoved: v => win.set("gapsIn", v) }
            }
            Opt {
                title: "Gap at the screen edge"
                hint: "Space between the windows and the edges of the screen."
                about: "The margin around the whole group of windows. The bar keeps its own room on top of this."
                value: `${gOut.v} px`
                preview: win.desk
                Dial { id: gOut; size: 72; to: 60; value: root.r.gapsOut; onMoved: v => win.set("gapsOut", v) }
            }
            Opt {
                title: "Border"
                hint: "An outline around each window. The focused one is brighter."
                about: "Helps you see which window has the keyboard. 0 removes the outline."
                value: `${bord.v} px`
                preview: win.desk
                Dial { id: bord; size: 72; to: 6; n: 24; value: root.r.border; onMoved: v => win.set("border", v) }
            }
            Opt {
                title: "Window corners"
                hint: "How round the corners of windows are."
                about: "0 gives sharp square corners. Higher numbers round them more."
                value: `${rnd.v} px`
                preview: win.desk
                Dial { id: rnd; size: 72; to: 40; value: Theme.state.rounding; onMoved: v => Theme.state.rounding = v } // shell.qml calls Theme.apply itself
            }
            Opt {
                title: "Panel corners"
                hint: "How round the shell's own panels and buttons are."
                about: "Applies to the bar, this panel and the rest of the shell, not to app windows. 100 % is fully round."
                value: `${pan.v} %`
                Dial { id: pan; size: 72; to: 100; step: 5; value: Theme.state.corners; onMoved: v => Theme.state.corners = v } // the shell's corners, %
            }

            Lb { topPadding: 40; bottomPadding: 4; text: "effects" }
            Opt {
                title: "Blur"
                hint: "Frosted glass behind see-through windows."
                about: "What sits behind a see-through window is blurred so its text stays readable. Uses a little more graphics power."
                value: root.r.blur ? "on" : "off"
                Switch { on: root.r.blur; onFlip: win.flip("blur") }
            }
            Opt {
                title: "Shadow"
                hint: "A soft shadow under each window."
                about: "Lifts windows off the wallpaper so their edges are easier to see."
                value: root.r.shadow ? "on" : "off"
                Switch { on: root.r.shadow; onFlip: win.flip("shadow") }
            }
            Opt {
                title: "Animations"
                hint: "Windows glide when they open, close or move."
                about: "Off makes every change instant. The preview here follows it too."
                value: root.r.motion ? "on" : "off"
                preview: win.desk
                Switch { on: root.r.motion; onFlip: win.flip("motion", true) }
            }

            Lb { topPadding: 40; bottomPadding: 4; text: "game mode" }
            Opt {
                title: "Start by itself"
                hint: "Turns game mode on when a game goes fullscreen."
                about: "Game mode trims the effects below to give the game more power, and puts everything back when the game closes."
                value: Theme.state.autoGame ? "on" : "off"
                Switch { on: Theme.state.autoGame; onFlip: Theme.state.autoGame = !Theme.state.autoGame }
            }
            Opt {
                title: "Keep gaps in games"
                hint: "Keeps gaps, border and corners while a game runs."
                about: "Off makes windows flat and edge to edge during game mode."
                value: root.r.gameGaps ? "kept" : "dropped"
                Switch { on: root.r.gameGaps; onFlip: win.flip("gameGaps") }
            }
            Opt {
                title: "Keep animations in games"
                hint: "Windows still glide during game mode."
                about: "Off makes window changes instant while a game runs."
                value: root.r.gameMotion ? "kept" : "dropped"
                Switch { on: root.r.gameMotion; onFlip: win.flip("gameMotion", true) }
            }
            Opt {
                title: "Keep blur in games"
                hint: "Frosted glass stays on during game mode."
                about: "Off saves graphics power for the game."
                value: root.r.gameBlur ? "kept" : "dropped"
                Switch { on: root.r.gameBlur; onFlip: win.flip("gameBlur") }
            }
            Opt {
                title: "Keep shadows in games"
                hint: "Window shadows stay on during game mode."
                about: "Off saves a little graphics power for the game."
                value: root.r.gameShadow ? "kept" : "dropped"
                Switch { on: root.r.gameShadow; onFlip: win.flip("gameShadow") }
            }
            Opt {
                title: "Quiet while gaming"
                hint: "Do not disturb turns on when a game starts by itself."
                about: "Notifications wait until you finish. Only applies when game mode starts by itself."
                value: root.r.gameDnd ? "on" : "off"
                Switch { on: root.r.gameDnd; onFlip: root.r.gameDnd = !root.r.gameDnd }
            }
        }

        // ---- SHELL: the live shell's name and mark, reload, switch (the Rice app), do not disturb ----
        Sheet {
            id: shl
            on: root.sel === 6
            caption: "shell · quickshell"
            readonly property Component mark: Component {
                Item {
                    width: 260
                    height: 260
                    Ring { anchors.fill: parent; n: 16; dot: 14; f: 1 }
                    Rectangle { anchors.centerIn: parent; width: 52; height: 52; radius: 26; color: Theme.fg }
                }
            }

            Opt {
                title: "Running now"
                hint: root.meta.tagline ?? "The desktop shell drawing the bar, panels and this screen."
                about: "The shell is the program that draws the bar, the panels and this settings screen. Your apps run on their own and don't depend on it."
                value: root.meta.name ?? "GLYPH"
                preview: shl.mark
            }
            Opt {
                title: "Reload"
                hint: "Restart the shell to pick up changes."
                about: "Reloads the bar and panels from their files. Open windows stay as they are. Handy after editing the shell by hand."
                preview: shl.mark
                Act { icon: "\u{F0450}"; text: "reload"; onHit: Quickshell.reload(false) }
            }
            Opt {
                visible: root.shells > 1
                title: "Switch shell"
                hint: "Pick another installed shell."
                about: "Opens the Rice app, where you choose which shell to run. This panel closes first."
                preview: shl.mark
                Act {
                    icon: "\u{F04E1}"
                    text: "switch"
                    onHit: {
                        root.close();
                        Quickshell.execDetached(["qs", "-c", "rice"]);
                    }
                }
            }
            Opt {
                title: "Do not disturb"
                hint: "Hold notifications instead of showing them."
                about: "New notifications don't pop up while this is on. They still collect, so you can read them later. Urgent ones, like a low battery, still show."
                value: Theme.state.dnd ? "on" : "off"
                Switch { on: Theme.state.dnd; onFlip: Theme.state.dnd = !Theme.state.dnd }
            }
        }
    }

    // DECK: a screen with the edges that catch the pointer lit when they're on: bottom — the deck, right — quick settings
    component Edges: Mini {
        width: 700
        Seg {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 8 }
            width: 320
            height: 4
            n: 24
            f: Theme.state.deckHover ? 1 : 0
        }
        Seg {
            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
            width: 4
            height: 240
            n: 16
            vertical: true
            f: Theme.state.quickHover ? 1 : 0
        }
    }

    // a miniature of this screen in its real shape: the wallpaper as set, (apps) snapshots of the open windows where they sit, and the
    // bar drawn at `at`, so it follows the setting live. Windows are captured one by one, not the whole screen: that would catch this
    // panel. k — the screen's logical px in layout px
    component Mini: Rectangle {
        id: mini
        property string at: Theme.state.barAt
        property bool apps: false
        readonly property real k: width / ((Rules.mon.w || 2880) / Rules.scale)
        width: 760
        height: width * (Rules.mon.h || 1080) / (Rules.mon.w || 1920)
        radius: 6
        color: Theme.bg
        border { width: 1; color: Theme.s3 }
        Image {
            visible: Theme.state.grid
            anchors { fill: parent; margins: 12 }
            fillMode: Image.Tile
            source: "data:image/svg+xml," + encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16"><circle cx="8" cy="8" r="1" fill="#${Theme.hex(Theme.s2)}"/></svg>`)
        }
        Wall { anchors { fill: parent; margins: 1 } path: Theme.wallSrc(Theme.state.wall); animate: false }
        Repeater {
            model: mini.apps && root.shown ? Hyprland.focusedMonitor?.activeWorkspace?.toplevels.values ?? [] : []
            Rectangle {
                required property var modelData
                readonly property var o: modelData.lastIpcObject ?? {}
                readonly property var m: Hyprland.focusedMonitor?.lastIpcObject ?? {}
                x: ((o.at?.[0] ?? 0) - (m.x ?? 0)) * mini.k
                y: ((o.at?.[1] ?? 0) - (m.y ?? 0)) * mini.k
                width: (o.size?.[0] ?? 0) * mini.k
                height: (o.size?.[1] ?? 0) * mini.k
                radius: Theme.state.rounding * mini.k
                color: Theme.s2
                clip: true
                ScreencopyView {
                    anchors.fill: parent
                    captureSource: parent.modelData.wayland
                    live: false // one snapshot per opening: four minis streaming every window is a lot of copying for a preview
                    constraintSize: Qt.size(parent.width * 2, parent.height * 2)
                }
            }
        }
        // the bar at its edge: the 14 gap and 64 thickness are layout px, on screen they're Theme.s logical
        Rectangle {
            readonly property real u: Theme.s * parent.k
            readonly property bool onTop: mini.at === "top"
            x: mini.at === "right" ? parent.width - 78 * u : 14 * u
            y: 14 * u
            width: onTop ? parent.width - 28 * u : 64 * u
            height: onTop ? 64 * u : parent.height - 28 * u
            radius: Theme.corner(Math.min(width, height) / 2)
            color: Theme.s1 // like the real bar: its outline and glow as set (BAR)
            border { width: Theme.state.barBorder ? Math.max(1, Theme.state.barBorder * parent.k * Theme.s) : 1; color: Theme.state.barBorder ? Theme.fg : Theme.s3 }
            Rectangle {
                visible: Theme.state.barGlow
                anchors { fill: parent; margins: -2 }
                radius: parent.radius + 2
                color: "transparent"
                border { width: 2; color: Theme.glow }
            }
        }
    }

    // an empty layout cell: 4 × 4 dimmed dots
    component Dots: Grid {
        columns: 4
        padding: 30
        spacing: 28
        Repeater {
            model: 16
            Rectangle { width: 6; height: 6; radius: 3; color: Theme.s3 }
        }
    }

    // a widget in the home layout: a circle or a 40 square (to scale), the icon as dots, the name. The selected one — a white outline,
    // in focus — white entirely. Doesn't fit — a faded outline
    component Tile: Rectangle {
        id: tile
        required property var modelData // { id, i, row, col, span, fits }
        property real cell: 168
        property real gap: 16
        readonly property bool on: modelData.fits && home.cur_?.id === modelData.id
        readonly property bool hot: on && !!home.grid?.activeFocus
        readonly property bool round: root.rounds.includes(modelData.id)
        width: modelData.span * cell + (modelData.span - 1) * gap
        height: cell
        radius: round ? cell / 2 : Theme.corner(cell * 0.18)
        color: hot ? Theme.fg : modelData.fits ? Theme.s1 : "transparent"
        border { width: on ? 2 : 1; color: on ? Theme.fg : modelData.fits ? Theme.s2 : Theme.mute }
        z: drag.active ? 1 : 0
        // without a target the offset is in scene px, and Stage is scaled
        readonly property real dx: drag.activeTranslation.x / Theme.s
        readonly property real dy: drag.activeTranslation.y / Theme.s
        transform: Translate { x: drag.active ? tile.dx : 0; y: drag.active ? tile.dy : 0 }
        Behavior on color { ColorAnimation { duration: Theme.t } }

        Ring {
            visible: tile.round && tile.cell > 100
            anchors { fill: parent; margins: 10 }
            n: 40
            dot: 4
            f: 0.66
            on: tile.hot ? Theme.ink : Theme.fg
            off: tile.hot ? Theme.fade(Theme.ink, 0.15) : Theme.s3
        }
        Column {
            anchors.centerIn: parent
            spacing: 10
            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.icons[tile.modelData.id] ?? "?"
                font.pixelSize: tile.cell * 0.26
                color: tile.hot ? Theme.ink : tile.modelData.fits ? Theme.fg : Theme.grey
                layer.enabled: true
                layer.effect: Dm { step: 3 }
            }
            Lb { visible: tile.cell > 100; anchors.horizontalCenter: parent.horizontalCenter; text: tile.modelData.id; px: 10; color: tile.hot ? Theme.ink : Theme.grey }
        }
        TapHandler { onTapped: home.tap(tile.modelData.i) }
        // the drop — after the signal: changing the list recreates the tiles, this one included
        DragHandler {
            id: drag
            target: null
            onActiveChanged: {
                if (active) {
                    if (tile.modelData.fits) home.cur = tile.modelData.row * 3 + tile.modelData.col;
                    return;
                }
                if (!home.grid) return;
                const p = home.grid.mapFromItem(tile.parent, tile.x + tile.width / 2 + tile.dx, tile.y + tile.height / 2 + tile.dy);
                Qt.callLater(home.land, tile.modelData.i, p);
            }
        }
    }
}
