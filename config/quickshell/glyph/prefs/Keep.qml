import QtQuick

// a Repeater model that changes only when its contents do: a new array, even an equal one, rebuilds every row and the keyboard focus
// is lost. src — plain values (ids, names), not objects; rows look their object up by it
QtObject {
    property var src: []
    property var out: []
    onSrcChanged: if (JSON.stringify(src) !== JSON.stringify(out)) out = src
    Component.onCompleted: out = src
}
