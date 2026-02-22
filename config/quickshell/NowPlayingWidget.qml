import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell

Rectangle {
    id: containerRect

    property int padding: 6
    property color fgColor: "#f2f2f2"
    property color bgColor: "#1c1c1c"
    property string iconBase: "file:///usr/share/icons/Adwaita/symbolic/status/"

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

        Image {
            width: 16
            height: 16
            source: containerRect.iconBase + "media-playback-start-symbolic.svg"
            smooth: true
            layer.enabled: true

            layer.effect: ColorOverlay {
                color: containerRect.fgColor
            }
        }

        Text {
            width: 180
            elide: Text.ElideRight
            color: containerRect.fgColor
            font.pixelSize: 11
            font.bold: true
            text: {
                if (NowPlayingData.playingCount === 0)
                    return "No media playing";

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
        onClicked: GlobalStates.nowPlayingOpen = !GlobalStates.nowPlayingOpen
    }
}
