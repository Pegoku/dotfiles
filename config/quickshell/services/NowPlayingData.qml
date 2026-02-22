pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    property var entries: []
    property int playingCount: entries.length
    readonly property var primary: entries.length > 0 ? entries[0] : null
    readonly property string primaryTitle: primary ? primary.title : "No media"
    readonly property string primaryArtist: primary ? primary.artist : ""

    function formatTime(seconds) {
        if (seconds === undefined || seconds === null)
            return "--:--";

        var total = Math.floor(Number(seconds));
        if (isNaN(total) || total < 0)
            return "--:--";

        var minutes = Math.floor(total / 60);
        var secs = total % 60;
        return minutes + ":" + (secs < 10 ? "0" + secs : secs);
    }

    function resync() {
        var list = Mpris.players?.values ?? [];
        var nextEntries = [];

        for (var i = 0; i < list.length; i++) {
            var p = list[i];
            if (!p || !p.isPlaying)
                continue;

            nextEntries.push({
                player: p.identity && p.identity.length > 0 ? p.identity : (p.desktopEntry && p.desktopEntry.length > 0 ? p.desktopEntry : p.dbusName),
                title: p.trackTitle && p.trackTitle.length > 0 ? p.trackTitle : "Unknown title",
                artist: p.trackArtist && p.trackArtist.length > 0 ? p.trackArtist : "Unknown artist",
                artUrl: p.trackArtUrl && p.trackArtUrl.length > 0 ? p.trackArtUrl : "",
                position: formatTime(p.position),
                length: formatTime(p.length),
                canToggle: p.canTogglePlaying,
                canNext: p.canGoNext,
                canPrevious: p.canGoPrevious,
                playerRef: p
            });
        }

        root.entries = nextEntries;
    }

    Timer {
        interval: 900
        repeat: true
        running: true
        onTriggered: root.resync()
    }

    Component.onCompleted: root.resync()
}
