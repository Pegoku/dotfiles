import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

Rectangle {
    id: containerRect

    property int padding: 6
    property string state: "offline"
    property real strength: 0
    property string networkName: "Disconnected"
    property bool networkingEnabled: true
    property bool wifiEnabled: true
    property bool menuOpen: false
    property var wifiNetworks: []
    property var scanBuffer: []
    property color fgColor: "#f2f2f2"
    property color bgColor: "#1c1c1c"
    property string iconBase: "file:///usr/share/icons/Adwaita/symbolic/status/"

    property string tooltipText: {
        if (!networkingEnabled)
            return "Networking is disabled";
        if (state === "wifi")
            return "Wi-Fi - " + Math.round(strength) + "% - " + networkName;
        if (state === "wired")
            return "Wired - " + networkName;

        return wifiEnabled ? "No network" : "Wi-Fi is disabled";
    }

    property string sideLabel: {
        if (!networkingEnabled)
            return "Network off";
        if (state === "wifi" || state === "wired")
            return networkName;

        return wifiEnabled ? "No network" : "Wi-Fi off";
    }

    function networkIconName() {
        if (!networkingEnabled)
            return "network-offline-symbolic";
        if (!wifiEnabled && state !== "wired")
            return "network-wireless-offline-symbolic";
        if (state === "wired")
            return "network-wired-symbolic";
        if (state !== "wifi")
            return "network-wireless-offline-symbolic";

        if (strength < 15)
            return "network-wireless-signal-none-symbolic";
        if (strength < 35)
            return "network-wireless-signal-weak-symbolic";
        if (strength < 60)
            return "network-wireless-signal-ok-symbolic";
        if (strength < 80)
            return "network-wireless-signal-good-symbolic";

        return "network-wireless-signal-excellent-symbolic";
    }

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

    anchors.verticalCenter: parent.verticalCenter
    radius: 12
    color: bgColor
    opacity: 0.85
    layer.enabled: !menuOpen
    width: contentRow.implicitWidth + padding * 2
    height: contentRow.implicitHeight + padding * 2

    ToolTip.visible: false

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
            "active=$(nmcli -t -f ACTIVE dev wifi list --rescan no 2>/dev/null | awk '$1==\"yes\"{print \"yes\"; exit}'); " +
            "ssid=$(nmcli -t -f ACTIVE,SSID dev wifi list --rescan no 2>/dev/null | awk -F':' '$1==\"yes\"{sub($1\":\",\"\"); print; exit}'); " +
            "sig=$(nmcli -t -f ACTIVE,SIGNAL dev wifi list --rescan no 2>/dev/null | awk -F':' '$1==\"yes\"{print $2; exit}'); " +
            "if [ \"$net_state\" = \"enabled\" ] && [ \"$active\" = \"yes\" ]; then " +
            "if [ -z \"$ssid\" ]; then ssid='Hidden network'; fi; " +
            "if [ -z \"$sig\" ]; then sig=0; fi; " +
            "echo \"NET WIFI|$sig|$ssid\"; " +
            "elif [ \"$net_state\" = \"enabled\" ]; then " +
            "wired=$(nmcli -t -f TYPE,STATE,CONNECTION device status 2>/dev/null | awk -F':' '$1==\"ethernet\" && $2 ~ /^connected/{sub($1\":\"$2\":\",\"\"); print; exit}'); " +
            "if [ -n \"$wired\" ]; then " +
            "echo \"NET WIRED|100|$wired\"; " +
            "else " +
            "echo 'NET OFF|0|Disconnected'; " +
            "fi; " +
            "else " +
            "echo 'NET OFF|0|Networking disabled'; " +
            "fi; " +
            "sleep 2; " +
            "done"
        ]
        running: true

        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (!line)
                    return;

                if (line.startsWith("FLAGS|")) {
                    var flagParts = line.split("|");
                    if (flagParts.length >= 3) {
                        containerRect.networkingEnabled = flagParts[1] === "enabled";
                        containerRect.wifiEnabled = flagParts[2] === "enabled";
                    }
                    return;
                }

                if (!line.startsWith("NET "))
                    return;

                var payload = line.substring(4);
                var parts = payload.split("|");
                if (parts.length < 3)
                    return;

                var mode = parts[0];
                var signalValue = Number(parts[1]);
                var name = parts.slice(2).join("|");

                if (mode === "WIFI") {
                    containerRect.state = "wifi";
                    containerRect.strength = isNaN(signalValue) ? 0 : Math.max(0, Math.min(100, signalValue));
                    containerRect.networkName = name && name.length > 0 ? name : "Hidden network";
                    return;
                }

                if (mode === "WIRED") {
                    containerRect.state = "wired";
                    containerRect.strength = 100;
                    containerRect.networkName = name && name.length > 0 ? name : "Wired";
                    return;
                }

                containerRect.state = "offline";
                containerRect.strength = 0;
                containerRect.networkName = "Disconnected";
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
        running: containerRect.menuOpen

        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (!line)
                    return;

                if (line === "SCAN_BEGIN") {
                    containerRect.scanBuffer = [];
                    return;
                }

                if (line === "SCAN_END") {
                    containerRect.wifiNetworks = containerRect.scanBuffer;
                    return;
                }

                if (!line.startsWith("AP|"))
                    return;

                var parts = line.split("|");
                if (parts.length < 4)
                    return;

                var ssid = parts.slice(3).join("|");
                containerRect.scanBuffer.push({
                    active: parts[1] === "yes",
                    signal: Number(parts[2]),
                    ssid: ssid
                });
            }
        }
    }

    Row {
        id: contentRow

        anchors.centerIn: parent
        spacing: 6

        Image {
            id: networkIcon

            width: 18
            height: 18
            source: containerRect.iconBase + containerRect.networkIconName() + ".svg"
            smooth: true
            layer.enabled: true

            layer.effect: ColorOverlay {
                color: containerRect.fgColor
            }
        }

        Text {
            width: 120
            elide: Text.ElideRight
            text: containerRect.sideLabel
            color: containerRect.fgColor
            font.pixelSize: 11
            font.bold: true
            verticalAlignment: Text.AlignVCenter
        }
    }

    MouseArea {
        id: hoverArea

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton

        onClicked: {
            containerRect.menuOpen = !containerRect.menuOpen;
        }
    }

    Rectangle {
        id: configPanel

        visible: containerRect.menuOpen
        z: 100
        width: 290
        height: panelColumn.implicitHeight + 14
        radius: 10
        color: "#1f1f1f"
        border.width: 1
        border.color: "#3d3d3d"
        anchors.top: containerRect.bottom
        anchors.topMargin: 6
        anchors.right: containerRect.right

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
                    color: containerRect.networkingEnabled ? "#2d5a35" : "#553232"

                    Text {
                        anchors.centerIn: parent
                        text: containerRect.networkingEnabled ? "Networking: on" : "Networking: off"
                        color: "#f2f2f2"
                        font.pixelSize: 11
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: containerRect.toggleNetworking()
                    }
                }

                Rectangle {
                    width: (parent.width - 8) / 2
                    height: 26
                    radius: 6
                    color: containerRect.wifiEnabled ? "#2d5a35" : "#553232"

                    Text {
                        anchors.centerIn: parent
                        text: containerRect.wifiEnabled ? "Wi-Fi: on" : "Wi-Fi: off"
                        color: "#f2f2f2"
                        font.pixelSize: 11
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: containerRect.toggleWifi()
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
                        model: containerRect.wifiNetworks

                        delegate: Rectangle {
                            required property var modelData

                            width: listColumn.width
                            height: 28
                            radius: 6
                            color: modelData.active ? "#2f4b66" : "#2a2a2a"
                            opacity: containerRect.networkingEnabled && containerRect.wifiEnabled ? 1.0 : 0.55

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
                                enabled: containerRect.networkingEnabled && containerRect.wifiEnabled
                                onClicked: containerRect.connectToWifi(modelData.ssid)
                            }
                        }
                    }

                    Text {
                        visible: containerRect.wifiNetworks.length === 0
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
                    onClicked: containerRect.openNmtui()
                }
            }
        }
    }
}
