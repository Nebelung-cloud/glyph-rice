import QtQuick
import qs

// a canvas in 1920×1080 layout pixels: stretched over the parent, everything inside is measured like in concept.html
Item {
    width: parent.width / Theme.s
    height: parent.height / Theme.s
    scale: Theme.s
    transformOrigin: Item.TopLeft
}
