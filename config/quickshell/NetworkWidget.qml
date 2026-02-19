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
    property color fgColor: "#f2f2f2"
    property color bgColor: "#1c1c1c"
    property string iconBase: "file:///usr/share/icons/Adwaita/symbolic/status/"

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

    anchors.verticalCenter: parent.verticalCenter
    radius: 12
    color: bgColor
    opacity: 0.85
    layer.enabled: true
    width: contentRow.implicitWidth + padding * 2
    height: contentRow.implicitHeight + padding * 2

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

    Row {
        id: contentRow

        anchors.centerIn: parent
        spacing: 6

        Image {
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
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onClicked: GlobalStates.networkMenuOpen = !GlobalStates.networkMenuOpen
    }
}
