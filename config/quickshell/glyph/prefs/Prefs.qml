import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs
import qs.components
import qs.services
import qs.settings

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
    readonly property string rings: "drag round the rings · scroll"
    readonly property var hints: [moves, moves, moves, "", "hover to preview · ↵ or click sets it", rings, ""]
    readonly property var r: Rules.store

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
        shown = true;
        stage.forceActiveFocus();
    }
    function close() { shown = false; }
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
    // bento layout, like home's (and like grid-auto-flow in the concept): left to right, top to bottom; doesn't fit in a row — from the next one,
    // the hole stays; three rows, beyond that — skipped
    function pack(ids) {
        let row = 0, col = 0;
        return ids.map((w, i) => {
            const span = Theme.kinds[w] ?? 1;
            if (col + span > 3) {
                row++;
                col = 0;
            }
            const c = { id: w, i, row, col, span, fits: row < 3 };
            col += span;
            return c;
        });
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
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Up || e.key === Qt.Key_K) root.go(root.sel - 1);
            else if (e.key === Qt.Key_Down || e.key === Qt.Key_J) root.go(root.sel + 1);
            else if (e.key === Qt.Key_Right && stage.activeFocus) stage.nextItemInFocusChain(true)?.forceActiveFocus();
            else if (e.key === Qt.Key_Escape) root.leave();
            else return;
            e.accepted = true;
        }

        // sections: the selected one large with a red dot (while the name is being typed, the red is the caret, the dot turns white)
        Column {
            x: 150 - 30 * (1 - root.t)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 22
            Repeater {
                model: root.sections
                Row {
                    id: word
                    required property string modelData
                    required property int index
                    readonly property bool on: root.sel === index
                    spacing: 26
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: word.on
                        width: 26
                        height: 26
                        radius: 13
                        color: name.activeFocus ? Theme.fg : Theme.accent
                    }
                    Grow { text: word.modelData; on: word.on; big: 112; small: 46; anchors.verticalCenter: parent.verticalCenter }
                    TapHandler { onTapped: root.go(word.index) }
                }
            }
        }

        Row {
            x: 150
            anchors { bottom: parent.bottom; bottomMargin: 70 }
            spacing: 34
            Lb { text: "↑↓ section" }
            Lb { text: "tab · ←→ change" }
            Lb { visible: !!text; text: root.hints[root.sel] }
            Lb { text: root.fromSystem ? "esc back" : "esc close"; TapHandler { onTapped: root.leave() } }
        }

        // ---- HOME: home at a 168/220 scale — the same kinds, order and layout. Click — select, another click or ↵ — the next kind,
        // drag — take the place of the one it's dropped on. What doesn't fit in 3 × 3 — a faded outline on the right ----
        Page {
            id: home
            k: 0
            caption: `home · bento 3 × 3 · ${used} of 9 cells`
            readonly property var cells: root.pack(Theme.state.widgets)
            readonly property var placed: cells.filter(c => c.fits)
            readonly property var off: cells.filter(c => !c.fits)
            readonly property int used: placed.reduce((a, c) => a + c.span, 0)
            readonly property var cur_: cells[cur] ?? null
            property int cur: 0

            function tap(i) {
                grid.forceActiveFocus();
                cur = cur === i ? root.cycle("widgets", i, Object.keys(Theme.kinds)) : i;
            }
            // dropped at grid point p: on a widget — its place, on an empty cell — after the last one before it; outside the grid — nothing
            function land(i, p) {
                if (p.x < 0 || p.y < 0 || p.x > grid.width || p.y > grid.height) return;
                const at = Math.min(2, Math.floor(p.y / 184)) * 3 + Math.min(2, Math.floor(p.x / 184));
                const hit = placed.find(c => c.row * 3 + c.col <= at && at < c.row * 3 + c.col + c.span);
                const n = placed.filter(c => c.row * 3 + c.col < at).length; // the ones that fit — always the start of the list
                cur = root.move("widgets", i, hit ? hit.i : i < n ? n - 1 : n);
            }

            Row {
                spacing: 60

                Item {
                    id: grid
                    width: 536
                    height: 536
                    activeFocusOnTab: true
                    Keys.onPressed: e => {
                        const c = root.nav(e, "widgets", home.cur, Object.keys(Theme.kinds));
                        if (c < 0) return;
                        home.cur = c;
                        e.accepted = true;
                    }
                    Repeater {
                        model: 9
                        Dots {
                            required property int index
                            x: index % 3 * 184
                            y: Math.floor(index / 3) * 184
                        }
                    }
                    Repeater {
                        model: home.placed
                        Tile {
                            x: modelData.col * 184
                            y: modelData.row * 184
                        }
                    }
                }

                Column {
                    width: 404
                    spacing: 12
                    Lb { text: "cells" }
                    Row {
                        spacing: 10
                        Num { id: usedN; text: home.used; font.pixelSize: 150 }
                        Num { anchors.baseline: usedN.baseline; text: "/9"; font.pixelSize: 54; color: Theme.mute }
                    }
                    Lb {
                        width: parent.width
                        elide: Text.ElideRight
                        text: !home.cur_ ? "empty · ↵ adds one" : `${home.cur_.id} · ${home.cur_.span} cell${home.cur_.span > 1 ? "s" : ""}${home.cur_.fits ? "" : " · off grid"}`
                    }
                    // the cat's gif (services/Gifs) — while the cat is selected. A click or ←→ when focused
                    Column {
                        id: gifPick
                        visible: home.cur_?.id === "cat"
                        topPadding: 28
                        spacing: 12
                        Lb {
                            width: 404
                            elide: Text.ElideRight
                            text: `gif · ${Gifs.name(Gifs.cur)} · ${Gifs.sel + 1} of ${Gifs.list.length}`
                            color: gifStrip.activeFocus ? Theme.fg : Theme.grey
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
                                border { width: on ? 2 : 1; color: on ? Theme.fg : Theme.s2 }
                                GifDots { anchors { fill: parent; margins: 6 } path: th.modelData; bg: th.color; playing: gifPick.visible && root.visible }
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
                    Item { width: 1; height: 40 }
                    Lb { text: home.off.length ? `off grid · ${home.off.length}` : "everything fits" }
                    Flow {
                        width: parent.width
                        spacing: 10
                        Repeater {
                            model: home.off
                            Tile { cell: 84; gap: 8 }
                        }
                    }
                    // the photo widget: only when it's on home. The shots — the first five in the folder (services/Photos)
                    Column {
                        visible: Theme.state.widgets.includes("photo")
                        topPadding: 28
                        spacing: 12
                        Lb { width: 404; elide: Text.ElideMiddle; text: `photo · ${Photos.list.length} of ${Photos.most} in ${Photos.dir.replace(Quickshell.env("HOME"), "~")}` }
                        Pick { label: "shape"; opts: ["square", "circle"]; cur: Theme.state.photoRound ? 1 : 0; onPicked: i => Theme.state.photoRound = i === 1 }
                        Pick { label: "look"; opts: ["dots", "color dots", "color"]; cur: [0, 3, 2].indexOf(Theme.state.photoLook); onPicked: i => Theme.state.photoLook = [0, 3, 2][i] }
                    }
                }
            }

            Tray {
                ids: Object.keys(Theme.kinds)
                icons: root.icons
                used: Theme.state.widgets
                dim: home.off.map(c => c.id)
                widths: Theme.kinds
                onToggled: key => home.cur = root.flip("widgets", key, home.cur)
            }
        }

        // ---- DECK: a screen, the deck at the bottom center, quick settings on the right; both slide out on hovering their edge.
        // Deck sections in order, like in the panel; the tray — which ones exist ----
        Page {
            id: deck
            k: 1
            caption: `deck · ${Theme.state.deck.length} of ${Theme.decks.length} sections · bottom edge`
            property int cur: 0
            // dragging section from (-1 — none): dx — the cursor offset in layout px, at — where it is in the strip, to — where it'll land
            property int from: -1
            property real dx: 0
            readonly property real at: Math.max(10, Math.min(10 + (Theme.state.deck.length - 1) * 104, 10 + from * 104 + dx))
            readonly property int to: Math.round((at - 10) / 104)

            Row {
                spacing: 40

                Mini {
                    // the edges that catch the cursor: bottom — the deck, right — quick settings
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

                Column {
                    spacing: 14
                    Toggle { width: 200; text: "deck · hover"; on: Theme.state.deckHover; onFlip: Theme.state.deckHover = !Theme.state.deckHover }
                    Toggle { width: 200; text: "quick · hover"; on: Theme.state.quickHover; onFlip: Theme.state.quickHover = !Theme.state.quickHover }
                    Lb { topPadding: 6; text: "bottom edge · right edge"; px: 10 }
                }
            }

            Tray {
                ids: Theme.decks
                icons: root.icons
                used: Theme.state.deck
                onToggled: key => deck.cur = root.flip("deck", key, deck.cur)
            }
        }

        // ---- BAR: the edge — screens in miniature, a click picks. The tray — like in the bar: at the side a column (labels beside it), on top
        // a row (labels under the icon), in order; drag along the bar. The tray below — what exists ----
        Page {
            id: bar
            k: 2
            caption: `bar · ${Theme.state.bar.length} of ${Theme.bars.length} in the tray · ${Theme.state.barAt} edge`
            readonly property bool onTop: Theme.state.barAt === "top"
            readonly property real step: onTop ? 104 : 68 // a slot along the bar
            property int cur: 0
            // dragging from (-1 — none): d — the cursor offset along the bar in layout px, at — where it is, to — where it'll land
            property int from: -1
            property real d: 0
            readonly property real at: Math.max(10, Math.min(10 + (Theme.state.bar.length - 1) * step, 10 + from * step + d))
            readonly property int to: Math.round((at - 10) / step)

            Grid {
                columns: bar.onTop ? 1 : 2
                columnSpacing: 200
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

                Column {
                    spacing: 14
                    Lb { text: "edge" }
                    // screens with a pill at their edge; ←→ — another one
                    Row {
                        id: edges
                        spacing: 20
                        activeFocusOnTab: true
                        Keys.onPressed: e => {
                            if (e.key !== Qt.Key_Left && e.key !== Qt.Key_Right && e.key !== Qt.Key_Space && e.key !== Qt.Key_Return) return;
                            const all = ["left", "right", "top"], back = e.key === Qt.Key_Left ? 2 : 1;
                            Theme.state.barAt = all[(all.indexOf(Theme.state.barAt) + back) % 3];
                            e.accepted = true;
                        }
                        Repeater {
                            model: ["left", "right", "top"]
                            Column {
                                id: ed
                                required property string modelData
                                readonly property bool on: modelData === Theme.state.barAt
                                spacing: 10
                                Rectangle {
                                    width: 200
                                    height: 125
                                    radius: Theme.corner(18)
                                    color: Theme.bg
                                    border { width: ed.on && edges.activeFocus ? 2 : 1; color: ed.on ? Theme.fg : Theme.s3 }
                                    Behavior on border.color { ColorAnimation { duration: Theme.t } }
                                    Rectangle {
                                        x: ed.modelData === "right" ? parent.width - 26 : 10
                                        y: 10
                                        width: ed.modelData === "top" ? parent.width - 20 : 16
                                        height: ed.modelData === "top" ? 16 : parent.height - 20
                                        radius: Theme.corner(8)
                                        color: ed.on ? Theme.fg : Theme.s3
                                        Behavior on color { ColorAnimation { duration: Theme.t } }
                                    }
                                    TapHandler { onTapped: Theme.state.barAt = ed.modelData }
                                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                                }
                                Lb { anchors.horizontalCenter: parent.horizontalCenter; text: ed.modelData; px: 10; color: ed.on ? Theme.fg : Theme.grey }
                            }
                        }
                    }
                    Item { width: 1; height: 12 }
                    Toggle { width: 200; text: "window title"; on: Theme.state.barTitle; onFlip: Theme.state.barTitle = !Theme.state.barTitle }
                    Lb { topPadding: 6; text: bar.onTop ? "left of the clock" : "above the clock"; px: 10 }
                    Item { width: 1; height: 6 }
                    Repeater {
                        model: bar.onTop ? [] : Quickshell.screens
                        Toggle {
                            required property var modelData
                            width: 200
                            text: `hide · ${modelData.name}`
                            on: Theme.state.barHide.includes(modelData.name)
                            onFlip: {
                                const a = Theme.state.barHide.filter(n => n !== modelData.name);
                                if (!on) a.push(modelData.name);
                                Theme.state.barHide = a;
                            }
                        }
                    }
                    Lb { visible: !bar.onTop; topPadding: 6; text: "auto-hide · experimental"; px: 10 }
                }
            }

            Tray {
                ids: Theme.bars
                icons: root.icons
                used: Theme.state.bar
                onToggled: key => bar.cur = root.flip("bar", key, bar.cur)
            }
        }

        // ---- LOOK: a miniature home follows the toggles; the name — into the pill ----
        Page {
            id: look
            k: 3
            caption: "look · the home screen, live"
            property bool dim: false // the colon went dark
            Timer { running: look.visible && root.visible && Theme.state.blink; interval: 500; repeat: true; onTriggered: look.dim = !look.dim }

            Row {
                spacing: 40

                Mini {
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
                    // Glyph strips: volume on the right, progress at the bottom
                    Seg { visible: Theme.state.edges; x: parent.width - 12; y: 140; width: 4; height: 200; n: 12; f: 0.6; vertical: true }
                    Seg { visible: Theme.state.edges; x: 230; y: parent.height - 10; width: 300; height: 4; n: 24; f: 0.4 }
                }

                Column {
                    spacing: 14
                    Toggle { width: 200; text: "dot grid"; on: Theme.state.grid; onFlip: Theme.state.grid = !Theme.state.grid }
                    Toggle { width: 200; text: "orb"; on: Theme.state.orb; onFlip: Theme.state.orb = !Theme.state.orb }
                    Toggle { width: 200; text: "24 hours"; on: Theme.state.clock24; onFlip: Theme.state.clock24 = !Theme.state.clock24 }
                    Toggle { width: 200; text: "blink"; on: Theme.state.blink; onFlip: Theme.state.blink = !Theme.state.blink }
                    Toggle { width: 200; text: "edges"; on: Theme.state.edges; onFlip: Theme.state.edges = !Theme.state.edges }
                    Toggle { width: 200; text: "island lights"; on: Theme.state.glyphLights === 1; onFlip: Theme.state.glyphLights = Theme.state.glyphLights === 1 ? 0 : 1 }
                    Act {
                        icon: "\u{F02E9}"
                        text: "wallpaper"
                        onHit: {
                            root.close();
                            root.wallRequested();
                        }
                    }
                }

            }

            // what home shows, and the lock
            Row {
                spacing: 12
                Lb { width: 110; anchors.verticalCenter: parent.verticalCenter; text: "on home" }
                Toggle { text: "clock"; on: Theme.state.homeClock; onFlip: Theme.state.homeClock = !Theme.state.homeClock }
                Toggle { text: "greeting"; on: Theme.state.homeHello; onFlip: Theme.state.homeHello = !Theme.state.homeHello }
                Toggle { text: "widgets"; on: Theme.state.homeBento; onFlip: Theme.state.homeBento = !Theme.state.homeBento }
                Toggle {
                    readonly property bool all: Theme.state.homeClock && Theme.state.homeHello && Theme.state.homeBento
                    text: "all"
                    on: all
                    onFlip: {
                        const v = !all;
                        Theme.state.homeClock = v;
                        Theme.state.homeHello = v;
                        Theme.state.homeBento = v;
                    }
                }
            }
            Row {
                spacing: 12
                Lb { width: 110; anchors.verticalCenter: parent.verticalCenter; text: "on the lock" }
                Toggle { text: "atmosphere"; on: Theme.state.atmosphere; onFlip: Theme.state.atmosphere = !Theme.state.atmosphere }
                Toggle { text: "hide length"; on: Theme.state.lockHideLen; onFlip: Theme.state.lockHideLen = !Theme.state.lockHideLen }
                Toggle { text: "one screen"; on: Theme.state.lockOneScreen; onFlip: Theme.state.lockOneScreen = !Theme.state.lockOneScreen }
            }

            // the name in the greeting; empty — $USER
            Rectangle {
                width: 760
                height: 72
                radius: Theme.corner(36)
                color: Theme.s2
                border { width: name.activeFocus ? 1 : 0; color: Theme.fg }
                Lb { id: nameL; x: 30; anchors.verticalCenter: parent.verticalCenter; text: "name"; color: name.activeFocus ? Theme.fg : Theme.grey }
                TextInput {
                    id: name
                    anchors { left: nameL.right; leftMargin: 24; right: parent.right; rightMargin: 30; verticalCenter: parent.verticalCenter }
                    text: Theme.state.name
                    maximumLength: 24
                    activeFocusOnTab: true
                    font { family: Theme.ui; pixelSize: 24 }
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
                    Keys.onPressed: e => {
                        if (e.key === Qt.Key_Up || e.key === Qt.Key_Down) root.go(root.sel + (e.key === Qt.Key_Up ? -1 : 1));
                        else if (e.key === Qt.Key_Escape || e.key === Qt.Key_Return || e.key === Qt.Key_Enter) stage.forceActiveFocus();
                        else return;
                        e.accepted = true;
                    }
                }
            }
        }

        // ---- STYLE: where color comes from and where it lands. On top — a desktop in the palette of the swatch under the cursor or focused (none —
        // in the current one): bar, quick settings, kitty, player, the Glyph bar; beside it — the roles as callouts, like on a
        // blueprint: which color goes where. Under it where color comes from and the theme; then what the source has: the wallpaper in dots (click — the picker), its tones
        // and variants (the ring — how much color) or palettes by group. The same choice as style in the launcher (Theme.styles).
        // Swatches by index: a new Theme.styles on every pick doesn't recreate the circles, and focus stays where it was ----
        Page {
            id: tint
            k: 4
            property Item hot: null // the swatch under the cursor or focused
            readonly property var p: hot?.item.pal ?? Theme.pal
            readonly property string src: Theme.state.paint === "scheme" ? (Theme.pal.group === "more" ? "" : Theme.pal.group + " ") + Theme.pal.name
                : Theme.state.paint === "wall" && Theme.tones.length ? `wallpaper · ${Theme.pal.name}` : "nothing"
            caption: `style · ${src} · ${Theme.light ? "light" : "dark"}` + (hot && !hot.item.now ? `   →   ${hot.item.name} · ↵ sets it` : "")
            function block(h) { return Theme.styles.find(b => b.head === h)?.items ?? []; }
            function peek(sw) {
                if (sw.peek) hot = sw;
                else if (hot === sw) hot = null;
            }

            Desk { p: tint.p }

            Row {
                spacing: 24
                Pick {
                    label: "from"
                    opts: ["nothing", "wall", "palette"]
                    cur: ["", "wall", "scheme"].indexOf(Theme.state.paint)
                    onPicked: i => Theme.state.paint = ["", "wall", "scheme"][i]
                }
                Pick { label: "theme"; opts: ["dark", "light"]; cur: Theme.light ? 1 : 0; onPicked: i => Theme.setLight(i === 1) }
                Toggle { opacity: Theme.light ? 0.4 : 1; text: "extra dark"; on: Theme.state.extraDark; onFlip: if (!Theme.light) Theme.state.extraDark = !Theme.state.extraDark }
            }

            // what the source has. One height for all: Page is centered, and the layout shouldn't jump when the source changes. ponytail: 300 — by
            // eye, palettes in two rows; if it grows — the Item grows with it
            Item {
                width: 1040
                height: Math.max(300, own.height)
                Column {
                    id: own
                    spacing: 28
                    Lb { visible: !Theme.state.paint; text: "black · white dots · one red — nothing to pick"; color: Theme.mute }
                    Row {
                        visible: Theme.state.paint === "wall"
                        spacing: 34
                        // the wallpaper in dots; click — the picker
                        Rectangle {
                            width: 168
                            height: 105
                            radius: Theme.corner(14)
                            color: "transparent"
                            border { width: Theme.state.wall ? 0 : 1; color: Theme.s3 }
                            Image {
                                anchors.fill: parent
                                source: visible ? Theme.url(Theme.wallSrc(Theme.state.wall)) : "" // not visible — no texture
                                fillMode: Image.PreserveAspectCrop
                                sourceSize: Qt.size(336, 210)
                                asynchronous: true
                                layer.enabled: true
                                layer.effect: Dm { step: 4 }
                            }
                            Lb { visible: !Theme.state.wall; anchors.centerIn: parent; px: 10; text: "no wallpaper" }
                            TapHandler {
                                onTapped: {
                                    root.close();
                                    root.wallRequested();
                                }
                            }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                        }
                        Column {
                            spacing: 6
                            Lb { text: Theme.tones.length ? "tones · from the wallpaper" : "no color in it · click it for another" }
                            Row {
                                Repeater {
                                    model: tint.block("tones").length
                                    Swatch { id: tw; item: tint.block("tones")[index] ?? ({ name: "" }); onPeekChanged: tint.peek(tw) }
                                }
                            }
                        }
                    }
                    Pick {
                        visible: Theme.state.paint === "wall" && Theme.tones.length > 0
                        readonly property var amounts: [50, 75, 100, 125, 150, 200]
                        label: "saturation · %"
                        opts: amounts.map(String)
                        cur: amounts.reduce((b, v, i) => Math.abs(v - Theme.state.paintSat) < Math.abs(amounts[b] - Theme.state.paintSat) ? i : b, 0) // an older value snaps to the nearest
                        onPicked: i => Theme.state.paintSat = amounts[i]
                    }
                    Column {
                        visible: Theme.state.paint === "wall" && Theme.tones.length > 0
                        spacing: 6
                        Lb { text: "variant · how much color, like material you" }
                        Row {
                            Repeater {
                                model: tint.block("variant").length
                                Swatch { id: vw; item: tint.block("variant")[index] ?? ({ name: "" }); onPeekChanged: tint.peek(vw) }
                            }
                        }
                    }
                    // palettes by group — the blocks between source and theme
                    Flow {
                        visible: Theme.state.paint === "scheme"
                        width: 1040
                        spacing: 40
                        Repeater {
                            model: Theme.state.paint === "scheme" ? Theme.styles.length - 2 : 0
                            Column {
                                id: sb
                                required property int index
                                readonly property var block: Theme.styles[index + 1] ?? ({ head: "", items: [] })
                                spacing: 6
                                Lb { text: sb.block.head }
                                Row {
                                    Repeater {
                                        model: sb.block.items.length
                                        Swatch { id: pw; item: sb.block.items[index] ?? ({ name: "" }); onPeekChanged: tint.peek(pw) }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---- WINDOWS: a desktop with two windows from the rings' live values. Window animation — only if motion ----
        Page {
            k: 5
            caption: `windows · hyprland · gaps ${gIn.v} / ${gOut.v} · border ${bord.v} · rounding ${rnd.v} · panels ${pan.v} %`

            Row {
                spacing: 40

                Mini {
                    id: desk
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
                                x: 20
                                y: 20
                                spacing: 9
                                Lb { text: wnd.index ? "zen" : "kitty"; px: 10; color: wnd.index ? Theme.mute : Theme.grey }
                                Repeater {
                                    model: [0.7, 0.45, 0.85, 0.3, 0.6, 0.5]
                                    Rectangle {
                                        required property real modelData
                                        width: (wnd.width - 40) * modelData
                                        height: 5
                                        radius: 2.5
                                        color: Theme.s3
                                    }
                                }
                            }
                        }
                    }
                }

                // ponytail: blur and shadows aren't visible in the layout (flat black) — only toggles
                Column {
                    spacing: 14
                    Toggle { width: 200; text: "blur"; on: root.r.blur; onFlip: { root.r.blur = !root.r.blur; Theme.apply(); } }
                    Toggle { width: 200; text: "shadow"; on: root.r.shadow; onFlip: { root.r.shadow = !root.r.shadow; Theme.apply(); } }
                    Toggle { width: 200; text: "motion"; on: root.r.motion; onFlip: { root.r.motion = !root.r.motion; Rules.motion(); } }
                }

            }

            Row {
                spacing: 40
                Dial { id: gIn; label: "gaps in"; to: 30; value: root.r.gapsIn; onMoved: v => { root.r.gapsIn = v; Theme.apply(); } }
                Dial { id: gOut; label: "gaps out"; to: 60; value: root.r.gapsOut; onMoved: v => { root.r.gapsOut = v; Theme.apply(); } }
                Dial { id: bord; label: "border"; to: 6; n: 24; value: root.r.border; onMoved: v => { root.r.border = v; Theme.apply(); } }
                Dial { id: rnd; label: "rounding"; to: 40; value: Theme.state.rounding; onMoved: v => Theme.state.rounding = v } // shell.qml calls Theme.apply itself
                Dial { id: pan; label: "panels"; to: 100; step: 5; value: Theme.state.corners; onMoved: v => Theme.state.corners = v } // the shell's corners, %
            }

            // game mode: starts by itself on a fullscreen game (services/Game), and what stays on in it. Off — game mode drops it
            Row {
                spacing: 12
                Toggle { width: 220; text: "auto game mode"; on: Theme.state.autoGame; onFlip: Theme.state.autoGame = !Theme.state.autoGame }
                Lb { leftPadding: 16; rightPadding: 4; anchors.verticalCenter: parent.verticalCenter; text: "in a game" }
                Toggle { width: 130; text: "gaps"; on: root.r.gameGaps; onFlip: { root.r.gameGaps = !root.r.gameGaps; Theme.apply(); } }
                Toggle { width: 130; text: "motion"; on: root.r.gameMotion; onFlip: { root.r.gameMotion = !root.r.gameMotion; Rules.motion(); } }
                Toggle { width: 130; text: "blur"; on: root.r.gameBlur; onFlip: { root.r.gameBlur = !root.r.gameBlur; Theme.apply(); } }
                Toggle { width: 130; text: "shadow"; on: root.r.gameShadow; onFlip: { root.r.gameShadow = !root.r.gameShadow; Theme.apply(); } }
                Toggle { width: 130; text: "quiet"; on: root.r.gameDnd; onFlip: root.r.gameDnd = !root.r.gameDnd }
            }
        }

        // ---- SHELL: the rice mark and the live shell's name; the switcher — the Rice app ----
        Page {
            k: 6
            caption: "shell · quickshell"

            Row {
                spacing: 50
                Item {
                    width: 260
                    height: 260
                    Ring { anchors.fill: parent; n: 16; dot: 14; f: 1 }
                    Rectangle { anchors.centerIn: parent; width: 52; height: 52; radius: 26; color: Theme.fg }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 18
                    Lb { text: "running now" }
                    Num { text: root.meta.name ?? "GLYPH"; font.pixelSize: 140 }
                    Lb { text: root.meta.tagline ?? "" }
                }
            }
            Row {
                spacing: 20
                Act {
                    visible: root.shells > 1
                    icon: "\u{F04E1}"
                    text: "switch shell"
                    onHit: {
                        root.close();
                        Quickshell.execDetached(["qs", "-c", "rice"]);
                    }
                }
                Act { icon: "\u{F0450}"; text: "reload"; onHit: Quickshell.reload(false) }
                Toggle { text: "do not disturb"; on: Theme.state.dnd; onFlip: Theme.state.dnd = !Theme.state.dnd }
            }
        }
    }

    // the section on the right: only the selected one is visible (Tab goes only through visible ones), appears from the bottom up
    component Page: Column {
        required property int k
        property string caption
        x: 800
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: visible ? 0 : 24
        visible: root.sel === k
        opacity: visible ? 1 : 0
        spacing: 28
        Behavior on opacity { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
        Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
        Lb { text: parent.caption }
    }

    // a miniature 16:10 screen: the wallpaper (the dot grid, if on) and the bar; k — the screen's logical px in layout px
    component Mini: Rectangle {
        readonly property real k: width / ((Rules.mon.w || 2880) / Rules.scale)
        width: 760
        height: 475
        radius: Theme.corner(24)
        color: Theme.bg
        border { width: 1; color: Theme.s3 }
        Image {
            visible: Theme.state.grid
            anchors { fill: parent; margins: 12 }
            fillMode: Image.Tile
            source: "data:image/svg+xml," + encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16"><circle cx="8" cy="8" r="1" fill="#${Theme.hex(Theme.s2)}"/></svg>`)
        }
        // the bar at its edge: the 14 gap and 64 thickness are layout px, on screen they're Theme.s logical
        Rectangle {
            readonly property real u: Theme.s * parent.k
            readonly property bool onTop: Theme.state.barAt === "top"
            x: Theme.barRight ? parent.width - 78 * u : 14 * u
            y: 14 * u
            width: onTop ? parent.width - 28 * u : 64 * u
            height: onTop ? 64 * u : parent.height - 28 * u
            radius: Theme.corner(Math.min(width, height) / 2)
            color: Theme.s1
            border { width: 1; color: Theme.s2 }
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
        readonly property bool on: home.cur === modelData.i
        readonly property bool hot: on && grid.activeFocus
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
                    home.cur = tile.modelData.i;
                    return;
                }
                const p = grid.mapFromItem(tile.parent, tile.x + tile.width / 2 + tile.dx, tile.y + tile.height / 2 + tile.dy);
                Qt.callLater(home.land, tile.modelData.i, p);
            }
        }
    }
}
