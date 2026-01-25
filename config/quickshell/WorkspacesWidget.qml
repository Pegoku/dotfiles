import QtQuick
import Quickshell
import Quickshell.Hyprland

Rectangle {
    id: containerRect

    property alias innerRow: workspaceRow
    property int wheelAccum: 0
    property int totalWorkspaces: 10

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    radius: 12
    width: workspaceRow.implicitWidth + workspaceRow.anchors.margins * 2
    color: "#1c1c1c"
    opacity: 0.85
    height: workspaceRow.implicitHeight + workspaceRow.anchors.margins * 2

    Row {
        id: workspaceRow

            layer.enabled: true
        anchors.fill: parent
        anchors.margins: 6
        spacing: 8

        Repeater {
            model: 10

            delegate: WorkspaceButton {
                required property int index

                number: index + 1
                workspace: Hyprland.workspaces.values.find((ws) => {
                    return ws.id === index + 1;
                }) ?? null
            }

        }

    }

    Timer {
        id: wheelResetTimer

        interval: 300
        repeat: false
        onTriggered: {
            containerRect.wheelAccum = 0;
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton // Disable clicks
        onWheel: {
            // angleDelta.y typical step is 120 per notch; accumulate and trigger on threshold
            containerRect.wheelAccum += wheel.angleDelta.y;
            wheelResetTimer.restart();
            var threshold = 120;
            var focused = Hyprland.focusedWorkspace.id;
            var total = containerRect.totalWorkspaces;
            if (containerRect.wheelAccum >= threshold && focused > 1) {
                Hyprland.dispatch("workspace " + (focused - 1));
                containerRect.wheelAccum = 0;
            } else if (containerRect.wheelAccum <= -threshold && focused < total) {
                Hyprland.dispatch("workspace " + (focused + 1));
                containerRect.wheelAccum = 0;
            }
        }
    }

}
