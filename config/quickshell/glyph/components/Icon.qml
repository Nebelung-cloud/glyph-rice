import QtQuick
import qs

// a Nerd Font glyph (Material Design). A 1em frame, like line-height: 1 in the concept (the NF line is 1.32em)
Text {
    readonly property real lead: -0.16 * font.pixelSize
    font { family: Theme.nf; pixelSize: 19 }
    topPadding: lead
    bottomPadding: lead
    color: Theme.fg
}
