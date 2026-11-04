import QtQuick
import qs
import qs.components

// an idle mark: a stem down to the scale, a Doto number and a name. Drag along the scale, ←→ — by a minute; past 60 — never (0).
// While dragging — its own v, into rules.json and hypridle — on release or after 400 ms of quiet
Item {
    id: mk
    property Item line // the scale: we drag along it
    property real step: 15 // px per minute
    property int row
    property string label
    property int value
    property int v: value
    signal moved(int v)
    function put(m) {
        m = m > 60.5 ? 0 : Math.max(1, Math.round(m));
        if (m === v) return;
        v = m;
        wait.restart();
    }
    onValueChanged: if (!ma.pressed && !wait.running) v = value
    Timer { id: wait; interval: 400; onTriggered: if (!ma.pressed && mk.v !== mk.value) mk.moved(mk.v) }

    x: (v || 62) * step
    y: row * 76
    width: 160
    height: 250 - y
    activeFocusOnTab: true
    Keys.onPressed: e => {
        if (e.key === Qt.Key_Left) put(v ? v - 1 : 60);
        else if (e.key === Qt.Key_Right) put(v ? v + 1 : 61);
        else return;
        e.accepted = true;
    }
    Behavior on x { NumberAnimation { duration: 120 } }

    Rectangle { width: 1; height: parent.height; color: mk.activeFocus || ma.pressed ? Theme.fg : Theme.mute }
    Column {
        x: 12
        Num { text: mk.v || "—"; font.pixelSize: 44 }
        Lb { topPadding: 6; text: mk.label; px: 10; color: mk.activeFocus ? Theme.fg : Theme.grey }
    }
    MouseArea {
        id: ma
        width: parent.width
        height: 76
        preventStealing: true
        cursorShape: Qt.SizeHorCursor
        onPressed: mk.forceActiveFocus()
        onPositionChanged: e => mk.put(mapToItem(mk.line, e.x, 0).x / mk.step)
        onReleased: {
            wait.stop();
            if (mk.v !== mk.value) mk.moved(mk.v);
        }
    }
}
