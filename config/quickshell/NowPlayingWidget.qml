import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell

Rectangle {
    id: containerRect

    property int padding: 6
    property color fgColor: "#f2f2f2"
    property color bgColor: "#1c1c1c"
    property string iconBase: "file:///usr/share/icons/Adwaita/symbolic/status/"
    property string actionIconBase: "file:///usr/share/icons/Adwaita/symbolic/actions/"

    function updateAnchorX() {
        GlobalStates.nowPlayingAnchorX = containerRect.x + containerRect.width / 2;
    }

    function currentArtUrl() {
        if (!NowPlayingData.primary)
            return "";
        if (NowPlayingData.primary.artUrl && NowPlayingData.primary.artUrl.length > 0)
            return NowPlayingData.primary.artUrl;
        if (NowPlayingData.primary.fallbackArtUrl && NowPlayingData.primary.fallbackArtUrl.length > 0)
            return NowPlayingData.primary.fallbackArtUrl;
        return "";
    }

    anchors.verticalCenter: parent.verticalCenter
    radius: 12
    color: bgColor
    opacity: 0.85
    layer.enabled: true
    width: contentRow.implicitWidth + padding * 2
    height: contentRow.implicitHeight + padding * 2

    Row {
        id: contentRow

        anchors.centerIn: parent
        spacing: 6

        Rectangle {
            width: 18
            height: 18
            radius: 4
            color: "#2c2c2c"
            clip: true

            Image {
                id: primaryCover

                anchors.fill: parent
                source: containerRect.currentArtUrl()
                fillMode: Image.PreserveAspectCrop
                smooth: true
                asynchronous: true
                visible: source.toString().length > 0

                onStatusChanged: {
                    if (status !== Image.Error || !NowPlayingData.primary)
                        return;
                    if (source === NowPlayingData.primary.fallbackArtUrl)
                        return;
                    if (NowPlayingData.primary.fallbackArtUrl && NowPlayingData.primary.fallbackArtUrl.length > 0)
                        source = NowPlayingData.primary.fallbackArtUrl;
                }
            }

                Image {
                    anchors.centerIn: parent
                    width: 12
                    height: 12
                    source: containerRect.actionIconBase + "media-playback-start-symbolic.svg"
                    smooth: true
                    visible: !NowPlayingData.primary || primaryCover.status === Image.Error || primaryCover.status === Image.Null || primaryCover.source.toString().length === 0
                    layer.enabled: true

                layer.effect: ColorOverlay {
                    color: containerRect.fgColor
                }
            }
        }

        Text {
            width: 180
            elide: Text.ElideRight
            color: containerRect.fgColor
            font.pixelSize: 11
            font.bold: true
            text: {
                if (NowPlayingData.playerCount === 0)
                    return "No media";
                if (NowPlayingData.playingCount === 0)
                    return "Media paused (" + NowPlayingData.playerCount + ")";

                var label = NowPlayingData.primaryTitle;
                if (NowPlayingData.playingCount > 1)
                    label += " +" + (NowPlayingData.playingCount - 1);

                return label;
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onClicked: {
            containerRect.updateAnchorX();
            GlobalStates.nowPlayingOpen = !GlobalStates.nowPlayingOpen;
        }
    }

    onXChanged: containerRect.updateAnchorX()
    onWidthChanged: containerRect.updateAnchorX()
    Component.onCompleted: containerRect.updateAnchorX()
}
