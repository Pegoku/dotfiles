pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland

/**
 * Global application state management
 */
Singleton {
    id: root
    
    property bool overviewOpen: false
    property bool powerMenuOpen: false
    property bool networkMenuOpen: false
    property bool nowPlayingOpen: false
    property bool calendarOpen: false
    property bool aiChatOpen: false
    property bool keybindsHelpOpen: false
    property real nowPlayingAnchorX: 220
    property real calendarAnchorX: 640
    property bool overviewAnimationsSuspended: false
    readonly property int overviewAnimationSuspendMs: 350

    // Open overview instances by screen name, so a window drag started on one
    // monitor can find the workspace grid on another. Workspace ids are unique
    // across monitors, so a single drag target covers every overview.
    property var overviews: ({})
    property int overviewDragTargetWorkspace: -1

    function registerOverview(name, overview) {
        overviews[name] = overview;
    }

    function unregisterOverview(name) {
        delete overviews[name];
    }

    // Workspace under a point given in Hyprland layout coordinates, whichever
    // monitor it falls on. -1 when the point is not over a workspace.
    function overviewWorkspaceAt(layoutX, layoutY) {
        for (var name in overviews) {
            var overview = overviews[name];
            if (!overview)
                continue;

            var workspace = overview.workspaceAtLayoutPosition(layoutX, layoutY);
            if (workspace !== -1)
                return workspace;
        }
        return -1;
    }

    function suspendOverviewAnimations() {
        if (!overviewAnimationsSuspended)
            Quickshell.execDetached(["hyprctl", "keyword", "animations:enabled", "0"]);

        overviewAnimationsSuspended = true;
        overviewAnimationRestoreTimer.restart();
    }

    function setOverviewOpen(open) {
        if (overviewOpen === open)
            return;

        suspendOverviewAnimations();
        overviewOpen = open;
    }

    function toggleOverview() {
        suspendOverviewAnimations();
        overviewOpen = !overviewOpen;
    }

    function setKeybindsHelpOpen(open) {
        keybindsHelpOpen = open;
    }

    function toggleKeybindsHelp() {
        keybindsHelpOpen = !keybindsHelpOpen;
    }

    Timer {
        id: overviewAnimationRestoreTimer
        interval: root.overviewAnimationSuspendMs
        repeat: false

        onTriggered: {
            root.overviewAnimationsSuspended = false;
            Quickshell.execDetached(["hyprctl", "keyword", "animations:enabled", "1"]);
        }
    }
    
    GlobalShortcut {
        name: "overviewToggle"
        description: "Toggles overview on press"

        onPressed: {
            root.toggleOverview();
        }
    }
}
