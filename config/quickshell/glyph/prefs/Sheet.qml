import QtQuick
import qs
import qs.components

// a settings page as rows + an inspector: the caption and rows top-anchored at a fixed place (switching pages never moves them), the
// inspector on the right follows the focused/hovered row: its value large, what it does, a live preview. Rows — Opt, group
// headings — Lb between them. back() — esc: close its own details first (System pages), true — closed
Item {
    id: root

    property bool on
    property string caption
    property Item hot: null // the row the inspector shows; none yet — the first row
    readonly property Item shown: hot ?? Array.from(list.children).find(c => c.about !== undefined && c.visible) ?? null
    default property alias rows: list.data
    // rows taller than the screen scroll: the focused row is kept in view, the wheel scrolls by hand
    readonly property real room: height - 150 - 130 // stops above the key hints
    property real scroll: 0
    function clampTo(v) { scroll = Math.max(0, Math.min(v, list.height - room)); }
    function reveal(row) {
        const y = row.mapToItem(list, 0, 0).y;
        if (y < scroll) clampTo(y);
        else if (y + row.height > scroll + room) clampTo(y + row.height - room);
    }
    onOnChanged: scroll = 0
    function back() { return false; }
    // a row with no control of its own keeps its editor in the inspector (BAR's buttons, HOME's grid): → or ↵ moves into it, ↑↓ stay
    // inside, esc goes back to the row. While editing, hovering other rows doesn't swap the editor away
    readonly property bool editing: ins.activeFocus
    function inEditor(it) {
        for (; it; it = it.parent) if (it === ins) return true;
        return false;
    }
    function edit() {
        const it = ins.item, f = it?.activeFocusOnTab ? it : it?.nextItemInFocusChain(true);
        if (!inEditor(f)) return false;
        f.forceActiveFocus();
        return true;
    }
    function owns(it) {
        for (; it; it = it.parent) if (it === root) return true;
        return false;
    }

    anchors.fill: parent
    visible: on
    opacity: on ? 1 : 0
    property real lift: on ? 0 : 24
    Behavior on opacity { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
    Behavior on lift { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }

    Lb { x: 380; y: 120 + root.lift; text: root.caption }
    Item {
        x: 340 // 40 px of room left of the rows for the focus bar
        y: 150 + root.lift
        width: 700
        height: root.room
        clip: list.height > root.room
        Column {
            id: list
            x: 40
            y: -root.scroll
            width: 620
            Behavior on y { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
        }
        WheelHandler { onWheel: e => root.clampTo(root.scroll - e.angleDelta.y) }
    }

    Column {
        x: 1100
        y: 120 + root.lift
        width: 740
        spacing: 18
        Num { visible: !!text; text: root.shown?.value ?? ""; font.pixelSize: 72; color: Theme.fg }
        Lb { text: root.shown?.title ?? ""; px: 14; color: Theme.fg }
        Text {
            width: 560
            text: root.shown?.about ?? ""
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            lineHeight: 1.3
            font { family: Theme.ui; pixelSize: 19 }
            color: Theme.grey
        }
        Item { width: 1; height: 12 }
        Loader { id: ins; sourceComponent: root.shown?.preview ?? null }
    }
}
