import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "./services"

Scope {
    id: root

    property int topBarHeight: 40
    readonly property int panelOuterMargin: Math.round(topBarHeight * 0.5)

    function shellEscape(value) {
        return "'" + String(value).replace(/'/g, "'\"'\"'") + "'";
    }

    function selectedModelId(index) {
        var models = AiChatConfig.models ?? [];
        if (models.length === 0)
            return "openai/gpt-4o-mini";
        var i = Math.max(0, Math.min(index, models.length - 1));
        var model = models[i];
        return model.id ? String(model.id) : "openai/gpt-4o-mini";
    }

    IpcHandler {
        target: "aichat"

        function toggle(): void {
            GlobalStates.aiChatOpen = !GlobalStates.aiChatOpen;
        }
        function open(): void {
            GlobalStates.aiChatOpen = true;
        }
        function close(): void {
            GlobalStates.aiChatOpen = false;
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panelWindow
            required property var modelData
            screen: modelData
            visible: GlobalStates.aiChatOpen
            color: "transparent"

            WlrLayershell.namespace: "quickshell:aichat"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: GlobalStates.aiChatOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            Rectangle {
                anchors.fill: parent
                color: "#000000"
                opacity: 0.7

                MouseArea {
                    anchors.fill: parent
                    onClicked: GlobalStates.aiChatOpen = false
                }
            }

            Rectangle {
                id: chatPanel

                property var messages: []
                property int selectedModelIndex: 0
                property bool requestPending: false
                property string pendingModelLabel: ""

                function appendMessage(role, content, reasoning) {
                    var text = String(content);
                    var reason = reasoning ? String(reasoning) : "";
                    messages = messages.concat([{ role: role, content: text, reasoning: reason }]);
                    Qt.callLater(() => {
                        listView.positionViewAtEnd();
                    });
                }

                function escapeHtml(value) {
                    return String(value)
                        .replace(/&/g, "&amp;")
                        .replace(/</g, "&lt;")
                        .replace(/>/g, "&gt;")
                        .replace(/\"/g, "&quot;");
                }

                function renderInlineMarkdown(text) {
                    var src = String(text);
                    var parts = src.split("`");
                    var out = "";

                    for (var i = 0; i < parts.length; i++) {
                        if (i % 2 === 0)
                            out += escapeHtml(parts[i]);
                        else
                            out += "<code>" + escapeHtml(parts[i]) + "</code>";
                    }

                    return out;
                }

                function renderMarkdown(text) {
                    var lines = String(text).replace(/\r\n/g, "\n").split("\n");
                    var html = "";
                    var inCode = false;
                    var inUl = false;
                    var inOl = false;

                    function closeLists() {
                        if (inUl) {
                            html += "</ul>";
                            inUl = false;
                        }
                        if (inOl) {
                            html += "</ol>";
                            inOl = false;
                        }
                    }

                    for (var i = 0; i < lines.length; i++) {
                        var line = lines[i];
                        var trimmed = line.trim();

                        if (trimmed.startsWith("```")) {
                            closeLists();
                            if (!inCode) {
                                html += "<pre><code>";
                                inCode = true;
                            } else {
                                html += "</code></pre>";
                                inCode = false;
                            }
                            continue;
                        }

                        if (inCode) {
                            html += escapeHtml(line) + "\n";
                            continue;
                        }

                        if (trimmed.length === 0) {
                            closeLists();
                            html += "<br/>";
                            continue;
                        }

                        var ulMatch = line.match(/^\s*-\s+(.*)$/);
                        if (ulMatch) {
                            if (inOl) {
                                html += "</ol>";
                                inOl = false;
                            }
                            if (!inUl) {
                                html += "<ul>";
                                inUl = true;
                            }
                            html += "<li>" + renderInlineMarkdown(ulMatch[1]) + "</li>";
                            continue;
                        }

                        var olMatch = line.match(/^\s*\d+\.\s+(.*)$/);
                        if (olMatch) {
                            if (inUl) {
                                html += "</ul>";
                                inUl = false;
                            }
                            if (!inOl) {
                                html += "<ol>";
                                inOl = true;
                            }
                            html += "<li>" + renderInlineMarkdown(olMatch[1]) + "</li>";
                            continue;
                        }

                        closeLists();
                        html += "<p>" + renderInlineMarkdown(trimmed) + "</p>";
                    }

                    if (inCode)
                        html += "</code></pre>";
                    if (inUl)
                        html += "</ul>";
                    if (inOl)
                        html += "</ol>";

                    return html;
                }

                function tailWords(text, count) {
                    var words = String(text).trim().split(/\s+/);
                    if (words.length <= count)
                        return words.join(" ");
                    return "... " + words.slice(words.length - count).join(" ");
                }

                function cycleModel(delta) {
                    var models = AiChatConfig.models ?? [];
                    if (models.length === 0)
                        return;
                    selectedModelIndex = (selectedModelIndex + delta + models.length) % models.length;
                }

                function currentModelLabel() {
                    var models = AiChatConfig.models ?? [];
                    if (models.length === 0)
                        return "No models configured";
                    var i = Math.max(0, Math.min(selectedModelIndex, models.length - 1));
                    return models[i].label ? String(models[i].label) : String(models[i].id);
                }

                function sendPrompt() {
                    if (requestPending)
                        return;

                    var prompt = inputEdit.text.trim();
                    if (prompt.length === 0)
                        return;

                    appendMessage("user", prompt, "");
                    inputEdit.text = "";
                    requestPending = true;
                    pendingModelLabel = currentModelLabel();

                    var modelId = root.selectedModelId(selectedModelIndex);
                    var history = JSON.stringify(messages.map(m => ({ role: m.role, content: m.content })));

                    requestProc.outputBuffer = "";
                    requestProc.command = [
                        "bash",
                        "-lc",
                        "QS_MODEL=" + root.shellEscape(modelId) + " " +
                        "QS_HISTORY=" + root.shellEscape(history) + " " +
                        "QS_SYSTEM=" + root.shellEscape(AiChatConfig.systemPrompt) + " " +
                        "QS_OR_SITE=" + root.shellEscape(AiChatConfig.siteUrl) + " " +
                        "QS_OR_TITLE=" + root.shellEscape(AiChatConfig.appTitle) + " " +
                        "python3 - <<'PY'\n" +
                        "import json, os, sys, urllib.request, urllib.error\n" +
                        "api = os.environ.get('OPENROUTER_API_KEY', '').strip()\n" +
                        "if not api:\n" +
                        "    print('__ERR__ Missing OPENROUTER_API_KEY')\n" +
                        "    raise SystemExit(0)\n" +
                        "model = os.environ.get('QS_MODEL', 'openai/gpt-4o-mini')\n" +
                        "system_prompt = os.environ.get('QS_SYSTEM', '').strip()\n" +
                        "site = os.environ.get('QS_OR_SITE', 'https://localhost')\n" +
                        "title = os.environ.get('QS_OR_TITLE', 'Quickshell AI Chat')\n" +
                        "try:\n" +
                        "    history = json.loads(os.environ.get('QS_HISTORY', '[]'))\n" +
                        "except Exception:\n" +
                        "    history = []\n" +
                        "msgs = []\n" +
                        "if system_prompt:\n" +
                        "    msgs.append({'role': 'system', 'content': system_prompt})\n" +
                        "for m in history:\n" +
                        "    role = m.get('role', 'user')\n" +
                        "    if role not in ('user', 'assistant', 'system'):\n" +
                        "        role = 'user'\n" +
                        "    msgs.append({'role': role, 'content': str(m.get('content', ''))})\n" +
                        "payload = {'model': model, 'messages': msgs}\n" +
                        "req = urllib.request.Request(\n" +
                        "    'https://openrouter.ai/api/v1/chat/completions',\n" +
                        "    data=json.dumps(payload).encode('utf-8'),\n" +
                        "    headers={\n" +
                        "        'Authorization': f'Bearer {api}',\n" +
                        "        'Content-Type': 'application/json',\n" +
                        "        'HTTP-Referer': site,\n" +
                        "        'X-Title': title,\n" +
                        "    }\n" +
                        ")\n" +
                        "try:\n" +
                        "    with urllib.request.urlopen(req, timeout=90) as resp:\n" +
                        "        body = resp.read().decode('utf-8', 'replace')\n" +
                        "except urllib.error.HTTPError as e:\n" +
                        "    detail = e.read().decode('utf-8', 'replace')\n" +
                        "    print(f'__ERR__ HTTP {e.code}: {detail}')\n" +
                        "    raise SystemExit(0)\n" +
                        "except Exception as e:\n" +
                        "    print(f'__ERR__ {e}')\n" +
                        "    raise SystemExit(0)\n" +
                        "try:\n" +
                        "    data = json.loads(body)\n" +
                        "    choices = data.get('choices') or []\n" +
                        "    content = ''\n" +
                        "    reasoning = ''\n" +
                        "    if choices:\n" +
                        "        c0 = choices[0] or {}\n" +
                        "        msg = c0.get('message') or {}\n" +
                        "        content = msg.get('content')\n" +
                        "        if isinstance(content, list):\n" +
                        "            parts = []\n" +
                        "            for item in content:\n" +
                        "                if isinstance(item, dict) and item.get('type') == 'text':\n" +
                        "                    parts.append(str(item.get('text', '')))\n" +
                        "            content = ''.join(parts)\n" +
                        "        reasoning = msg.get('reasoning') or msg.get('reasoning_content') or c0.get('reasoning') or ''\n" +
                        "        if isinstance(reasoning, list):\n" +
                        "            rparts = []\n" +
                        "            for item in reasoning:\n" +
                        "                if isinstance(item, dict):\n" +
                        "                    if item.get('type') == 'text':\n" +
                        "                        rparts.append(str(item.get('text', '')))\n" +
                        "                    else:\n" +
                        "                        rparts.append(str(item.get('content', '')))\n" +
                        "                else:\n" +
                        "                    rparts.append(str(item))\n" +
                        "            reasoning = ''.join(rparts)\n" +
                        "    if not content:\n" +
                        "        content = ((data.get('error') or {}).get('message') or '').strip()\n" +
                        "    payload = {'content': content if content else '(no response text)', 'reasoning': reasoning if reasoning else ''}\n" +
                        "    print('__JSON__' + json.dumps(payload, ensure_ascii=False))\n" +
                        "except Exception as e:\n" +
                        "    print(f'__ERR__ Failed to parse response: {e}')\n" +
                        "PY"
                    ];
                    requestProc.running = true;
                }

                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    left: parent.left
                    topMargin: topBarHeight
                    leftMargin: panelOuterMargin
                    bottomMargin: panelOuterMargin
                }
                width: 520
                radius: 16
                color: "#1e1e1e"
                border.width: 1
                border.color: "#3a3a3a"

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    onClicked: mouse => mouse.accepted = true
                }

                Column {
                    id: header

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 8

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "AI Chat"
                        color: "#e6e6e6"
                        font.pixelSize: 16
                        font.bold: true
                    }

                    ComboBox {
                        id: modelCombo

                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(chatPanel.width - 48, 360)
                        model: AiChatConfig.models ?? []
                        textRole: "label"
                        currentIndex: chatPanel.selectedModelIndex

                        onActivated: index => {
                            chatPanel.selectedModelIndex = index;
                        }

                        background: Rectangle {
                            radius: 8
                            color: "#252525"
                            border.width: 1
                            border.color: "#3a3a3a"
                        }

                        contentItem: Text {
                            leftPadding: 10
                            rightPadding: 24
                            verticalAlignment: Text.AlignVCenter
                            text: chatPanel.currentModelLabel()
                            color: "#dcdcdc"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                    }
                }

                Rectangle {
                    id: headerDivider

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: header.bottom
                    anchors.margins: 12
                    height: 1
                    color: "#3a3a3a"
                }

                ListView {
                    id: listView

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: headerDivider.bottom
                    anchors.bottom: inputWrap.top
                    anchors.margins: 12
                    spacing: 8
                    clip: true
                    model: chatPanel.messages

                    delegate: Rectangle {
                        required property var modelData
                        property bool hasReasoning: modelData.reasoning && modelData.reasoning.length > 0
                        property bool reasoningExpanded: false

                        width: listView.width
                        radius: 8
                        color: modelData.role === "user" ? "#2f2f2f" : "#252525"
                        implicitHeight: bubbleColumn.implicitHeight + 14

                        Column {
                            id: bubbleColumn

                            anchors.fill: parent
                            anchors.margins: 7
                            spacing: 6

                            Rectangle {
                                visible: modelData.role === "assistant"
                                width: bubbleColumn.width
                                height: 24
                                radius: 6
                                color: "#1f1f1f"

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: hasReasoning
                                    onClicked: reasoningExpanded = !reasoningExpanded
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 16
                                    elide: Text.ElideRight
                                    color: "#bbbbbb"
                                    font.pixelSize: 10
                                    text: hasReasoning
                                        ? (reasoningExpanded ? "Hide reasoning" : "Show reasoning")
                                        : ("Tail: " + chatPanel.tailWords(modelData.content, 6))
                                }
                            }

                            Rectangle {
                                visible: modelData.role === "assistant" && hasReasoning && reasoningExpanded
                                width: bubbleColumn.width
                                radius: 6
                                color: "#1f1f1f"
                                border.width: 1
                                border.color: "#343434"
                                implicitHeight: reasoningText.implicitHeight + 12

                                TextEdit {
                                    id: reasoningText
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    readOnly: true
                                    selectByMouse: true
                                    text: chatPanel.renderMarkdown(modelData.reasoning)
                                    textFormat: TextEdit.RichText
                                    wrapMode: TextEdit.Wrap
                                    color: "#c6c6c6"
                                    font.pixelSize: 11
                                }
                            }

                            TextEdit {
                                id: contentText

                                width: bubbleColumn.width
                                readOnly: true
                                selectByMouse: true
                                text: chatPanel.renderMarkdown(modelData.content)
                                textFormat: TextEdit.RichText
                                wrapMode: TextEdit.Wrap
                                color: "#e6e6e6"
                                font.pixelSize: 12
                                cursorVisible: false
                            }
                        }
                    }
                }

                Rectangle {
                    id: inputWrap

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 12
                    height: 110
                    radius: 8
                    color: "#252525"
                    border.width: 1
                    border.color: "#3a3a3a"

                    TextEdit {
                        id: inputEdit

                        anchors.left: parent.left
                        anchors.right: sendButton.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: 8
                        anchors.rightMargin: 6
                        color: "#f1f1f1"
                        wrapMode: TextEdit.Wrap
                        font.pixelSize: 13
                        selectByMouse: true

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (event.modifiers & Qt.ShiftModifier)
                                    return;
                                chatPanel.sendPrompt();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Escape) {
                                GlobalStates.aiChatOpen = false;
                                event.accepted = true;
                            }
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: 12
                        text: "Ask anything... (Enter send, Shift+Enter newline)"
                        color: "#9a9a9a"
                        font.pixelSize: 11
                        visible: inputEdit.text.length === 0
                    }

                    Rectangle {
                        id: sendButton

                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 8
                        width: 72
                        height: 28
                        radius: 6
                        color: chatPanel.requestPending ? "#3f3f3f" : "#5a5a5a"

                        Text {
                            anchors.centerIn: parent
                            text: chatPanel.requestPending ? "Wait" : "Send"
                            color: "#f1f1f1"
                            font.pixelSize: 11
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !chatPanel.requestPending
                            onClicked: chatPanel.sendPrompt()
                        }
                    }

                    Row {
                        id: processingIndicator

                        visible: chatPanel.requestPending
                        anchors.right: sendButton.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: sendButton.verticalCenter
                        spacing: 6

                        Text {
                            text: chatPanel.pendingModelLabel.length > 0 ? chatPanel.pendingModelLabel : "Thinking"
                            color: "#b7bcc9"
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            width: 170
                        }

                        Rectangle {
                            width: 5
                            height: 5
                            radius: 3
                            color: "#c7ccda"
                            opacity: 0.25
                            SequentialAnimation on opacity {
                                running: processingIndicator.visible
                                loops: Animation.Infinite
                                NumberAnimation { to: 1.0; duration: 180 }
                                NumberAnimation { to: 0.25; duration: 180 }
                                PauseAnimation { duration: 360 }
                            }
                        }

                        Rectangle {
                            width: 5
                            height: 5
                            radius: 3
                            color: "#c7ccda"
                            opacity: 0.25
                            SequentialAnimation on opacity {
                                running: processingIndicator.visible
                                loops: Animation.Infinite
                                PauseAnimation { duration: 120 }
                                NumberAnimation { to: 1.0; duration: 180 }
                                NumberAnimation { to: 0.25; duration: 180 }
                                PauseAnimation { duration: 240 }
                            }
                        }

                        Rectangle {
                            width: 5
                            height: 5
                            radius: 3
                            color: "#c7ccda"
                            opacity: 0.25
                            SequentialAnimation on opacity {
                                running: processingIndicator.visible
                                loops: Animation.Infinite
                                PauseAnimation { duration: 240 }
                                NumberAnimation { to: 1.0; duration: 180 }
                                NumberAnimation { to: 0.25; duration: 180 }
                                PauseAnimation { duration: 120 }
                            }
                        }
                    }
                }

                FocusScope {
                    anchors.fill: parent
                    focus: GlobalStates.aiChatOpen
                }

                Connections {
                    target: GlobalStates

                    function onAiChatOpenChanged() {
                        if (GlobalStates.aiChatOpen)
                            inputEdit.forceActiveFocus();
                    }
                }

                Process {
                    id: requestProc

                    running: false
                    property string outputBuffer: ""

                    stdout: SplitParser {
                        onRead: data => {
                            requestProc.outputBuffer += data;
                        }
                    }

                    onExited: {
                        chatPanel.requestPending = false;
                        var response = requestProc.outputBuffer.trim();
                        if (response.length === 0)
                            response = "(empty response)";
                        if (response.startsWith("__ERR__"))
                            response = "Error: " + response.substring(7).trim();
                        if (response.startsWith("__JSON__")) {
                            var payloadText = response.substring(8);
                            try {
                                var payload = JSON.parse(payloadText);
                                var content = payload.content ? String(payload.content) : "(no response text)";
                                var reasoning = payload.reasoning ? String(payload.reasoning) : "";
                                chatPanel.appendMessage("assistant", content, reasoning);
                            } catch (e) {
                                chatPanel.appendMessage("assistant", "Error: invalid response payload", "");
                            }
                        } else {
                            chatPanel.appendMessage("assistant", response, "");
                        }
                        requestProc.outputBuffer = "";
                        inputEdit.forceActiveFocus();
                    }
                }
            }

            FocusScope {
                anchors.fill: parent
                focus: GlobalStates.aiChatOpen

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        GlobalStates.aiChatOpen = false;
                        event.accepted = true;
                    }
                }
            }
        }
    }
}
