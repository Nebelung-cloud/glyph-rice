import QtQuick
import qs
import qs.components

// picking from many, when Pick doesn't fit: the label on the left, a white pill with the current one and chevrons on the right. Click — the next one,
// on the left chevron — the previous one; ←→, space. cur -1 — the value isn't among the options: «—»
Rectangle {
    id: root
    property string label
    property var names: []
    property int cur: -1
    signal picked(int i)
    readonly property int n: names.length
    function step(d) { if (n) picked(cur < 0 ? 0 : (cur + d + n) % n); }

    width: 466
    height: 64
    radius: 32
    color: Theme.s2
    border { width: activeFocus ? 1 : 0; color: Theme.fg }
    activeFocusOnTab: true
    Keys.onPressed: e => {
        if (e.key === Qt.Key_Left) step(-1);
        else if (e.key === Qt.Key_Right || e.key === Qt.Key_Space || e.key === Qt.Key_Return || e.key === Qt.Key_Enter) step(1);
        else return;
        e.accepted = true;
    }

    Lb {
        anchors.verticalCenter: parent.verticalCenter
        leftPadding: 28
        width: parent.width - pick.width - 20
        elide: Text.ElideRight
        text: root.label
        color: root.activeFocus ? Theme.fg : Theme.grey
    }
    Row {
        id: pick
        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
        spacing: 4
        Icon { anchors.verticalCenter: parent.verticalCenter; text: "\u{F0141}"; color: Theme.grey }
        Rectangle {
            width: val.implicitWidth + 28
            height: 44
            radius: 22
            color: root.cur >= 0 ? Theme.fg : Theme.s3
            Lb { id: val; anchors.centerIn: parent; text: root.names[root.cur] ?? "—"; color: root.cur >= 0 ? Theme.ink : Theme.grey }
        }
        Icon { anchors.verticalCenter: parent.verticalCenter; text: "\u{F0142}"; color: Theme.grey }
    }
    HoverHandler { cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: p => { root.forceActiveFocus(); root.step(p.position.x < pick.x + 26 ? -1 : 1); } }
}
