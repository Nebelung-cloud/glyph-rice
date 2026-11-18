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
    property Item hot: null // the row the inspector shows
    default property alias rows: list.data
    function back() { return false; }
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
    Column {
        id: list
        x: 380
        y: 150 + root.lift
        width: 620
    }

    Column {
        x: 1100
        y: 120 + root.lift
        width: 740
        spacing: 18
        Num { visible: !!text; text: root.hot?.value ?? ""; font.pixelSize: 72; color: Theme.fg }
        Lb { text: root.hot?.title ?? ""; px: 14; color: Theme.fg }
        Text {
            width: 560
            text: root.hot?.about ?? ""
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            lineHeight: 1.3
            font { family: Theme.ui; pixelSize: 19 }
            color: Theme.grey
        }
        Item { width: 1; height: 12 }
        Loader { sourceComponent: root.hot?.preview ?? null }
    }
}
