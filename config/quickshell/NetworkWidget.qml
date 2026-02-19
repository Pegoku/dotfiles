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
    property color fgColor: "#f2f2f2"
    property color bgColor: "#1c1c1c"
    property string iconBase: "file:///usr/share/icons/Adwaita/symbolic/status/"

    property string tooltipText: {
        if (state === "wifi")
            return "Wi-Fi · " + Math.round(strength) + "% · " + networkName;
        if (state === "wired")
            return "Wired · " + networkName;

        return "No network";
    }

    function networkIconName() {
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

    ToolTip.visible: hoverArea.containsMouse && containerRect.tooltipText.length > 0
    ToolTip.text: containerRect.tooltipText
    ToolTip.delay: 150
    ToolTip.timeout: 0

    Process {
        id: networkProc

        command: [
            "bash",
            "-lc",
            "while true; do " +
            "active=$(nmcli -t -f ACTIVE dev wifi list --rescan no 2>/dev/null | awk '$1==\"yes\"{print \"yes\"; exit}'); " +
            "ssid=$(nmcli -t -f ACTIVE,SSID dev wifi list --rescan no 2>/dev/null | awk -F':' '$1==\"yes\"{sub($1\":\",\"\"); print; exit}'); " +
            "sig=$(nmcli -t -f ACTIVE,SIGNAL dev wifi list --rescan no 2>/dev/null | awk -F':' '$1==\"yes\"{print $2; exit}'); " +
            "if [ \"$active\" = \"yes\" ]; then " +
            "if [ -z \"$ssid\" ]; then ssid='Hidden network'; fi; " +
            "if [ -z \"$sig\" ]; then sig=0; fi; " +
            "echo \"NET WIFI|$sig|$ssid\"; " +
            "else " +
            "wired=$(nmcli -t -f TYPE,STATE,CONNECTION device status 2>/dev/null | awk -F':' '$1==\"ethernet\" && $2 ~ /^connected/{sub($1\":\"$2\":\",\"\"); print; exit}'); " +
            "if [ -n \"$wired\" ]; then " +
            "echo \"NET WIRED|100|$wired\"; " +
            "else " +
            "echo 'NET OFF|0|Disconnected'; " +
            "fi; " +
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
        spacing: 0

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
    }

    MouseArea {
        id: hoverArea

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
}
