import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    property bool transientOpen: false

    IpcHandler {
        target: "nowplaying"

        function pulse(): void {
            root.transientOpen = true;
            transientTimeout.restart();
        }
    }

    Timer {
        id: transientTimeout
        interval: 2500
        repeat: false
        running: false
        onTriggered: root.transientOpen = false
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: GlobalStates.nowPlayingOpen || root.transientOpen
            color: "transparent"

            WlrLayershell.namespace: "quickshell:nowplaying"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: GlobalStates.nowPlayingOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0

            FocusScope {
                anchors.fill: parent
                focus: GlobalStates.nowPlayingOpen

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        GlobalStates.nowPlayingOpen = false;
                        event.accepted = true;
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: GlobalStates.nowPlayingOpen = false
            }

            Rectangle {
                id: overlayCard

                property string actionIconBase: "file:///usr/share/icons/Adwaita/symbolic/actions/"

                z: 100
                width: 420
                height: Math.min(380, columnContent.implicitHeight + 14)
                radius: 12
                color: "#1f1f1f"
                border.width: 1
                border.color: "#3d3d3d"
                anchors.top: parent.top
                anchors.topMargin: 46
                anchors.left: parent.left
                anchors.leftMargin: Math.max(8, Math.min(parent.width - overlayCard.width - 8, GlobalStates.nowPlayingAnchorX - overlayCard.width / 2))

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    onClicked: mouse => mouse.accepted = true
                }

                Column {
                    id: columnContent

                    width: parent.width - 14
                    spacing: 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 7

                    Text {
                        text: "Now Playing"
                        color: "#e8e8e8"
                        font.pixelSize: 13
                        font.bold: true
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#3a3a3a"
                    }

                    Flickable {
                        width: parent.width
                        height: 320
                        clip: true
                        contentWidth: width
                        contentHeight: tracksColumn.implicitHeight

                        Column {
                            id: tracksColumn

                            width: parent.width
                            spacing: 6

                            Repeater {
                                model: NowPlayingData.entries

                                delegate: Rectangle {
                                    required property var modelData

                                    width: tracksColumn.width
                                    height: 98
                                    radius: 8
                                    color: "#263152"

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 10

                                        Rectangle {
                                            width: 60
                                            height: 60
                                            radius: 8
                                            color: "#2c2c2c"
                                            clip: true

                                            Image {
                                                id: coverImage

                                                anchors.fill: parent
                                                source: modelData.artUrl && modelData.artUrl.length > 0 ? modelData.artUrl : modelData.fallbackArtUrl
                                                fillMode: Image.PreserveAspectCrop
                                                smooth: true
                                                asynchronous: true
                                                visible: source.toString().length > 0

                                                onStatusChanged: {
                                                    if (status !== Image.Error)
                                                        return;
                                                    if (!modelData.fallbackArtUrl || modelData.fallbackArtUrl.length === 0)
                                                        return;
                                                    if (source === modelData.fallbackArtUrl)
                                                        return;
                                                    source = modelData.fallbackArtUrl;
                                                }
                                            }

                                            Image {
                                                anchors.centerIn: parent
                                                width: 18
                                                height: 18
                                                source: overlayCard.actionIconBase + "media-playback-start-symbolic.svg"
                                                smooth: true
                                                visible: coverImage.status === Image.Error || coverImage.status === Image.Null || coverImage.source.toString().length === 0
                                                layer.enabled: true

                                                layer.effect: ColorOverlay {
                                                    color: "#f2f2f2"
                                                }
                                            }
                                        }

                                        Column {
                                            width: parent.width - 60 - 10
                                            spacing: 3

                                            Text {
                                                width: parent.width
                                                elide: Text.ElideRight
                                                text: modelData.title
                                                color: "#f2f2f2"
                                                font.pixelSize: 12
                                                font.bold: true
                                            }

                                            Text {
                                                width: parent.width
                                                elide: Text.ElideRight
                                                text: modelData.artist
                                                color: "#cfcfcf"
                                                font.pixelSize: 11
                                            }

                                            Row {
                                                spacing: 8

                                                Text {
                                                    text: modelData.position && modelData.position.length > 0 ? modelData.position : "--:--"
                                                    color: "#b5b5b5"
                                                    font.pixelSize: 10
                                                }

                                                Text {
                                                    text: "/"
                                                    color: "#8a8a8a"
                                                    font.pixelSize: 10
                                                }

                                                Text {
                                                    text: modelData.length && modelData.length.length > 0 ? modelData.length : "--:--"
                                                    color: "#b5b5b5"
                                                    font.pixelSize: 10
                                                }

                                                Text {
                                                    text: modelData.player
                                                    color: "#8a8a8a"
                                                    font.pixelSize: 10
                                                    elide: Text.ElideRight
                                                    width: 96
                                                }

                                                Text {
                                                    text: modelData.state
                                                    color: modelData.isPlaying ? "#9fd7a1" : "#d6c88f"
                                                    font.pixelSize: 10
                                                }
                                            }

                                            Row {
                                                spacing: 6

                                                Rectangle {
                                                    width: 24
                                                    height: 20
                                                    radius: 5
                                                    color: modelData.canPrevious ? "#38446a" : "#2b2f3b"
                                                    opacity: modelData.canPrevious ? 1 : 0.55

                                                    Image {
                                                        anchors.centerIn: parent
                                                        width: 13
                                                        height: 13
                                                        source: overlayCard.actionIconBase + "media-skip-backward-symbolic.svg"
                                                        smooth: true
                                                        layer.enabled: true

                                                        layer.effect: ColorOverlay {
                                                            color: "#f2f2f2"
                                                        }
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        enabled: modelData.canPrevious
                                                        onClicked: modelData.playerRef.previous()
                                                    }
                                                }

                                                Rectangle {
                                                    width: 34
                                                    height: 20
                                                    radius: 5
                                                    color: modelData.canToggle ? "#4867a7" : "#2b2f3b"
                                                    opacity: modelData.canToggle ? 1 : 0.55

                                                    Image {
                                                        anchors.centerIn: parent
                                                        width: 14
                                                        height: 14
                                                        source: overlayCard.actionIconBase + (modelData.isPlaying ? "media-playback-pause-symbolic.svg" : "media-playback-start-symbolic.svg")
                                                        smooth: true
                                                        layer.enabled: true

                                                        layer.effect: ColorOverlay {
                                                            color: "#f2f2f2"
                                                        }
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        enabled: modelData.canToggle
                                                        onClicked: modelData.playerRef.togglePlaying()
                                                    }
                                                }

                                                Rectangle {
                                                    width: 24
                                                    height: 20
                                                    radius: 5
                                                    color: modelData.canNext ? "#38446a" : "#2b2f3b"
                                                    opacity: modelData.canNext ? 1 : 0.55

                                                    Image {
                                                        anchors.centerIn: parent
                                                        width: 13
                                                        height: 13
                                                        source: overlayCard.actionIconBase + "media-skip-forward-symbolic.svg"
                                                        smooth: true
                                                        layer.enabled: true

                                                        layer.effect: ColorOverlay {
                                                            color: "#f2f2f2"
                                                        }
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        enabled: modelData.canNext
                                                        onClicked: modelData.playerRef.next()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                visible: NowPlayingData.entries.length === 0
                                width: tracksColumn.width
                                height: 48
                                radius: 8
                                color: "#2a2a2a"

                                Text {
                                    anchors.centerIn: parent
                                    text: "Nothing is currently playing"
                                    color: "#bfbfbf"
                                    font.pixelSize: 11
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
