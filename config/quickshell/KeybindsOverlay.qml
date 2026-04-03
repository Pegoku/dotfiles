import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    readonly property string focusedMonitorName: Hyprland.focusedMonitor?.name ?? ""
    property var pages: []
    property int currentPage: 0
    property string parserOutput: ""
    readonly property string parserScriptPath: Qt.resolvedUrl("scripts/parse-keybinds-help.sh").toString().replace("file://", "")

    function refreshPages() {
        if (parserProc.running)
            return;

        parserOutput = "";
        parserProc.running = true;
    }

    function closeOverlay() {
        GlobalStates.setKeybindsHelpOpen(false);
    }

    function openOverlay() {
        currentPage = 0;
        refreshPages();
        GlobalStates.setKeybindsHelpOpen(true);
    }

    function toggleOverlay() {
        if (GlobalStates.keybindsHelpOpen)
            closeOverlay();
        else
            openOverlay();
    }

    function clampPage(index) {
        if (!pages || pages.length === 0)
            return 0;
        return Math.max(0, Math.min(index, pages.length - 1));
    }

    function setPage(index) {
        currentPage = clampPage(index);
    }

    function changePage(delta) {
        setPage(currentPage + delta);
    }

    function parsePages(raw) {
        var lines = String(raw || "").split("\n");
        var pageOrder = [];
        var pageMap = {};

        function ensurePage(title) {
            if (!title || title.length === 0)
                title = "General";
            if (pageMap[title])
                return pageMap[title];

            var page = { title: title, entries: [] };
            pageMap[title] = page;
            pageOrder.push(page);
            return page;
        }

        for (var i = 0; i < lines.length; ++i) {
            var line = lines[i].trim();
            if (!line)
                continue;

            var parts = line.split("\t");
            if (parts.length < 2)
                continue;

            if (parts[0] === "SECTION") {
                ensurePage(parts[1]);
                continue;
            }

            if (parts[0] !== "ENTRY" || parts.length < 5)
                continue;

            ensurePage(parts[1]).entries.push({
                shortcut: parts[2],
                description: parts[3],
                action: parts[4]
            });
        }

        var filteredPages = [];
        for (var j = 0; j < pageOrder.length; ++j) {
            if (pageOrder[j].entries.length > 0)
                filteredPages.push(pageOrder[j]);
        }

        return filteredPages;
    }

    IpcHandler {
        target: "keybinds"

        function toggle(): void {
            root.toggleOverlay();
        }

        function open(): void {
            root.openOverlay();
        }

        function close(): void {
            root.closeOverlay();
        }
    }

    Process {
        id: parserProc

        command: ["bash", root.parserScriptPath]
        running: false

        stdout: SplitParser {
            onRead: data => {
                root.parserOutput += data + "\n";
            }
        }

        onExited: {
            root.pages = root.parsePages(root.parserOutput);
            if (root.pages.length === 0)
                root.currentPage = 0;
            else if (root.currentPage >= root.pages.length)
                root.currentPage = root.pages.length - 1;
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panelWindow
            required property var modelData
            screen: modelData
            readonly property bool isFocusedScreen: panelWindow.screen?.name === root.focusedMonitorName
            readonly property var activePage: root.pages.length > 0 ? root.pages[root.currentPage] : null

            visible: GlobalStates.keybindsHelpOpen
            color: "transparent"

            WlrLayershell.namespace: "quickshell:keybinds"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: GlobalStates.keybindsHelpOpen && isFocusedScreen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Rectangle {
                anchors.fill: parent
                color: "#000000"
                opacity: GlobalStates.keybindsHelpOpen ? 0.72 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 180 }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.closeOverlay()
                }
            }

            FocusScope {
                id: keyHandler
                anchors.fill: parent
                focus: GlobalStates.keybindsHelpOpen && panelWindow.isFocusedScreen

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape || event.key === Qt.Key_H) {
                        root.closeOverlay();
                        event.accepted = true;
                        return;
                    }

                    if (event.key === Qt.Key_Left || event.key === Qt.Key_PageUp) {
                        root.changePage(-1);
                        event.accepted = true;
                        return;
                    }

                    if (event.key === Qt.Key_Right || event.key === Qt.Key_PageDown || event.key === Qt.Key_Space) {
                        root.changePage(1);
                        event.accepted = true;
                        return;
                    }

                    if (event.key === Qt.Key_Home) {
                        root.setPage(0);
                        event.accepted = true;
                        return;
                    }

                    if (event.key === Qt.Key_End) {
                        root.setPage(root.pages.length - 1);
                        event.accepted = true;
                    }
                }
            }

            Rectangle {
                id: helpCard
                visible: panelWindow.isFocusedScreen
                anchors.centerIn: parent
                width: Math.min(parent.width - 80, 980)
                height: Math.min(parent.height - 100, 760)
                radius: 18
                color: "#171717"
                border.color: "#333333"
                border.width: 1

                Column {
                    anchors.fill: parent
                    anchors.margins: 22
                    spacing: 16

                    Row {
                        width: parent.width
                        spacing: 12

                        Column {
                            width: parent.width - pageBadge.width - 12
                            spacing: 6

                            Text {
                                width: parent.width
                                text: panelWindow.activePage ? panelWindow.activePage.title : "Keybinds"
                                color: "#f3f3f3"
                                font.pixelSize: 30
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: panelWindow.activePage ? panelWindow.activePage.entries.length + " shortcuts from ~/.config/hypr/hyprland/keybinds.conf" : "No shortcuts found"
                                color: "#a8a8a8"
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }
                        }

                        Rectangle {
                            id: pageBadge
                            width: 90
                            height: 34
                            radius: 17
                            color: "#242424"
                            border.color: "#3a3a3a"

                            Text {
                                anchors.centerIn: parent
                                text: root.pages.length > 0 ? (root.currentPage + 1) + " / " + root.pages.length : "0 / 0"
                                color: "#dddddd"
                                font.pixelSize: 14
                                font.bold: true
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#2a2a2a"
                    }

                    Flickable {
                        id: entryList
                        width: parent.width
                        height: parent.height - navigationRow.height - 84
                        contentWidth: width
                        contentHeight: entryColumn.height
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true

                        onVisibleChanged: if (visible) contentY = 0

                        Column {
                            id: entryColumn
                            width: entryList.width
                            spacing: 10

                            Repeater {
                                model: panelWindow.activePage ? panelWindow.activePage.entries : []

                                delegate: Rectangle {
                                    required property var modelData

                                    width: entryColumn.width
                                    height: implicitHeight
                                    radius: 12
                                    color: "#1d1d1d"
                                    border.color: "#2f2f2f"
                                    border.width: 1
                                    implicitHeight: Math.max(62, rowLayout.implicitHeight + 22)

                                    Row {
                                        id: rowLayout
                                        x: 14
                                        y: 11
                                        width: parent.width - 28
                                        spacing: 16

                                        Rectangle {
                                            width: 220
                                            height: implicitHeight
                                            radius: 10
                                            color: "#2a2232"
                                            border.color: "#4c3a57"
                                            border.width: 1
                                            implicitHeight: shortcutLabel.implicitHeight + 18

                                            Text {
                                                id: shortcutLabel
                                                anchors.centerIn: parent
                                                width: parent.width - 20
                                                text: modelData.shortcut
                                                color: "#f5eaff"
                                                font.pixelSize: 14
                                                font.bold: true
                                                horizontalAlignment: Text.AlignHCenter
                                                wrapMode: Text.Wrap
                                            }
                                        }

                                        Column {
                                            width: rowLayout.width - 236
                                            spacing: 4

                                            Text {
                                                width: parent.width
                                                text: modelData.description
                                                color: "#f0f0f0"
                                                font.pixelSize: 14
                                                wrapMode: Text.Wrap
                                            }

                                            Text {
                                                width: parent.width
                                                text: modelData.action
                                                color: "#8f8f8f"
                                                font.pixelSize: 12
                                                wrapMode: Text.WrapAnywhere
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Row {
                        id: navigationRow
                        width: parent.width
                        spacing: 10

                        Rectangle {
                            width: 110
                            height: 38
                            radius: 10
                            color: root.currentPage > 0 ? "#2a2a2a" : "#202020"
                            border.color: root.currentPage > 0 ? "#4a4a4a" : "#303030"

                            MouseArea {
                                anchors.fill: parent
                                enabled: root.currentPage > 0
                                onClicked: root.changePage(-1)
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "Prev"
                                color: root.currentPage > 0 ? "#f0f0f0" : "#727272"
                                font.pixelSize: 14
                                font.bold: true
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Left/Right to switch pages. Esc or H to close."
                            color: "#9e9e9e"
                            font.pixelSize: 13
                        }

                        Item {
                            width: parent.width - 340
                            height: 1
                        }

                        Rectangle {
                            width: 110
                            height: 38
                            radius: 10
                            color: root.currentPage < root.pages.length - 1 ? "#2a2a2a" : "#202020"
                            border.color: root.currentPage < root.pages.length - 1 ? "#4a4a4a" : "#303030"

                            MouseArea {
                                anchors.fill: parent
                                enabled: root.currentPage < root.pages.length - 1
                                onClicked: root.changePage(1)
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "Next"
                                color: root.currentPage < root.pages.length - 1 ? "#f0f0f0" : "#727272"
                                font.pixelSize: 14
                                font.bold: true
                            }
                        }
                    }
                }
            }
        }
    }
}
