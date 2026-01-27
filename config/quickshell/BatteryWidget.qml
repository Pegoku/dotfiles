import QtQuick
import Quickshell
import Quickshell.Services.UPower

Rectangle {
    id: containerRect

    property int padding: 6
    property real percentage: {
        var d = UPower.displayDevice;
        if (!d || !d.ready) return 0;
        return d.percentage;
    }
    property bool charging: {
        var d = UPower.displayDevice;
        if (!d || !d.ready) return false;
        return d.timeToFull > 0;
    }

    anchors.verticalCenter: parent.verticalCenter
    radius: 12
    color: "#1c1c1c"
    opacity: 0.85
    layer.enabled: true
    width: contentRow.implicitWidth + padding * 2
    height: contentRow.implicitHeight + padding * 2

    Row {
        id: contentRow

        anchors.centerIn: parent
        spacing: 6

        Text {
            id: battText
            text: Math.round(containerRect.percentage * 100)
            color: "white"
            font.pixelSize: 14
        }

        Item {
            id: ring
            width: 22
            height: 22

            property int stroke: 2
            property color trackColor: "#3a3a3a"
            property color fillColor: "white"

            Canvas {
                id: ringCanvas
                anchors.fill: parent

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    ctx.clearRect(0, 0, width, height);

                    var cx = width / 2;
                    var cy = height / 2;
                    var radius = Math.min(width, height) / 2 - ring.stroke;
                    var start = -Math.PI / 2;
                    var end = start + (Math.PI * 2 * containerRect.percentage);

                    ctx.lineWidth = ring.stroke;
                    ctx.lineCap = "round";
                    ctx.strokeStyle = ring.trackColor;
                    ctx.beginPath();
                    ctx.arc(cx, cy, radius, 0, Math.PI * 2);
                    ctx.stroke();

                    ctx.strokeStyle = ring.fillColor;
                    ctx.beginPath();
                    ctx.arc(cx, cy, radius, start, end);
                    ctx.stroke();
                }
            }

            // Image {
            //     id: battIcon
            //     anchors.centerIn: parent
            //     width: 12
            //     height: 12
            //     source: "image://theme/" + (containerRect.charging
            //         ? "battery-charging-symbolic"
            //         : "battery-symbolic")
            //     smooth: true
            // }

            Connections {
                target: containerRect
                function onPercentageChanged() { ringCanvas.requestPaint(); }
                function onChargingChanged() { ringCanvas.requestPaint(); }
            }
        }
    }

}
