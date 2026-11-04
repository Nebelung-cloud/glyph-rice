import QtQuick
import qs
import qs.components

// recording settings under the tiles (right click on record): area, sound, fps, quality, cursor.
// They live in Theme.state, recording from the screenshot tool uses them too (Sys.recArgs)
Rectangle {
    id: root
    signal touched // any click inside — the panel is pinned
    signal start

    readonly property var st: Theme.state

    height: list.height + 32
    radius: 30
    color: Theme.s2

    Column {
        id: list
        x: 16
        y: 16
        width: parent.width - 32
        spacing: 8

        Lb { x: 4; text: "recording · ~/videos" }

        Choice { label: "area"; opts: ["screen", "region"]; cur: root.st.recArea; onPicked: i => root.st.recArea = i }
        Choice { label: "audio"; opts: ["off", "sys", "mic", "both"]; cur: root.st.recAudio; onPicked: i => root.st.recAudio = i }
        Choice { label: "fps"; opts: Sys.recFps; cur: Math.max(0, Sys.recFps.indexOf(root.st.recFps)); onPicked: i => root.st.recFps = Sys.recFps[i] }
        Choice { label: "quality"; opts: ["med", "high", "max", "ultra"]; cur: root.st.recQuality; onPicked: i => root.st.recQuality = i }
        Choice { label: "cursor"; opts: ["on", "off"]; cur: root.st.recCursor ? 0 : 1; onPicked: i => root.st.recCursor = i === 0 }

        // start/stop; recording — a red dot, the only red thing on the panel
        Rectangle {
            width: list.width
            height: 54
            radius: 27
            color: Theme.fg
            Row {
                anchors.centerIn: parent
                spacing: 10
                Rectangle { visible: Sys.rec; anchors.verticalCenter: parent.verticalCenter; width: 10; height: 10; radius: 5; color: Theme.red }
                Lb { anchors.verticalCenter: parent.verticalCenter; text: Sys.rec ? "stop recording" : "start recording"; color: Theme.ink }
            }
            TapHandler { onTapped: root.start() }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
        }
    }

    // a choice row: a label on the left, the white fill slides to the selected cell — like the power mode
    component Choice: Item {
        id: ch
        property string label
        property var opts: []
        property int cur
        signal picked(int i)
        width: list.width
        height: 44
        Lb { x: 4; anchors.verticalCenter: parent.verticalCenter; text: ch.label; px: 10 }
        Rectangle {
            id: track
            x: 96
            width: parent.width - x
            height: parent.height
            radius: height / 2
            color: Theme.s1
            readonly property real cell: (width - 8) / ch.opts.length
            Rectangle {
                x: 4 + track.cell * ch.cur
                y: 4
                width: track.cell
                height: parent.height - 8
                radius: height / 2
                color: Theme.fg
                Behavior on x { NumberAnimation { duration: Theme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.glide } }
            }
            Repeater {
                model: ch.opts
                Item {
                    id: cell
                    required property int index
                    required property var modelData
                    x: 4 + track.cell * index
                    width: track.cell
                    height: track.height
                    Lb { anchors.centerIn: parent; px: 10; text: cell.modelData; color: ch.cur === cell.index ? Theme.ink : Theme.grey }
                    TapHandler { onTapped: { root.touched(); ch.picked(cell.index); } }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }
            }
        }
    }
}
