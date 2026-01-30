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
    
    GlobalShortcut {
        name: "overviewToggle"
        description: "Toggles overview on press"

        onPressed: {
            root.overviewOpen = !root.overviewOpen;
        }
    }
}
