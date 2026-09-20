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

    // Workspace a window is being dragged onto in the overview, shared so the
    // monitor the drag started on stops highlighting once it leaves. Workspace
    // ids are unique across monitors, so one value covers every overview.
    property int overviewDragTargetWorkspace: -1

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
