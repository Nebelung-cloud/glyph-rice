import QtQuick
import qs
import qs.components

// an action button: a pill with a round icon on the left and a label. Click, ↵, space
Rectangle {
    id: act
    property string icon
    property string text
    signal hit
    width: actL.implicitWidth + 110
    height: 64
    radius: 32
    color: Theme.s2
    border { width: activeFocus ? 1 : 0; color: Theme.fg }
    activeFocusOnTab: true
    Keys.onPressed: e => {
        if (e.key !== Qt.Key_Return && e.key !== Qt.Key_Enter && e.key !== Qt.Key_Space) return;
        act.hit();
        e.accepted = true;
    }
    Rectangle {
        x: 6
        y: 6
        width: 52
        height: 52
        radius: 26
        color: Theme.s3
        Icon { anchors.centerIn: parent; text: act.icon; font.pixelSize: 22 }
    }
    Lb { id: actL; x: 76; anchors.verticalCenter: parent.verticalCenter; text: act.text; color: act.activeFocus ? Theme.fg : Theme.grey }
    TapHandler { onTapped: act.hit() }
}
