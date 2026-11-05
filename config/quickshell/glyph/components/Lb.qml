import QtQuick
import qs

// a label: Space Mono in caps, .14em tracking, grey. Size — px (not font.pixelSize: the tracking is computed from it)
Text {
    textFormat: Text.PlainText // labels show other people's strings (networks, devices, windows, tracks): AutoText would load <img src="http://…"> from them
    property real px: 12
    font { family: Theme.mono; pixelSize: px; letterSpacing: px * 0.14; capitalization: Font.AllUppercase }
    color: Theme.grey
}
