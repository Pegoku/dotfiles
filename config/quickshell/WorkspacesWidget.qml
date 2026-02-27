import QtQuick
import Quickshell
import Quickshell.Hyprland

Rectangle {
    id: containerRect

    property int wheelAccum: 0
    readonly property int buttonWidth: 24
    readonly property int buttonHeight: 20
    readonly property int buttonSpacing: 0
    readonly property int focusedWorkspaceId: Math.max(1, Hyprland.focusedWorkspace?.id ?? 1)
    readonly property int groupStart: Math.floor((focusedWorkspaceId - 1) / 10) * 10 + 1
    readonly property int groupEnd: groupStart + 9

    function workspaceById(id) {
        return Hyprland.workspaces.values.find((item) => item.id === id) ?? null;
    }

    function workspaceHasWindows(id) {
        var ws = workspaceById(id);
        return ws && ws.toplevels && ws.toplevels.values.length > 0;
    }

    function workspaceIsActive(id) {
        var ws = workspaceById(id);
        return ws && ws.active;
    }

    function shouldConnect(leftId, rightId) {
        return workspaceHasWindows(leftId)
            && workspaceHasWindows(rightId)
            && !workspaceIsActive(leftId)
            && !workspaceIsActive(rightId);
    }

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    radius: 12
    color: "#1c1c1c"
    opacity: 0.85
    layer.enabled: true
    width: workspaceRow.implicitWidth + 12
    height: workspaceRow.implicitHeight + 12

    Item {
        id: connectorLayer

        anchors.centerIn: parent
        width: workspaceRow.implicitWidth
        height: workspaceRow.implicitHeight
        z: 1

        Repeater {
            model: 9

            delegate: Rectangle {
                required property int index

                readonly property int leftId: containerRect.groupStart + index
                readonly property int rightId: leftId + 1

                x: index * (containerRect.buttonWidth + containerRect.buttonSpacing) + containerRect.buttonWidth - 10
                y: 0
                width: containerRect.buttonSpacing + 20
                height: containerRect.buttonHeight
                radius: 0
                color: "#5a5a5a"
                visible: containerRect.shouldConnect(leftId, rightId)
            }
        }
    }

    Row {
        id: workspaceRow

        anchors.centerIn: parent
        spacing: containerRect.buttonSpacing
        z: 3

        Repeater {
            model: 10

            delegate: WorkspaceButton {
                required property int index

                number: containerRect.groupStart + index
                width: containerRect.buttonWidth
                height: containerRect.buttonHeight
                active: containerRect.workspaceIsActive(number)
                occupied: containerRect.workspaceHasWindows(number)

                onPressed: id => {
                    Hyprland.dispatch("workspace " + id);
                }
            }
        }
    }

    Timer {
        id: wheelResetTimer

        interval: 300
        repeat: false
        onTriggered: containerRect.wheelAccum = 0
    }

    MouseArea {
        anchors.centerIn: parent
        width: containerRect.width + 40
        height: 100
        acceptedButtons: Qt.NoButton

        onWheel: {
            containerRect.wheelAccum += wheel.angleDelta.y;
            wheelResetTimer.restart();

            var threshold = 120;
            var focused = containerRect.focusedWorkspaceId;

            if (containerRect.wheelAccum >= threshold && focused > 1) {
                Hyprland.dispatch("workspace " + (focused - 1));
                containerRect.wheelAccum = 0;
            } else if (containerRect.wheelAccum <= -threshold) {
                Hyprland.dispatch("workspace " + (focused + 1));
                containerRect.wheelAccum = 0;
            }
        }
    }
}
