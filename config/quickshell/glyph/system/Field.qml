import QtQuick
import qs
import qs.components

// an input row: a pill, the label on the left, the text on the right. ↵ — accepted. Swallows ↑↓: otherwise they go to the window and change the section
Rectangle {
    id: root
    property string label
    property alias text: input.text
    property string hint
    property bool secret
    signal accepted

    function focusIn() { input.forceActiveFocus(); }

    width: 480
    height: 64
    radius: Theme.corner(32)
    color: Theme.s2
    border { width: input.activeFocus ? 1 : 0; color: Theme.fg }

    Lb {
        id: head
        anchors.verticalCenter: parent.verticalCenter
        leftPadding: 28
        rightPadding: 14
        text: root.label
        color: input.activeFocus ? Theme.fg : Theme.grey
    }
    TextInput {
        id: input
        anchors { left: head.right; right: parent.right; rightMargin: 26; verticalCenter: parent.verticalCenter }
        activeFocusOnTab: true
        echoMode: root.secret ? TextInput.Password : TextInput.Normal
        passwordCharacter: "•"
        font { family: Theme.mono; pixelSize: 16 }
        color: Theme.fg
        selectionColor: Theme.fg
        selectedTextColor: Theme.ink
        clip: true
        onAccepted: root.accepted()
        Keys.onPressed: e => { if (e.key === Qt.Key_Up || e.key === Qt.Key_Down) e.accepted = true; }
        Lb { anchors.verticalCenter: parent.verticalCenter; visible: !input.text; text: root.hint; color: Theme.mute }
    }
    TapHandler { onTapped: input.forceActiveFocus() }
}
