import QtQuick
import Quickshell
import Quickshell.Hyprland

Rectangle {
    id: containerRect

    // The screen this bar instance belongs to. Each monitor owns a block of ten
    // workspaces (see hypr/hyprland/workspaces.lua), so the bar shows that
    // monitor's block and stays put while other monitors change workspace.
    required property var screen

    property int wheelAccum: 0
    readonly property int buttonWidth: 24
    readonly property int buttonHeight: 20
    readonly property int buttonSpacing: 0
    readonly property int workspacesPerMonitor: 10
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property int activeWorkspaceId: Math.max(1, monitor?.activeWorkspace?.id ?? 1)
    // Normally the monitor's own block. Workspaces past the last block are not
    // bound to any monitor, so a bar showing one of those follows it instead.
    readonly property int groupStart: Math.floor((activeWorkspaceId - 1) / workspacesPerMonitor) * workspacesPerMonitor + 1
    readonly property int groupEnd: groupStart + workspacesPerMonitor - 1

    function workspaceById(id) {
        return Hyprland.workspaces.values.find((item) => item.id === id) ?? null;
    }

    function workspaceHasWindows(id) {
        var ws = workspaceById(id);
        return ws && ws.toplevels && ws.toplevels.values.length > 0;
    }

    // Active on this monitor, not globally: each bar highlights its own monitor.
    function workspaceIsActive(id) {
        return id === activeWorkspaceId;
    }

    function focusWorkspace(id) {
        Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + id + "\" })");
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
            model: containerRect.workspacesPerMonitor - 1

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
            model: containerRect.workspacesPerMonitor

            delegate: WorkspaceButton {
                required property int index

                number: containerRect.groupStart + index
                width: containerRect.buttonWidth
                height: containerRect.buttonHeight
                active: containerRect.workspaceIsActive(number)
                occupied: containerRect.workspaceHasWindows(number)

                onPressed: id => {
                    containerRect.focusWorkspace(id);
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

        onWheel: wheel => {
            containerRect.wheelAccum += wheel.angleDelta.y;
            wheelResetTimer.restart();

            var threshold = 120;
            var active = containerRect.activeWorkspaceId;

            if (containerRect.wheelAccum >= threshold && active > containerRect.groupStart) {
                containerRect.focusWorkspace(active - 1);
                containerRect.wheelAccum = 0;
            } else if (containerRect.wheelAccum <= -threshold && active < containerRect.groupEnd) {
                containerRect.focusWorkspace(active + 1);
                containerRect.wheelAccum = 0;
            }
        }
    }
}
