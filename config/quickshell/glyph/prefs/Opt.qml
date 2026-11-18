import QtQuick
import qs
import qs.components

// one setting as a row: its name, one plain line of what it does, the control in a fixed right column. Focused or hovered — the page's
// inspector shows its value, about and preview. No control — the row itself takes focus (the inspector holds the editor then)
FocusScope {
    id: root

    property string title
    property string hint
    property string about
    property string value
    property Component preview
    property bool wide: false // the control under the words, full width (a row of swatches)
    default property alias control: slot.data
    property Item host: null // the Sheet: the nearest ancestor with `hot`

    readonly property bool lit: activeFocus || hover.hovered
    // each arrival, not `lit`: hovered and focused at once keeps lit true, so returning focus would leave the inspector on another row
    onActiveFocusChanged: if (activeFocus && host) { host.hot = root; host.reveal(root); }
    Component.onCompleted: {
        for (let p = parent; p; p = p.parent) if (p.hot !== undefined) { host = p; break; }
    }

    width: parent?.width ?? 620
    height: (wide ? words.height + 16 + slot.height : Math.max(words.height, slot.height)) + 36
    activeFocusOnTab: !slot.children.length

    // the focused row: a white bar at its left
    Rectangle {
        x: -22
        y: 18
        width: 4
        height: parent.height - 36
        radius: 2
        color: Theme.fg
        visible: root.activeFocus
    }
    Column {
        id: words
        y: 18
        width: root.wide ? parent.width : parent.width - slot.width - 40
        spacing: 6
        Text {
            text: root.title
            textFormat: Text.PlainText
            font { family: Theme.ui; pixelSize: 21 }
            color: root.lit ? Theme.fg : Qt.lighter(Theme.grey, 1.25)
            Behavior on color { ColorAnimation { duration: Theme.t } }
        }
        Text {
            visible: !!text
            width: parent.width
            text: root.hint
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            font { family: Theme.ui; pixelSize: 15 }
            color: Theme.grey
        }
    }
    Item {
        id: slot
        x: root.wide ? 0 : parent.width - width
        y: root.wide ? words.y + words.height + 16 : (parent.height - height) / 2
        width: childrenRect.width
        height: childrenRect.height
    }
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.s2 }

    HoverHandler { id: hover; onHoveredChanged: if (hovered && root.host) root.host.hot = root }
    TapHandler { onTapped: (slot.children[0] ?? root).forceActiveFocus() }
}
