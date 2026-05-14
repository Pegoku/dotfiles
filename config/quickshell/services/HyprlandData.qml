pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

/**
 * Provides access to Hyprland window and workspace data via hyprctl
 */
Singleton {
    id: root
    property var windowList: []
    property var layoutWindowList: []
    property var addresses: []
    property var windowByAddress: ({})
    property var workspaces: []
    property var workspaceIds: []
    property var workspaceById: ({})
    property var monitors: []

    function updateWindowList() {
        getClients.running = true;
    }

    function updateMonitors() {
        getMonitors.running = true;
    }

    function updateWorkspaces() {
        getWorkspaces.running = true;
    }

    function updateAll() {
        updateWindowList();
        updateMonitors();
        updateWorkspaces();
    }

    function layoutSignatureFor(windows) {
        var parts = [];
        for (var i = 0; i < windows.length; ++i) {
            var win = windows[i];
            parts.push([
                win.address,
                win.workspace?.id ?? -1,
                win.monitor ?? -1,
                win.at ? win.at[0] : 0,
                win.at ? win.at[1] : 0,
                win.size ? win.size[0] : 0,
                win.size ? win.size[1] : 0,
                win.floating ? 1 : 0,
                win.mapped ? 1 : 0,
                win.hidden ? 1 : 0
            ].join(":"));
        }
        return parts.join("|");
    }

    Component.onCompleted: {
        updateAll();
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            updateAll()
        }
    }

    Process {
        id: getClients
        command: ["hyprctl", "clients", "-j"]
        
        property string outputBuffer: ""
        
        stdout: SplitParser {
            id: clientsCollector
            onRead: data => {
                getClients.outputBuffer += data;
            }
        }
        
        onExited: {
            if (outputBuffer.length > 0) {
                try {
                    var nextWindowList = JSON.parse(outputBuffer)
                    let tempWinByAddress = {};
                    for (var i = 0; i < nextWindowList.length; ++i) {
                        var win = nextWindowList[i];
                        tempWinByAddress[win.address] = win;
                    }
                    if (layoutSignatureFor(nextWindowList) !== layoutSignatureFor(root.layoutWindowList))
                        root.layoutWindowList = nextWindowList;
                    root.windowList = nextWindowList;
                    root.windowByAddress = tempWinByAddress;
                    root.addresses = nextWindowList.map(win => win.address);
                } catch (e) {
                    console.error("Error parsing clients:", e);
                }
            }
            outputBuffer = "";
        }
    }

    Process {
        id: getMonitors
        command: ["hyprctl", "monitors", "-j"]
        
        property string outputBuffer: ""
        
        stdout: SplitParser {
            id: monitorsCollector
            onRead: data => {
                getMonitors.outputBuffer += data;
            }
        }
        
        onExited: {
            if (outputBuffer.length > 0) {
                try {
                    root.monitors = JSON.parse(outputBuffer);
                } catch (e) {
                    console.error("Error parsing monitors:", e);
                }
            }
            outputBuffer = "";
        }
    }

    Process {
        id: getWorkspaces
        command: ["hyprctl", "workspaces", "-j"]
        
        property string outputBuffer: ""
        
        stdout: SplitParser {
            id: workspacesCollector
            onRead: data => {
                getWorkspaces.outputBuffer += data;
            }
        }
        
        onExited: {
            if (outputBuffer.length > 0) {
                try {
                    root.workspaces = JSON.parse(outputBuffer);
                    let tempWorkspaceById = {};
                    for (var i = 0; i < root.workspaces.length; ++i) {
                        var ws = root.workspaces[i];
                        tempWorkspaceById[ws.id] = ws;
                    }
                    root.workspaceById = tempWorkspaceById;
                    root.workspaceIds = root.workspaces.map(ws => ws.id);
                } catch (e) {
                    console.error("Error parsing workspaces:", e);
                }
            }
            outputBuffer = "";
        }
    }
}
