import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "./services"

Scope {
    id: root
    property var state: ({ ready: false, busy: false, account: "Connecting…", error: "", chats: [], items: [], requests: [], models: [], thread: "" })
    property string draft: ""
    property var optimisticMessage: null
    property int messageSequence: 0
    property string selectedModel: AiChatConfig.model
    property bool started: false
    property var availableModels: []
    property string selectedEffort: ""
    property bool selectionInitialized: false
    readonly property var modelInfo: availableModels.find(m => m.id === selectedModel) || ({ efforts: [], defaultEffort: "" })
    readonly property var effortOptions: modelInfo.efforts
    property bool historyOpen: true
    property var pendingRequests: []
    property var savedChats: []
    property var activeScreen: Quickshell.screens[0]
    readonly property color ink: "#edf0f7"
    readonly property color muted: "#969daf"
    readonly property color accent: "#bbadff"

    function open() {
        var monitor = Hyprland.focusedMonitor;
        for (var s of Quickshell.screens) {
            if (monitor && s.name === monitor.name) activeScreen = s;
        }
        if (!started) { started = true; bridge.running = true; }
        GlobalStates.aiChatOpen = true;
        Qt.callLater(() => { openingGrab.active = true; composer.forceActiveFocus(); });
    }
    // The compositor releases this grab on an outside click. Keep the panel
    // open when that happens, so other apps remain usable while Codex works.
    HyprlandFocusGrab {
        id: openingGrab
        windows: [window]
    }
    function send(data) {
        if (bridge.running) bridge.write(JSON.stringify(data) + "\n");
    }
    function requestDetails(request) {
        var p = request.params;
        if (request.method === "item/tool/requestUserInput") return "";
        var details = [p.reason || "", p.command || ""];
        if (p.permissions) details.push(JSON.stringify(p.permissions, null, 2));
        if (p.networkApprovalContext) details.push(JSON.stringify(p.networkApprovalContext, null, 2));
        if (p.grantRoot) details.push("Folder: " + p.grantRoot);
        if (request.method === "item/fileChange/requestApproval") {
            var item = root.state.items.find(i => i.id === p.itemId);
            if (item) details.push(item.text);
        }
        return details.filter(s => s).join("\n\n") || JSON.stringify(p, null, 2);
    }
    function submit() {
        if (!draft.trim() || state.busy || !state.ready) return;
        var text = draft.trim();
        var id = "local-" + Date.now() + "-" + (++messageSequence);
        optimisticMessage = { id: id, kind: "userMessage", title: "You", text: text, status: "" };
        messages.append({ itemId: id, kind: "userMessage", title: "You", body: text, status: "" });
        root.state = Object.assign({}, root.state, { busy: true, error: "" });
        draft = "";
        conversation.follow = true;
        Qt.callLater(() => conversation.positionViewAtEnd());
        send({ action: "send", text: text, clientMessageId: id, cwd: folder.text, model: selectedModel, effort: selectedEffort });
    }
    IpcHandler {
        target: "aichat"
        function toggle(): void { if (GlobalStates.aiChatOpen) GlobalStates.aiChatOpen = false; else root.open(); }
        function open(): void { root.open(); }
        function close(): void { GlobalStates.aiChatOpen = false; }
    }
    Process {
        id: bridge
        command: ["python3", "-u", decodeURIComponent(Qt.resolvedUrl("scripts/codex_chat.py").toString().replace("file://", ""))]
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => {
                try {
                    var next = JSON.parse(line);
                    if (next.type !== "state") return;
                    if (JSON.stringify(root.state.models) !== JSON.stringify(next.models)) {
                        root.availableModels = next.models;
                    }
                    if (JSON.stringify(root.state.requests) !== JSON.stringify(next.requests)) root.pendingRequests = next.requests;
                    if (JSON.stringify(root.state.chats) !== JSON.stringify(next.chats)) root.savedChats = next.chats;
                    if (!root.selectionInitialized && next.models.length && next.model) {
                        root.selectedModel = AiChatConfig.model || next.model;
                        root.selectedEffort = AiChatConfig.model ? root.modelInfo.defaultEffort : next.effort;
                        root.selectionInitialized = true;
                    } else if ((next.thread !== root.state.thread && next.thread) || (root.state.model && next.model && next.model !== root.state.model)) {
                        root.selectedModel = next.model;
                        root.selectedEffort = next.effort || root.modelInfo.defaultEffort;
                    }
                    if (root.state.effort && next.effort && next.effort !== root.state.effort) root.selectedEffort = next.effort;
                    if (!root.selectedEffort) root.selectedEffort = root.modelInfo.defaultEffort;
                    if (root.optimisticMessage && next.receivedMessage === root.optimisticMessage.id) root.optimisticMessage = null;
                    if (root.optimisticMessage) next.busy = true;
                    root.state = next;
                    if (!folder.activeFocus && next.cwd) folder.text = next.cwd;
                    // Update rows in place: streaming must not destroy text selection or scroll position.
                    var rows = next.items.slice();
                    if (root.optimisticMessage) rows.push(root.optimisticMessage);
                    if (messages.count > rows.length || (messages.count && rows.length && messages.get(0).itemId !== rows[0].id)) messages.clear();
                    for (var i = 0; i < rows.length; i++) {
                        var r = rows[i];
                        var row = { itemId: r.id, kind: r.kind, title: r.title, body: r.text, status: r.status };
                        if (i >= messages.count) messages.append(row);
                        else if (messages.get(i).itemId !== r.id || messages.get(i).body !== r.text || messages.get(i).status !== r.status) messages.set(i, row);
                    }
                    if (conversation.follow) Qt.callLater(() => conversation.positionViewAtEnd());
                } catch (e) { console.warn("Codex bridge: " + e); }
            }
        }
        onExited: {
            root.state = Object.assign({}, root.state, { ready: false, busy: false, error: root.state.error || "Codex disconnected. Reconnect to continue." });
        }
    }
    ListModel { id: messages }

    component ChatButton: Button {
        id: button
        property bool primary: false
        implicitHeight: 34
        padding: 12
        hoverEnabled: true
        background: Rectangle {
            radius: 9
            color: button.primary ? root.accent : (button.hovered ? "#363744" : "#292a35")
            opacity: button.enabled ? 1 : 0.4
        }
        contentItem: Text {
            text: button.text
            color: button.primary ? "#211b35" : root.ink
            font.pixelSize: 13
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            opacity: button.enabled ? 1 : 0.4
        }
    }

    component ChatCombo: ComboBox {
        id: control
        implicitHeight: 38
        padding: 10
        hoverEnabled: true
        background: Rectangle { radius: 9; color: control.hovered ? "#30313e" : "#242530"; border.color: control.activeFocus ? root.accent : "#41404f" }
        contentItem: Text { text: control.displayText; color: root.ink; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight; rightPadding: 22 }
        indicator: Text { x: control.width - 25; anchors.verticalCenter: parent.verticalCenter; text: "⌄"; color: root.muted; font.pixelSize: 16 }
        delegate: ItemDelegate {
            id: option
            required property int index
            required property var modelData
            width: control.width - 12
            height: 40
            highlighted: control.highlightedIndex === index
            background: Rectangle { radius: 7; color: option.highlighted ? "#393047" : "transparent" }
            contentItem: Text { text: option.modelData[control.textRole]; color: option.index === control.currentIndex ? root.accent : root.ink; font.pixelSize: 12; verticalAlignment: Text.AlignVCenter }
        }
        popup: Popup {
            y: control.height + 6
            width: control.width
            padding: 6
            implicitHeight: Math.min(contentItem.implicitHeight + 12, 330)
            background: Rectangle { radius: 12; color: "#23242f"; border.color: "#4c455f" }
            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: control.popup.visible ? control.delegateModel : null
                currentIndex: control.highlightedIndex
                ScrollBar.vertical: ScrollBar {}
            }
        }
    }

    PanelWindow {
        id: window
        screen: root.activeScreen
        visible: GlobalStates.aiChatOpen
        color: "transparent"
        anchors { top: true; bottom: true; left: true }
        implicitWidth: Math.min(780, (screen ? screen.width : 1920) - 24)
        margins { top: 52; bottom: 12; left: 12 }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell:aichat"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        onVisibleChanged: {
            if (!visible) {
                openingGrab.active = false;
            }
        }

        Rectangle {
            id: card
            anchors.fill: parent
            radius: 22
            color: "#191a22"
            border.color: "#41404f"
            // Consume clicks in the panel without blocking its controls.
            MouseArea { anchors.fill: parent }
            Keys.onEscapePressed: GlobalStates.aiChatOpen = false

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 16
                RowLayout {
                    Layout.fillWidth: true
                    Rectangle {
                        width: 38; height: 38; radius: 12; color: "#343047"
                        Text { anchors.centerIn: parent; text: ">_"; color: root.accent; font.pixelSize: 20; font.bold: true }
                    }
                    ColumnLayout {
                        spacing: 3
                        Text { text: "Codex"; color: root.ink; font.pixelSize: 22; font.weight: Font.DemiBold }
                        Text { text: root.state.account; color: root.muted; font.pixelSize: 12 }
                    }
                    Item { Layout.fillWidth: true }
                    ChatButton { text: root.historyOpen ? "Hide history" : "History"; onClicked: root.historyOpen = !root.historyOpen }
                    ChatButton { text: "+ New chat"; enabled: !root.state.busy; onClicked: root.send({ action: "new" }) }
                    ChatButton {
                        text: "Reconnect"; visible: !root.state.ready
                        onClicked: { if (bridge.running) root.send({ action: "refresh" }); else bridge.running = true; }
                    }
                    ChatButton { text: "✕"; onClicked: GlobalStates.aiChatOpen = false }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Folder"; color: root.muted; font.pixelSize: 12 }
                    TextField {
                        id: folder
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        leftPadding: 10
                        text: AiChatConfig.workingDirectory
                        enabled: !root.state.busy
                        color: root.ink; selectByMouse: true; font.pixelSize: 12
                        background: Rectangle { radius: 8; color: "#23242f"; border.color: folder.activeFocus ? root.accent : "#343541" }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14
                    ChatCombo {
                        id: modelPicker
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        enabled: !root.state.busy && root.availableModels.length > 0
                        model: root.availableModels
                        currentIndex: root.availableModels.findIndex(m => m.id === root.selectedModel)
                        textRole: "label"
                        displayText: currentIndex >= 0 ? root.availableModels[currentIndex].label : (root.selectedModel || "Loading models…")
                        onActivated: index => {
                            root.selectedModel = root.availableModels[index].id;
                            root.selectedEffort = root.modelInfo.defaultEffort;
                        }
                    }
                    ColumnLayout {
                        Layout.preferredWidth: 240
                        Layout.maximumWidth: 280
                        spacing: 0
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Reasoning"; color: root.muted; font.pixelSize: 11 }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: root.selectedEffort ? root.selectedEffort + (root.selectedEffort === root.modelInfo.defaultEffort ? " · recommended" : "") : "Unavailable"
                                color: root.accent; font.pixelSize: 11
                            }
                        }
                        Slider {
                            id: reasoning
                            Accessible.name: "Reasoning effort"
                            Layout.fillWidth: true
                            implicitHeight: 23
                            from: 0; to: Math.max(1, root.effortOptions.length - 1); stepSize: 1
                            snapMode: Slider.SnapAlways
                            enabled: !root.state.busy && root.effortOptions.length > 1
                            value: Math.max(0, root.effortOptions.findIndex(e => e.id === root.selectedEffort))
                            onMoved: root.selectedEffort = root.effortOptions[Math.round(value)].id
                            ToolTip.visible: hovered || pressed
                            ToolTip.text: (root.effortOptions[Math.round(value)] || {}).description || ""
                            background: Rectangle {
                                x: reasoning.leftPadding; y: reasoning.topPadding + reasoning.availableHeight / 2 - height / 2
                                width: reasoning.availableWidth; height: 4; radius: 2; color: "#42404f"
                                Rectangle { width: reasoning.visualPosition * parent.width; height: parent.height; radius: 2; color: root.accent }
                            }
                            handle: Rectangle {
                                x: reasoning.leftPadding + reasoning.visualPosition * (reasoning.availableWidth - width)
                                y: reasoning.topPadding + reasoning.availableHeight / 2 - height / 2
                                width: 13; height: 13; radius: 7; color: reasoning.pressed ? "#e2daff" : root.accent
                            }
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 20
                    ColumnLayout {
                        Layout.preferredWidth: 164
                        Layout.maximumWidth: 164
                        Layout.fillHeight: true
                        visible: root.historyOpen
                        Text { text: "CONVERSATIONS"; color: root.muted; font.pixelSize: 10; font.letterSpacing: 1.4 }
                        ListView {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            clip: true; spacing: 6
                            model: root.savedChats
                            ScrollBar.vertical: ScrollBar {}
                            delegate: ItemDelegate {
                                required property var modelData
                                width: ListView.view.width
                                height: 62
                                enabled: !root.state.busy
                                background: Rectangle {
                                    radius: 10
                                    color: modelData.id === root.state.thread ? "#342d49" : (parent.hovered ? "#2b2c39" : "#22232e")
                                    border.color: modelData.id === root.state.thread ? "#8473b0" : "#3c3d4d"
                                    Rectangle { width: 3; height: 22; radius: 2; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; color: root.accent; visible: modelData.id === root.state.thread }
                                }
                                contentItem: Text { text: modelData.title; color: modelData.id === root.state.thread ? root.accent : root.muted; font.pixelSize: 12; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter }
                                onClicked: { conversation.follow = true; root.send({ action: "resume", thread: modelData.id, cwd: modelData.cwd }); }
                            }
                        }
                        Text { text: "Super+B  toggle\nEsc  hide"; color: root.muted; font.pixelSize: 11; lineHeight: 1.5 }
                    }
                    Rectangle { Layout.fillHeight: true; width: 1; color: "#30303c"; visible: root.historyOpen }
                    ColumnLayout {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        spacing: 12
                        Item {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            Column {
                                anchors.centerIn: parent; width: Math.min(380, parent.width); spacing: 14
                                visible: messages.count === 0
                                Text { width: parent.width; text: "What are we working on?"; color: root.ink; font.pixelSize: 26; font.weight: Font.Medium; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter }
                                Text { width: parent.width; text: "Ask a question, search the web, or work on files in your selected folder."; color: root.muted; font.pixelSize: 14; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter; lineHeight: 1.4 }
                            }
                            ListView {
                                id: conversation
                                property bool follow: true
                                anchors.fill: parent
                                clip: true; spacing: 14
                                model: messages
                                onMovementEnded: follow = atYEnd
                                onContentYChanged: { if (moving) follow = atYEnd; }
                                ScrollBar.vertical: ScrollBar { onPressedChanged: { if (!pressed) conversation.follow = conversation.atYEnd; } }
                                delegate: Rectangle {
                                    id: message
                                    required property string kind
                                    required property string title
                                    required property string body
                                    required property string status
                                    property bool tool: kind !== "userMessage" && kind !== "agentMessage"
                                    property bool expanded: false
                                    width: conversation.width - 14
                                    height: messageLayout.implicitHeight + 24
                                    radius: 12
                                    color: kind === "userMessage" ? "#2e293e" : (tool ? "#22232d" : "transparent")
                                    ColumnLayout {
                                        id: messageLayout
                                        x: 12; y: 12; width: parent.width - 24
                                        spacing: 8
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text { text: message.title; color: message.kind === "userMessage" ? root.accent : root.muted; font.pixelSize: 11; font.weight: Font.DemiBold }
                                            Text { text: message.status === "inProgress" ? "• running" : message.status; color: root.muted; font.pixelSize: 10 }
                                            Item { Layout.fillWidth: true }
                                            ChatButton { text: message.expanded ? "Collapse" : "Details"; visible: message.tool; implicitHeight: 26; onClicked: message.expanded = !message.expanded }
                                            ChatButton { text: "Copy"; implicitHeight: 26; onClicked: { bodyText.selectAll(); bodyText.copy(); bodyText.deselect(); } }
                                        }
                                        TextEdit {
                                            id: bodyText
                                            Layout.fillWidth: true
                                            visible: !message.tool || message.expanded
                                            text: message.body
                                            textFormat: message.kind === "agentMessage" ? TextEdit.MarkdownText : TextEdit.PlainText
                                            readOnly: true; selectByMouse: true; wrapMode: TextEdit.Wrap
                                            color: root.ink; selectionColor: "#665780"; selectedTextColor: "#ffffff"
                                            font.pixelSize: message.tool ? 12 : 14
                                            font.family: message.tool ? "monospace" : "sans-serif"
                                            onLinkActivated: link => { if (/^https?:\/\//i.test(link)) Qt.openUrlExternally(link); }
                                        }
                                    }
                                }
                            }
                            ChatButton {
                                anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                                visible: !conversation.follow && messages.count > 0
                                text: "↓ Latest"; onClicked: { conversation.follow = true; conversation.positionViewAtEnd(); }
                            }
                        }
                        Text {
                            Layout.fillWidth: true; visible: root.state.error !== ""
                            text: root.state.error; color: "#ffaaa6"; font.pixelSize: 12; wrapMode: Text.Wrap
                            maximumLineCount: 4; elide: Text.ElideRight
                        }
                        // Requests are explicit, actionable cards; never silently approve a tool.
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.preferredHeight: visible ? Math.min(240, requestColumn.implicitHeight) : 0
                            visible: root.state.requests.length > 0
                            clip: true
                            ColumnLayout {
                                id: requestColumn
                                width: parent.width
                                Repeater {
                                    model: root.pendingRequests
                                    delegate: Rectangle {
                                        id: requestCard
                                        required property var modelData
                                        property var answers: ({})
                                        Layout.fillWidth: true
                                        implicitHeight: requestBody.implicitHeight + 24
                                        radius: 12; color: "#373040"
                                        ColumnLayout {
                                            id: requestBody
                                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                                            Text { text: requestCard.modelData.method === "item/tool/requestUserInput" ? "Codex has a question" : "Permission needed"; color: root.accent; font.bold: true }
                                            TextEdit {
                                                Layout.fillWidth: true
                                                readOnly: true; selectByMouse: true; wrapMode: TextEdit.Wrap; color: root.ink; font.pixelSize: 12
                                                text: root.requestDetails(requestCard.modelData)
                                            }
                                            Repeater {
                                                model: requestCard.modelData.params.questions || []
                                                delegate: ColumnLayout {
                                                    required property var modelData
                                                    Layout.fillWidth: true
                                                    Text { Layout.fillWidth: true; text: modelData.question; wrapMode: Text.Wrap; color: root.ink }
                                                    Text { Layout.fillWidth: true; text: (modelData.options || []).map(o => o.label + ": " + o.description).join("\n"); wrapMode: Text.Wrap; color: root.muted; font.pixelSize: 12 }
                                                    TextField { Layout.fillWidth: true; placeholderText: "Your answer"; onTextChanged: requestCard.answers[modelData.id] = { answers: [text] } }
                                                }
                                            }
                                            RowLayout {
                                                ChatButton { text: "Deny"; visible: requestCard.modelData.method !== "item/tool/requestUserInput"; onClicked: root.send({ action: "reply", id: requestCard.modelData.id, allow: false }) }
                                                ChatButton { text: requestCard.modelData.method === "item/tool/requestUserInput" ? "Reply" : "Allow once"; primary: true; onClicked: root.send({ action: "reply", id: requestCard.modelData.id, allow: true, answers: requestCard.answers }) }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: Math.min(160, Math.max(94, composer.contentHeight + 28))
                            radius: 14; color: "#242530"; border.color: composer.activeFocus ? "#8c7fbc" : "#41404f"
                            ScrollView {
                                anchors.fill: parent; anchors.margins: 12; clip: true
                                TextArea {
                                    id: composer
                                    text: root.draft
                                    onTextChanged: root.draft = text
                                    placeholderText: "Ask Codex anything…"
                                    placeholderTextColor: root.muted
                                    color: root.ink; font.pixelSize: 14; wrapMode: TextEdit.Wrap; selectByMouse: true
                                    background: null
                                    Keys.onPressed: event => {
                                        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) { root.submit(); event.accepted = true; }
                                        else if (event.key === Qt.Key_Escape) { GlobalStates.aiChatOpen = false; event.accepted = true; }
                                    }
                                }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: root.state.busy ? "●  Codex is working…" : "Enter to send · Shift+Enter for a new line"; color: root.state.busy ? root.accent : root.muted; font.pixelSize: 11; Layout.fillWidth: true }
                            ChatButton { text: "Stop"; visible: root.state.busy; onClicked: root.send({ action: "stop" }) }
                            ChatButton { text: "Send ↑"; primary: true; visible: !root.state.busy; enabled: root.state.ready && root.draft.trim().length > 0; onClicked: root.submit() }
                        }
                    }
                }
            }
        }
    }
}
