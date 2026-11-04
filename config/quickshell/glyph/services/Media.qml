pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick

// the active player (the playing one or the first) and the song lyrics from lrclib.net
Singleton {
    id: root

    readonly property var players: Mpris.players.values
    readonly property MprisPlayer player: players.find(p => p.isPlaying) ?? players[0] ?? null
    readonly property bool playing: player?.isPlaying ?? false
    property real position: 0

    property var lyrics: []   // [[seconds, line], …], empty — no synced lyrics
    readonly property int line: {
        let i = -1;
        for (let k = 0; k < lyrics.length && lyrics[k][0] <= position; k++) i = k;
        return i;
    }

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

    readonly property string track: player ? `${player.trackArtist}\n${player.trackTitle}` : ""
    onTrackChanged: {
        lyrics = [];
        position = player?.position ?? 0;
        if (!player?.trackTitle) return;
        lrc.command = ["curl", "-sfG", "--max-time", "10", "https://lrclib.net/api/get",
            "--data-urlencode", "artist_name=" + player.trackArtist,
            "--data-urlencode", "track_name=" + player.trackTitle];
        lrc.running = true;
    }

    Process {
        id: lrc
        stdout: StdioCollector {
            onStreamFinished: {
                let j;
                try { j = JSON.parse(text); } catch (e) { return; }
                root.lyrics = (j.syncedLyrics ?? "").split("\n").map(l => {
                    const m = l.match(/^\[(\d+):([\d.]+)\]\s*(.*)$/);
                    return m ? [+m[1] * 60 + +m[2], m[3]] : null;
                }).filter(x => x && x[1]);
            }
        }
    }
}
