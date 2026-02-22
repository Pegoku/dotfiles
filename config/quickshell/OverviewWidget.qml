pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "./services"

Item {
    id: root
    required property var screen
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property int workspacesShown: 9 // 3x3 grid
    readonly property int rows: 3
    readonly property int columns: 3
    readonly property real scale: 0.15

    property int draggingFromWorkspace: -1
    property int draggingTargetWorkspace: -1
    
    property real workspaceImplicitWidth: monitor.width * scale
    property real workspaceImplicitHeight: monitor.height * scale
    property real workspaceSpacing: 10
    property real padding: 20
    property int zCounter: 0
    property string appQuery: ""
    property var filteredApps: []
    property int selectedAppIndex: 0
    readonly property bool hasSearchQuery: appQuery.trim().length > 0
    readonly property int maxLauncherRows: 7
    readonly property int launcherRowHeight: 32
    readonly property int launcherRowSpacing: 2
    readonly property int launcherListPadding: 4
    readonly property int launcherViewportHeight: {
        var rows = Math.min(maxLauncherRows, filteredApps.length);
        if (rows <= 0)
            return 30 + launcherListPadding * 2;
        return rows * launcherRowHeight + Math.max(0, rows - 1) * launcherRowSpacing + launcherListPadding * 2;
    }

    function workspaceAtPosition(xPos, yPos) {
        const cellWidth = workspaceImplicitWidth + workspaceSpacing
        const cellHeight = workspaceImplicitHeight + workspaceSpacing
        const col = Math.floor(xPos / cellWidth)
        const row = Math.floor(yPos / cellHeight)
        if (col < 0 || col >= columns || row < 0 || row >= rows) return -1
        const withinX = xPos - col * cellWidth
        const withinY = yPos - row * cellHeight
        if (withinX < 0 || withinX > workspaceImplicitWidth) return -1
        if (withinY < 0 || withinY > workspaceImplicitHeight) return -1
        return row * columns + col + 1
    }

    function requestTopZ() {
        zCounter += 1
        return zCounter
    }

    function normalizeText(value) {
        if (value === undefined || value === null)
            return "";
        return String(value).toLowerCase();
    }

    function appKeywords(entry) {
        if (!entry || !entry.keywords)
            return "";
        return String(entry.keywords).toLowerCase();
    }

    function appMatches(entry, query) {
        if (!entry)
            return false;

        var haystack = [
            normalizeText(entry.name),
            normalizeText(entry.genericName),
            normalizeText(entry.comment),
            normalizeText(entry.id),
            appKeywords(entry)
        ].join(" ");

        return haystack.indexOf(query) !== -1;
    }

    function refreshFilteredApps() {
        var apps = DesktopEntries.applications?.values ?? [];
        var query = normalizeText(appQuery.trim());

        if (query.length === 0) {
            filteredApps = [];
            selectedAppIndex = 0;
            return;
        }

        var next = [];

        for (var i = 0; i < apps.length; i++) {
            var app = apps[i];
            if (appMatches(app, query))
                next.push(app);
        }

        next.sort((a, b) => normalizeText(a.name).localeCompare(normalizeText(b.name)));
        filteredApps = next;

        if (selectedAppIndex >= filteredApps.length)
            selectedAppIndex = Math.max(0, filteredApps.length - 1);
    }

    function launchEntry(entry) {
        if (!entry)
            return;

        entry.execute();
        appQuery = "";
        refreshFilteredApps();
        GlobalStates.overviewOpen = false;
    }

    function ensureSelectedVisible() {
        if (!hasSearchQuery || filteredApps.length === 0)
            return;
        if (!appsFlick)
            return;

        var rowTop = selectedAppIndex * (launcherRowHeight + launcherRowSpacing);
        var rowBottom = rowTop + launcherRowHeight;
        var viewTop = appsFlick.contentY;
        var viewBottom = viewTop + appsFlick.height - launcherListPadding * 2;

        if (rowTop < viewTop)
            appsFlick.contentY = rowTop;
        else if (rowBottom > viewBottom)
            appsFlick.contentY = rowBottom - (appsFlick.height - launcherListPadding * 2);
    }
    
    implicitWidth: background.implicitWidth + padding * 2
    implicitHeight: background.implicitHeight + padding * 2
    
    Rectangle {
        id: background
        anchors.centerIn: parent
        
        implicitWidth: mainLayout.implicitWidth + padding * 2
        implicitHeight: mainLayout.implicitHeight + padding * 2
        radius: 16
        color: "#1e1e1e"
        border.color: "#3a3a3a"
        border.width: 2
        
        Column {
            id: mainLayout
            anchors.centerIn: parent
            spacing: workspaceSpacing

            Rectangle {
                id: launcherPanel

                width: workspaceColumnLayout.implicitWidth
                radius: 10
                color: "#161616"
                border.width: 1
                border.color: "#2f2f2f"
                implicitHeight: launcherColumn.implicitHeight + 14

                Column {
                    id: launcherColumn

                    width: parent.width - 14
                    spacing: 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 7

                    Rectangle {
                        width: parent.width
                        height: 36
                        radius: 8
                        color: "#242424"
                        border.width: 1
                        border.color: searchInput.activeFocus ? "#4a9eff" : "#353535"

                        TextInput {
                            id: searchInput

                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: TextInput.AlignVCenter
                            color: "#efefef"
                            selectionColor: "#3d6fb8"
                            selectedTextColor: "#ffffff"
                            font.pixelSize: 13
                            clip: true
                            text: root.appQuery

                            onTextChanged: {
                                root.appQuery = text;
                                root.selectedAppIndex = 0;
                                root.refreshFilteredApps();
                            }

                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Down) {
                                    root.selectedAppIndex = Math.min(root.filteredApps.length - 1, root.selectedAppIndex + 1);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Up) {
                                    root.selectedAppIndex = Math.max(0, root.selectedAppIndex - 1);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    if (root.filteredApps.length > 0)
                                        root.launchEntry(root.filteredApps[root.selectedAppIndex]);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Escape) {
                                    GlobalStates.overviewOpen = false;
                                    event.accepted = true;
                                }
                            }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            color: "#8f8f8f"
                            font.pixelSize: 13
                            text: "Type to launch an app..."
                            visible: searchInput.text.length === 0
                        }
                    }

                    Rectangle {
                        visible: root.hasSearchQuery
                        width: parent.width
                        height: root.launcherViewportHeight
                        radius: 8
                        color: "#1d1d1d"

                        Flickable {
                            id: appsFlick

                            anchors.fill: parent
                            anchors.margins: root.launcherListPadding
                            clip: true
                            interactive: true
                            boundsBehavior: Flickable.StopAtBounds
                            contentWidth: width
                            contentHeight: listContainer.implicitHeight

                            Column {
                                id: listContainer

                                width: appsFlick.width
                                spacing: root.launcherRowSpacing

                                Repeater {
                                    model: root.filteredApps.length

                                    delegate: Rectangle {
                                        required property int index
                                        property var entry: root.filteredApps[index]
                                        property bool selected: index === root.selectedAppIndex

                                        width: listContainer.width
                                        height: root.launcherRowHeight
                                        radius: 6
                                        color: selected ? "#314a72" : "transparent"

                                        Text {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 20
                                            color: selected ? "#ffffff" : "#d7d7d7"
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                            text: (entry?.name ?? "") + (entry?.genericName && entry.genericName.length > 0 ? " - " + entry.genericName : "")
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onEntered: root.selectedAppIndex = index
                                            onClicked: root.launchEntry(entry)
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton

                                onWheel: wheel => {
                                    appsFlick.contentY -= wheel.angleDelta.y / 2;
                                    wheel.accepted = true;
                                }
                            }
                        }

                        Text {
                            visible: root.hasSearchQuery && root.filteredApps.length === 0
                            anchors.centerIn: parent
                            color: "#8a8a8a"
                            font.pixelSize: 12
                            text: "No matching apps"
                        }
                    }
                }
            }

            Item {
                id: workspaceSection
                visible: !root.hasSearchQuery

                implicitWidth: workspaceColumnLayout.implicitWidth
                implicitHeight: workspaceColumnLayout.implicitHeight
                width: implicitWidth
                height: implicitHeight

                Column {
                    id: workspaceColumnLayout
                    anchors.centerIn: parent
                    spacing: workspaceSpacing

                    Repeater {
                        model: root.rows
                        delegate: Row {
                            id: row
                            required property int index
                            spacing: workspaceSpacing
                            
                            Repeater {
                                model: root.columns
                                delegate: Rectangle {
                                    id: workspace
                                    required property int index
                                    property int colIndex: index
                                    property int workspaceValue: row.index * root.columns + colIndex + 1
                                    property bool isActive: monitor.activeWorkspace?.id === workspaceValue
                                    property bool hoveredWhileDragging: root.draggingTargetWorkspace === workspaceValue
                                    
                                    width: root.workspaceImplicitWidth
                                    height: root.workspaceImplicitHeight
                                    color: hoveredWhileDragging ? "#2a2f38" : isActive ? "#2a4a6a" : "#252525"
                                    radius: 8
                                    border.width: isActive ? 3 : 1
                                    border.color: isActive ? "#4a9eff" : "#3a3a3a"
                                    
                                    Behavior on color {
                                        ColorAnimation { duration: 200 }
                                    }
                                    
                                    Behavior on border.color {
                                        ColorAnimation { duration: 200 }
                                    }
                                    
                                    Text {
                                        anchors.centerIn: parent
                                        text: workspace.workspaceValue
                                        font {
                                            pixelSize: 80 * root.scale
                                            weight: Font.DemiBold
                                        }
                                        color: workspace.isActive ? "#ffffff" : "#505050"
                                        opacity: 0.3
                                    }
                                    
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            if (root.draggingTargetWorkspace === -1) {
                                                GlobalStates.overviewOpen = false
                                                Hyprland.dispatch(`workspace ${workspace.workspaceValue}`)
                                            }
                                        }
                                    }

                                }
                            }
                        }
                    }
                }

                // Windows overlay
                Item {
                    id: windowSpace
                    anchors.centerIn: parent
                    width: workspaceColumnLayout.width
                    height: workspaceColumnLayout.height
                    
                    Repeater {
                        model: HyprlandData.windowList.filter(win => {
                            return win.workspace?.id > 0 && win.workspace?.id <= root.workspacesShown;
                        })
                        
                        delegate: Loader {
                            id: windowLoader
                            required property var modelData
                            z: (item && item.dynamicZ !== undefined) ? item.dynamicZ : 0
                            
                            property int workspaceId: modelData.workspace?.id ?? 1
                            property int rowIndex: Math.floor((workspaceId - 1) / root.columns)
                            property int colIndex: (workspaceId - 1) % root.columns
                            property real xOffset: (root.workspaceImplicitWidth + workspaceSpacing) * colIndex
                            property real yOffset: (root.workspaceImplicitHeight + workspaceSpacing) * rowIndex
                            
                            sourceComponent: OverviewWindow {
                                overviewWidget: root
                                toplevel: {
                                    // Find the toplevel for this window
                                    var toplevels = ToplevelManager.toplevels?.values ?? [];
                                    for (var i = 0; i < toplevels.length; i++) {
                                        var tl = toplevels[i];
                                        if (tl.HyprlandToplevel && `0x${tl.HyprlandToplevel.address}` === windowLoader.modelData.address) {
                                            return tl;
                                        }
                                    }
                                    return null;
                                }
                                windowData: windowLoader.modelData
                                monitorData: root.monitor
                                scale: root.scale
                                widgetMonitorWidth: root.monitor.width
                                widgetMonitorHeight: root.monitor.height
                                xOffset: windowLoader.xOffset
                                yOffset: windowLoader.yOffset
                            }
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: GlobalStates

        function onOverviewOpenChanged() {
            if (!GlobalStates.overviewOpen)
                return;

            root.appQuery = "";
            root.selectedAppIndex = 0;
            root.refreshFilteredApps();
            searchInput.forceActiveFocus();
        }
    }

    Connections {
        target: DesktopEntries

        function onApplicationsChanged() {
            root.refreshFilteredApps();
        }
    }

    onSelectedAppIndexChanged: Qt.callLater(root.ensureSelectedVisible)

    Component.onCompleted: root.refreshFilteredApps()
}
