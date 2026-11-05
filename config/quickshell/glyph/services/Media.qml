pragma Singleton

import Quickshell
import Quickshell.Services.Mpris
import QtQuick

// the active player (the playing one or the first)
Singleton {
    id: root

    readonly property var players: Mpris.players.values
    readonly property MprisPlayer player: players.find(p => p.isPlaying) ?? players[0] ?? null
    readonly property bool playing: player?.isPlaying ?? false
    property real position: 0

    function time(s) {
        s = Math.max(0, Math.floor(s || 0));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    // the mpris position has to be polled
    Timer {
        running: root.playing
        interval: 500
        repeat: true
        onTriggered: root.position = root.player?.position ?? 0
    }

    // a new track: the position at once, without waiting for the poll
    readonly property string track: player ? `${player.trackArtist}\n${player.trackTitle}` : ""
    onTrackChanged: position = player?.position ?? 0
}
