import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Qt5Compat.GraphicalEffects

Scope {
    id: root
    property string username: "User"

    IpcHandler {
        target: "powermenu"

        function toggle(): void {
            GlobalStates.powerMenuOpen = !GlobalStates.powerMenuOpen;
        }
        function open(): void {
            GlobalStates.powerMenuOpen = true;
        }
        function close(): void {
            GlobalStates.powerMenuOpen = false;
        }
    }

    Process {
        id: whoamiProcess
        command: ["whoami"]
        running: true

        property string outputBuffer: ""

        stdout: SplitParser {
            onRead: data => {
                whoamiProcess.outputBuffer += data;
            }
        }

        onExited: {
            const name = outputBuffer.trim();
            if (name.length > 0) {
                root.username = name;
            }
            outputBuffer = "";
        }
    }

    PanelWindow {
        id: panelWindow
        visible: GlobalStates.powerMenuOpen

        WlrLayershell.namespace: "quickshell:powermenu"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: GlobalStates.powerMenuOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "transparent"

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: GlobalStates.powerMenuOpen ? 0.6 : 0

            Behavior on opacity {
                NumberAnimation { duration: 200 }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    GlobalStates.powerMenuOpen = false
                }
            }
        }

        FocusScope {
            id: keyHandler
            anchors.fill: parent
            focus: GlobalStates.powerMenuOpen

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    GlobalStates.powerMenuOpen = false;
                    event.accepted = true;
                }
            }
        }

        Rectangle {
            id: menuCard
            anchors.centerIn: parent
            radius: 16
            color: "#1e1e1e"
            border.color: "#3a3a3a"
            border.width: 2
            width: 520
            height: 300

            Column {
                anchors.centerIn: parent
                spacing: 20

                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    Rectangle {
                        width: 72
                        height: 72
                        radius: 36
                        color: "transparent"
                        border.color: "#cfcfcf"
                        border.width: 2
                        anchors.horizontalCenter: parent.horizontalCenter

                        ColoredIcon {
                            anchors.centerIn: parent
                            source: "file:///usr/share/icons/Adwaita/symbolic/status/avatar-default-symbolic.svg"
                            size: 36
                            color: "#dcdcdc"
                        }
                    }

                    Text {
                        text: root.username
                        color: "#e6e6e6"
                        font.pixelSize: 14
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                Row {
                    spacing: 24
                    anchors.horizontalCenter: parent.horizontalCenter

                    PowerIconButton { label: "Sleep"; iconPath: "file:///usr/share/icons/Adwaita/symbolic/status/weather-clear-night-symbolic.svg"; command: "systemctl suspend || loginctl suspend" }
                    PowerIconButton { label: "Hibernate"; iconPath: "file:///usr/share/icons/Adwaita/symbolic/status/weather-snow-symbolic.svg"; command: "systemctl hibernate || loginctl hibernate" }
                    PowerIconButton { label: "Restart"; iconPath: "file:///usr/share/icons/Adwaita/symbolic/actions/system-reboot-symbolic.svg"; command: "systemctl reboot || loginctl reboot" }
                    PowerIconButton { label: "Shut Down"; iconPath: "file:///usr/share/icons/Adwaita/symbolic/actions/system-shutdown-symbolic.svg"; command: "systemctl poweroff || loginctl poweroff" }
                    PowerIconButton { label: "Log Out"; iconPath: "file:///usr/share/icons/Adwaita/symbolic/actions/system-log-out-symbolic.svg"; command: "hyprctl dispatch exit || loginctl terminate-user $USER" }
                }
            }
        }
    }

    component PowerIconButton: Rectangle {
        id: button
        required property string label
        required property string command
        required property string iconPath

        width: 78
        height: 96
        radius: 10
        color: "transparent"

        Column {
            anchors.centerIn: parent
            spacing: 8

            Rectangle {
                width: 48
                height: 48
                radius: 24
                color: button.containsMouse ? "#3a3a3a" : "transparent"
                border.color: button.containsMouse ? "#cfcfcf" : "#6a6a6a"
                border.width: 1

                ColoredIcon {
                    anchors.centerIn: parent
                    source: button.iconPath
                    size: 24
                    color: button.containsMouse ? "#ffffff" : "#d0d0d0"
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: button.label
                color: "#dcdcdc"
                font.pixelSize: 11
            }
        }

        property bool containsMouse: false
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: button.containsMouse = true
            onExited: button.containsMouse = false
            onClicked: {
                Quickshell.execDetached(["bash", "-c", button.command])
                GlobalStates.powerMenuOpen = false
            }
        }
    }

    component ColoredIcon: Item {
        id: iconRoot
        required property string source
        required property int size
        required property color color

        width: size
        height: size

        Image {
            id: iconImage
            anchors.fill: parent
            source: iconRoot.source
            smooth: true
            visible: false
        }

        ColorOverlay {
            anchors.fill: iconImage
            source: iconImage
            color: iconRoot.color
        }
    }
}
