import QtQuick
import qs
import qs.services

// back · play (a red circle — «live») · forward
Row {
    id: root

    property real size: 22
    property real play: 52

    spacing: root.size

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        text: "\u{F04AE}"
        font.pixelSize: root.size
        color: Media.player?.canGoPrevious ? Theme.fg : Theme.mute
        TapHandler { onTapped: Media.player?.previous() }
    }
    Rectangle {
        width: root.play
        height: root.play
        radius: root.play / 2
        color: Theme.red
        Icon { anchors.centerIn: parent; text: Media.playing ? "\u{F03E4}" : "\u{F040A}"; color: Theme.light ? Theme.ink : Theme.fg; font.pixelSize: root.play * 0.46 } // the palette's white: with the wallpaper — with its tint
        TapHandler { onTapped: Media.player?.togglePlaying() }
    }
    Icon {
        anchors.verticalCenter: parent.verticalCenter
        text: "\u{F04AD}"
        font.pixelSize: root.size
        color: Media.player?.canGoNext ? Theme.fg : Theme.mute
        TapHandler { onTapped: Media.player?.next() }
    }
}
