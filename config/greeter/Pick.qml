import QtQuick
import qs
import qs.components

// a side list on the login screen: label, key hint, rows with a dot. The picked dot stretches into a pill
Column {
    id: root

    property string label
    property string hint
    property var model: []
    property int current: -1 // -1: nothing stays picked (power)
    signal picked(int index)

    spacing: 14

    Row {
        spacing: 12
        Lb { text: root.label }
        Lb { text: root.hint; color: Theme.mute }
    }
    Repeater {
        model: root.model

        Item {
            id: row
            required property int index
            required property string modelData
            readonly property bool on: index === root.current

            width: 340
            height: 28

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: row.on ? 26 : 11
                height: 11
                radius: 5.5
                color: row.on ? Theme.fg : mouse.containsMouse ? Theme.grey : Theme.s3
                Behavior on width { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
                Behavior on color { ColorAnimation { duration: Theme.t } }
            }
            Text {
                x: 42
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData
                font { family: Theme.ui; pixelSize: 20 }
                color: row.on || mouse.containsMouse ? Theme.fg : Theme.grey
                Behavior on color { ColorAnimation { duration: Theme.t } }
            }
            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.picked(row.index)
            }
        }
    }
}
