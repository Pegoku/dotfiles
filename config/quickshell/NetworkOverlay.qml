import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: GlobalStates.networkMenuOpen
            color: "transparent"

            WlrLayershell.namespace: "quickshell:networkmenu"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: GlobalStates.networkMenuOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

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
                focus: GlobalStates.networkMenuOpen

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        GlobalStates.networkMenuOpen = false;
                        event.accepted = true;
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: GlobalStates.networkMenuOpen = false
            }

            Rectangle {
                id: configPanel

                property bool networkingEnabled: true
                property bool wifiEnabled: true
                property var wifiNetworks: []
                property var scanBuffer: []

                function toggleNetworking() {
                    Quickshell.execDetached(["nmcli", "networking", networkingEnabled ? "off" : "on"]);
                }

                function toggleWifi() {
                    Quickshell.execDetached(["nmcli", "radio", "wifi", wifiEnabled ? "off" : "on"]);
                }

                function connectToWifi(ssid) {
                    if (!networkingEnabled || !wifiEnabled)
                        return;
                    if (!ssid || ssid.length === 0)
                        return;

                    Quickshell.execDetached(["nmcli", "dev", "wifi", "connect", ssid]);
                }

                function openNmtui() {
                    Quickshell.execDetached([
                        "bash",
                        "-lc",
                        "term=''; " +
                        "for t in kitty alacritty foot wezterm gnome-terminal konsole xterm; do " +
                        "command -v \"$t\" >/dev/null 2>&1 && { term=\"$t\"; break; }; " +
                        "done; " +
                        "case \"$term\" in " +
                        "kitty) exec kitty -e nmtui ;; " +
                        "alacritty) exec alacritty -e nmtui ;; " +
                        "foot) exec foot -e nmtui ;; " +
                        "wezterm) exec wezterm start -- nmtui ;; " +
                        "gnome-terminal) exec gnome-terminal -- nmtui ;; " +
                        "konsole) exec konsole -e nmtui ;; " +
                        "xterm) exec xterm -e nmtui ;; " +
                        "*) command -v notify-send >/dev/null 2>&1 && notify-send 'Network widget' 'No supported terminal found for nmtui' ;; " +
                        "esac"
                    ]);
                }

                z: 100
                width: 290
                height: panelColumn.implicitHeight + 14
                radius: 10
                color: "#1f1f1f"
                border.width: 1
                border.color: "#3d3d3d"
                anchors.top: parent.top
                anchors.topMargin: 46
                anchors.right: parent.right
                anchors.rightMargin: 10

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    onClicked: mouse => mouse.accepted = true
                }

                Process {
                    id: statusProc

                    command: [
                        "bash",
                        "-lc",
                        "while true; do " +
                        "net_state=$(nmcli networking 2>/dev/null | tr '[:upper:]' '[:lower:]'); " +
                        "wifi_radio=$(nmcli radio wifi 2>/dev/null | tr '[:upper:]' '[:lower:]'); " +
                        "if [ -z \"$net_state\" ]; then net_state=disabled; fi; " +
                        "if [ -z \"$wifi_radio\" ]; then wifi_radio=disabled; fi; " +
                        "echo \"FLAGS|$net_state|$wifi_radio\"; " +
                        "sleep 2; " +
                        "done"
                    ]
                    running: GlobalStates.networkMenuOpen

                    stdout: SplitParser {
                        onRead: data => {
                            var line = data.trim();
                            if (!line.startsWith("FLAGS|"))
                                return;

                            var parts = line.split("|");
                            if (parts.length < 3)
                                return;

                            configPanel.networkingEnabled = parts[1] === "enabled";
                            configPanel.wifiEnabled = parts[2] === "enabled";
                        }
                    }
                }

                Process {
                    id: wifiScanProc

                    command: [
                        "bash",
                        "-lc",
                        "while true; do " +
                        "echo 'SCAN_BEGIN'; " +
                        "nmcli -t -f ACTIVE,SIGNAL,SSID dev wifi list --rescan yes 2>/dev/null | " +
                        "awk -F':' '{active=$1; signal=$2; sub(\"^[^:]*:[^:]*:\", \"\", $0); ssid=$0; if (ssid==\"\") ssid=\"Hidden network\"; if (signal==\"\") signal=0; if (!(ssid in best) || signal+0 > best[ssid]) {best[ssid]=signal+0; activeMap[ssid]=(active==\"yes\" ? \"yes\" : activeMap[ssid])} if (active==\"yes\") activeMap[ssid]=\"yes\"} END {for (s in best) print \"AP|\" activeMap[s] \"|\" best[s] \"|\" s}' | sort -t'|' -k2,2r -k3,3nr; " +
                        "echo 'SCAN_END'; " +
                        "sleep 8; " +
                        "done"
                    ]
                    running: GlobalStates.networkMenuOpen

                    stdout: SplitParser {
                        onRead: data => {
                            var line = data.trim();
                            if (!line)
                                return;

                            if (line === "SCAN_BEGIN") {
                                configPanel.scanBuffer = [];
                                return;
                            }

                            if (line === "SCAN_END") {
                                configPanel.wifiNetworks = configPanel.scanBuffer;
                                return;
                            }

                            if (!line.startsWith("AP|"))
                                return;

                            var parts = line.split("|");
                            if (parts.length < 4)
                                return;

                            var ssid = parts.slice(3).join("|");
                            configPanel.scanBuffer.push({
                                active: parts[1] === "yes",
                                signal: Number(parts[2]),
                                ssid: ssid
                            });
                        }
                    }
                }

                Column {
                    id: panelColumn

                    width: parent.width - 14
                    spacing: 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 7

                    Row {
                        width: parent.width
                        spacing: 8

                        Rectangle {
                            width: (parent.width - 8) / 2
                            height: 26
                            radius: 6
                            color: configPanel.networkingEnabled ? "#2d5a35" : "#553232"

                            Text {
                                anchors.centerIn: parent
                                text: configPanel.networkingEnabled ? "Networking: on" : "Networking: off"
                                color: "#f2f2f2"
                                font.pixelSize: 11
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: configPanel.toggleNetworking()
                            }
                        }

                        Rectangle {
                            width: (parent.width - 8) / 2
                            height: 26
                            radius: 6
                            color: configPanel.wifiEnabled ? "#2d5a35" : "#553232"

                            Text {
                                anchors.centerIn: parent
                                text: configPanel.wifiEnabled ? "Wi-Fi: on" : "Wi-Fi: off"
                                color: "#f2f2f2"
                                font.pixelSize: 11
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: configPanel.toggleWifi()
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#3a3a3a"
                    }

                    Text {
                        text: "Wi-Fi networks"
                        color: "#d7d7d7"
                        font.pixelSize: 12
                        font.bold: true
                    }

                    Flickable {
                        width: parent.width
                        height: 160
                        clip: true
                        contentWidth: width
                        contentHeight: listColumn.implicitHeight

                        Column {
                            id: listColumn

                            width: parent.width
                            spacing: 4

                            Repeater {
                                model: configPanel.wifiNetworks

                                delegate: Rectangle {
                                    required property var modelData

                                    width: listColumn.width
                                    height: 28
                                    radius: 6
                                    color: modelData.active ? "#2f4b66" : "#2a2a2a"
                                    opacity: configPanel.networkingEnabled && configPanel.wifiEnabled ? 1.0 : 0.55

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 56
                                        elide: Text.ElideRight
                                        text: (modelData.active ? "* " : "") + modelData.ssid
                                        color: "#f2f2f2"
                                        font.pixelSize: 11
                                    }

                                    Text {
                                        anchors.right: parent.right
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: Math.max(0, Math.min(100, Number(modelData.signal))) + "%"
                                        color: "#bfbfbf"
                                        font.pixelSize: 10
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: configPanel.networkingEnabled && configPanel.wifiEnabled
                                        onClicked: configPanel.connectToWifi(modelData.ssid)
                                    }
                                }
                            }

                            Text {
                                visible: configPanel.wifiNetworks.length === 0
                                text: "No networks found"
                                color: "#9a9a9a"
                                font.pixelSize: 11
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 28
                        radius: 6
                        color: "#2d2d2d"

                        Text {
                            anchors.centerIn: parent
                            text: "Open nmtui"
                            color: "#f2f2f2"
                            font.pixelSize: 11
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: configPanel.openNmtui()
                        }
                    }
                }
            }
        }
    }
}
