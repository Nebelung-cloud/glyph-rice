import QtQuick
import qs

// numbers and short words: Doto, round dots (ROND 100). No smaller than 26px.
// The frame — like line-height .85 in the concept: lineHeight doesn't work on single-line Text, hence negative padding
// (the Doto line 1.2em → .85em). Your own spacing — `topPadding: lead + 8`
Text {
    textFormat: Text.PlainText
    readonly property real lead: -0.175 * font.pixelSize
    font { family: Theme.dot; pixelSize: 44; weight: Font.Black; variableAxes: ({ "ROND": 100, "wght": 900 }) }
    topPadding: lead
    bottomPadding: lead
    color: Theme.fg
}
