import QtQuick
import qs
import qs.components

// the section on the right, like in Prefs: only the selected one is visible, appears from the bottom up. back() — esc: close its own (details),
// true — closed, the window does nothing
Column {
    property bool on
    property string caption
    function back() { return false; }
    x: 860
    width: 950
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: visible ? 0 : 24
    visible: on
    opacity: visible ? 1 : 0
    spacing: 28
    Behavior on opacity { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
    Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
    Lb { text: parent.caption }
}
