import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: GlobalStates.nowPlayingOpen
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
                anchors.leftMargin: 12

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
                                    height: 76
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
                                                anchors.fill: parent
                                                source: modelData.artUrl
                                                fillMode: Image.PreserveAspectCrop
                                                smooth: true
                                                visible: source && source.length > 0
                                            }

                                            Image {
                                                anchors.centerIn: parent
                                                width: 18
                                                height: 18
                                                source: "file:///usr/share/icons/Adwaita/symbolic/status/media-playback-start-symbolic.svg"
                                                smooth: true
                                                visible: !modelData.artUrl || modelData.artUrl.length === 0
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
                                                    width: 120
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
                                    text: NowPlayingData.playerctlAvailable ? "Nothing is currently playing" : "Install playerctl to enable media tracking"
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
