import QtQuick

// the wheel by notches: notch(±1) per 120 of angle. A hi-res wheel sends 15 per click, so it accumulates, otherwise 8 steps a notch.
// A MouseArea, not a WheelHandler: that one checks the point against the window's geometry too and missed the wheel in the bar.
// No touchpad (scrollGestureEnabled); buttons and hovering pass through. From Nebelung-cloud/glyph-rice dev e518c81 and 5c6a1fc, with rawnullbyte
MouseArea {
    signal notch(int d) // +1 — the wheel away from you
    property real acc: 0
    anchors.fill: parent
    acceptedButtons: Qt.NoButton
    scrollGestureEnabled: false
    onWheel: e => {
        acc += e.angleDelta.y || e.angleDelta.x;
        while (Math.abs(acc) >= 120) {
            notch(Math.sign(acc));
            acc -= Math.sign(acc) * 120;
        }
    }
}
