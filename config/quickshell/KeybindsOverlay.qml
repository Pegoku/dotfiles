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

    function displayAction(action) {
        var text = String(action || "").trim();
        if (text.startsWith("exec "))
            return text.substring(5);
        return text;
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
                width: Math.min(parent.width - 64, 1220)
                height: Math.min(parent.height - 72, 820)
                radius: 24
                color: "#121214"
                border.color: "#40354f"
                border.width: 1

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: parent.radius - 1
                    color: "#18181b"
                    border.color: "#2a2a31"
                    border.width: 1
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 20

                    Rectangle {
                        id: sidebar
                        width: 260
                        height: parent.height
                        radius: 20
                        color: "#14141a"
                        border.color: "#2b2b36"
                        border.width: 1

                        Column {
                            anchors.fill: parent
                            anchors.margins: 18
                            spacing: 16

                            Column {
                                width: parent.width
                                spacing: 6

                                Text {
                                    width: parent.width
                                    text: "Keybind Help"
                                    color: "#f6f2ff"
                                    font.pixelSize: 28
                                    font.bold: true
                                }

                                Text {
                                    width: parent.width
                                    text: "Pages are read from ~/.config/hypr/hyprland/keybinds.conf headings."
                                    color: "#9f9cab"
                                    font.pixelSize: 13
                                    wrapMode: Text.Wrap
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: "#272732"
                            }

                            Flickable {
                                width: parent.width
                                height: parent.height - 150
                                contentWidth: width
                                contentHeight: pageColumn.height
                                boundsBehavior: Flickable.StopAtBounds
                                clip: true

                                Column {
                                    id: pageColumn
                                    width: parent.width
                                    spacing: 8

                                    Repeater {
                                        model: root.pages

                                        delegate: Rectangle {
                                            required property var modelData
                                            required property int index

                                            width: pageColumn.width
                                            height: 56
                                            radius: 14
                                            color: root.currentPage === index ? "#2a2233" : "#1b1b22"
                                            border.color: root.currentPage === index ? "#7f5ab5" : "#30303a"
                                            border.width: 1

                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: root.setPage(index)
                                            }

                                            Column {
                                                anchors.left: parent.left
                                                anchors.right: pageCountBadge.left
                                                anchors.leftMargin: 14
                                                anchors.rightMargin: 12
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 3

                                                Text {
                                                    width: parent.width
                                                    text: modelData.title
                                                    color: root.currentPage === index ? "#fbf7ff" : "#d5d2dc"
                                                    font.pixelSize: 14
                                                    font.bold: true
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    width: parent.width
                                                    text: modelData.entries.length + " shortcuts"
                                                    color: root.currentPage === index ? "#c8b6e7" : "#888594"
                                                    font.pixelSize: 12
                                                    elide: Text.ElideRight
                                                }
                                            }

                                            Rectangle {
                                                id: pageCountBadge
                                                anchors.right: parent.right
                                                anchors.rightMargin: 12
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 34
                                                height: 24
                                                radius: 12
                                                color: root.currentPage === index ? "#4b3866" : "#262630"

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: index + 1
                                                    color: root.currentPage === index ? "#ffffff" : "#a7a4b1"
                                                    font.pixelSize: 12
                                                    font.bold: true
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Column {
                        width: parent.width - sidebar.width - 20
                        height: parent.height
                        spacing: 16

                        Rectangle {
                            width: parent.width
                            height: 118
                            radius: 20
                            color: "#15151a"
                            border.color: "#2c2c36"
                            border.width: 1

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 6
                                radius: 3
                                color: "#8b5cf6"
                            }

                            Row {
                                anchors.fill: parent
                                anchors.margins: 22
                                spacing: 18

                                Column {
                                    width: parent.width - pageBadge.width - navPill.width - 36
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8

                                    Text {
                                        width: parent.width
                                        text: panelWindow.activePage ? panelWindow.activePage.title : "Keybinds"
                                        color: "#faf7ff"
                                        font.pixelSize: 34
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width: parent.width
                                        text: panelWindow.activePage ? panelWindow.activePage.entries.length + " shortcuts in this section" : "No shortcuts found"
                                        color: "#aea8bc"
                                        font.pixelSize: 14
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width: parent.width
                                        text: "Use Left/Right, PageUp/PageDown, Home/End. Press Esc or H to close."
                                        color: "#7e7a89"
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                    }
                                }

                                Rectangle {
                                    id: navPill
                                    width: 152
                                    height: 36
                                    radius: 18
                                    color: "#1f1f26"
                                    border.color: "#333341"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Section navigation"
                                        color: "#c9c6d2"
                                        font.pixelSize: 12
                                        font.bold: true
                                    }
                                }

                                Rectangle {
                                    id: pageBadge
                                    width: 88
                                    height: 42
                                    radius: 21
                                    color: "#241f2d"
                                    border.color: "#57426f"
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.pages.length > 0 ? (root.currentPage + 1) + " / " + root.pages.length : "0 / 0"
                                        color: "#f2ecff"
                                        font.pixelSize: 15
                                        font.bold: true
                                    }
                                }
                            }
                        }

                        Flickable {
                            id: entryList
                            width: parent.width
                            height: parent.height - footerBar.height - 134
                            contentWidth: width
                            contentHeight: entryColumn.height
                            boundsBehavior: Flickable.StopAtBounds
                            clip: true

                            onVisibleChanged: if (visible) contentY = 0

                            Column {
                                id: entryColumn
                                width: entryList.width
                                spacing: 12

                                Repeater {
                                    model: panelWindow.activePage ? panelWindow.activePage.entries : []

                                    delegate: Rectangle {
                                        required property var modelData

                                        width: entryColumn.width
                                        height: implicitHeight
                                        radius: 16
                                        color: "#1a1a1f"
                                        border.color: "#2f2f38"
                                        border.width: 1
                                        implicitHeight: Math.max(84, rowLayout.implicitHeight + 24)

                                        Row {
                                            id: rowLayout
                                            x: 18
                                            y: 12
                                            width: parent.width - 36
                                            spacing: 18

                                            Rectangle {
                                                width: 210
                                                height: implicitHeight
                                                radius: 13
                                                color: "#2a2233"
                                                border.color: "#64458b"
                                                border.width: 1
                                                implicitHeight: shortcutLabel.implicitHeight + 22

                                                Text {
                                                    id: shortcutLabel
                                                    anchors.centerIn: parent
                                                    width: parent.width - 24
                                                    text: modelData.shortcut
                                                    color: "#fbf6ff"
                                                    font.pixelSize: 15
                                                    font.bold: true
                                                    horizontalAlignment: Text.AlignHCenter
                                                    wrapMode: Text.Wrap
                                                }
                                            }

                                            Column {
                                                width: rowLayout.width - 228
                                                spacing: 8

                                                Text {
                                                    width: parent.width
                                                    text: modelData.description
                                                    color: "#f2f0f7"
                                                    font.pixelSize: 16
                                                    font.bold: true
                                                    wrapMode: Text.Wrap
                                                }

                                                Rectangle {
                                                    width: parent.width
                                                    height: commandText.implicitHeight + 16
                                                    radius: 10
                                                    color: "#141419"
                                                    border.color: "#2a2a33"
                                                    border.width: 1

                                                    Text {
                                                        id: commandText
                                                        anchors.fill: parent
                                                        anchors.margins: 8
                                                        text: root.displayAction(modelData.action)
                                                        color: "#9ca3af"
                                                        font.pixelSize: 12
                                                        font.family: "monospace"
                                                        wrapMode: Text.WrapAnywhere
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: footerBar
                            width: parent.width
                            height: 56
                            radius: 16
                            color: "#15151a"
                            border.color: "#2b2b34"
                            border.width: 1

                            Row {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 10

                                Rectangle {
                                    width: 104
                                    height: parent.height - 4
                                    radius: 12
                                    color: root.currentPage > 0 ? "#241f2d" : "#1c1c23"
                                    border.color: root.currentPage > 0 ? "#57426f" : "#30303a"

                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: root.currentPage > 0
                                        onClicked: root.changePage(-1)
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Prev"
                                        color: root.currentPage > 0 ? "#f5efff" : "#72727f"
                                        font.pixelSize: 14
                                        font.bold: true
                                    }
                                }

                                Rectangle {
                                    height: parent.height - 4
                                    width: 168
                                    radius: 12
                                    color: "#1b1b22"
                                    border.color: "#2f2f38"

                                    Text {
                                        anchors.centerIn: parent
                                        text: panelWindow.activePage ? panelWindow.activePage.entries.length + " visible binds" : "0 visible binds"
                                        color: "#c0bdc9"
                                        font.pixelSize: 13
                                        font.bold: true
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "This view updates from your Hyprland keybind file when the menu opens."
                                    color: "#8d8997"
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                    width: parent.width - 410
                                }

                                Rectangle {
                                    width: 104
                                    height: parent.height - 4
                                    radius: 12
                                    color: root.currentPage < root.pages.length - 1 ? "#241f2d" : "#1c1c23"
                                    border.color: root.currentPage < root.pages.length - 1 ? "#57426f" : "#30303a"

                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: root.currentPage < root.pages.length - 1
                                        onClicked: root.changePage(1)
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Next"
                                        color: root.currentPage < root.pages.length - 1 ? "#f5efff" : "#72727f"
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
    }
}
