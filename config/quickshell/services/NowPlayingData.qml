pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    property bool debugLogs: true
    property var entries: []
    readonly property int playerCount: entries.length
    property int playingCount: {
        var count = 0;
        for (var i = 0; i < entries.length; i++) {
            if (entries[i].isPlaying)
                count += 1;
        }
        return count;
    }
    readonly property var primary: {
        for (var i = 0; i < entries.length; i++) {
            if (entries[i].isPlaying)
                return entries[i];
        }
        return entries.length > 0 ? entries[0] : null;
    }
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

    function normalizeArtUrl(value) {
        if (value === undefined || value === null)
            return "";

        var art = String(value);
        if (art.length === 0)
            return "";

        if (art.startsWith("/") && !art.startsWith("//"))
            return "file://" + art;

        return art;
    }

    function extractMediaUrl(metadata) {
        if (!metadata)
            return "";

        var url = metadata["xesam:url"];
        if (url === undefined || url === null)
            return "";

        return String(url);
    }

    function youtubeThumbnailFromMediaUrl(mediaUrl) {
        if (!mediaUrl || mediaUrl.length === 0)
            return "";

        var id = "";
        var watchMatch = mediaUrl.match(/[?&]v=([A-Za-z0-9_-]{11})/);
        if (watchMatch && watchMatch.length > 1)
            id = watchMatch[1];

        if (id.length === 0) {
            var shortMatch = mediaUrl.match(/youtu\.be\/([A-Za-z0-9_-]{11})/);
            if (shortMatch && shortMatch.length > 1)
                id = shortMatch[1];
        }

        if (id.length === 0)
            return "";

        return "https://i.ytimg.com/vi/" + id + "/hqdefault.jpg";
    }

    function playbackStateLabel(player) {
        if (!player)
            return "Unknown";
        if (player.playbackState === MprisPlaybackState.Playing)
            return "Playing";
        if (player.playbackState === MprisPlaybackState.Paused)
            return "Paused";
        if (player.playbackState === MprisPlaybackState.Stopped)
            return "Stopped";

        return player.isPlaying ? "Playing" : "Paused";
    }

    function resync() {
        var list = Mpris.players?.values ?? [];
        var nextEntries = [];

        if (root.debugLogs)
            console.log("[NowPlayingData] mpris players:", list.length);

        for (var i = 0; i < list.length; i++) {
            var p = list[i];
            if (!p)
                continue;

            var identity = p.identity ? String(p.identity) : "";
            var desktopEntry = p.desktopEntry ? String(p.desktopEntry) : "";
            var dbusName = p.dbusName ? String(p.dbusName) : "";
            var title = p.trackTitle ? String(p.trackTitle) : "";
            var artist = p.trackArtist ? String(p.trackArtist) : "";
            var mediaUrl = extractMediaUrl(p.metadata);
            var artUrl = normalizeArtUrl(p.trackArtUrl);
            var fallbackArtUrl = youtubeThumbnailFromMediaUrl(mediaUrl);

            if (root.debugLogs) {
                console.log(
                    "[NowPlayingData] player=", identity.length > 0 ? identity : (desktopEntry.length > 0 ? desktopEntry : dbusName),
                    "state=", playbackStateLabel(p),
                    "title=", title,
                    "artist=", artist,
                    "trackArtUrl=", String(p.trackArtUrl),
                    "normalizedArtUrl=", artUrl,
                    "xesam:url=", mediaUrl,
                    "fallbackArtUrl=", fallbackArtUrl
                );
            }

            nextEntries.push({
                player: identity.length > 0 ? identity : (desktopEntry.length > 0 ? desktopEntry : dbusName),
                title: title.length > 0 ? title : "Unknown title",
                artist: artist.length > 0 ? artist : "Unknown artist",
                state: playbackStateLabel(p),
                isPlaying: p.isPlaying,
                artUrl: artUrl,
                fallbackArtUrl: fallbackArtUrl,
                position: formatTime(p.position),
                length: formatTime(p.length),
                canToggle: p.canTogglePlaying,
                canNext: p.canGoNext,
                canPrevious: p.canGoPrevious,
                playerRef: p
            });
        }

        nextEntries.sort((a, b) => {
            if (a.isPlaying === b.isPlaying)
                return a.player.localeCompare(b.player);
            return a.isPlaying ? -1 : 1;
        });

        root.entries = nextEntries;

        if (root.debugLogs)
            console.log("[NowPlayingData] entries after sync:", root.entries.length, "playing:", root.playingCount);
    }

    Timer {
        interval: 900
        repeat: true
        running: true
        onTriggered: root.resync()
    }

    Component.onCompleted: root.resync()
}
