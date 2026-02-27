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
                property int activeAssistantIndex: -1

                function appendMessage(role, content, reasoning) {
                    var text = String(content);
                    var reason = reasoning ? String(reasoning) : "";
                    messages = messages.concat([{ role: role, content: text, reasoning: reason }]);
                    Qt.callLater(() => {
                        listView.positionViewAtEnd();
                    });
                }

                function beginAssistantStream() {
                    messages = messages.concat([{ role: "assistant", content: "", reasoning: "", streaming: true }]);
                    activeAssistantIndex = messages.length - 1;
                    Qt.callLater(() => {
                        listView.positionViewAtEnd();
                    });
                }

                function appendAssistantStream(contentChunk, reasoningChunk) {
                    if (activeAssistantIndex < 0 || activeAssistantIndex >= messages.length)
                        return;

                    var next = messages.slice();
                    var msg = Object.assign({}, next[activeAssistantIndex]);

                    if (contentChunk && contentChunk.length > 0)
                        msg.content = String(msg.content || "") + String(contentChunk);
                    if (reasoningChunk && reasoningChunk.length > 0)
                        msg.reasoning = String(msg.reasoning || "") + String(reasoningChunk);

                    next[activeAssistantIndex] = msg;
                    messages = next;

                    Qt.callLater(() => {
                        listView.positionViewAtEnd();
                    });
                }

                function finishAssistantStream(fallbackText) {
                    if (activeAssistantIndex >= 0 && activeAssistantIndex < messages.length) {
                        var next = messages.slice();
                        var msg = Object.assign({}, next[activeAssistantIndex]);
                        if ((!msg.content || msg.content.length === 0) && fallbackText && fallbackText.length > 0)
                            msg.content = fallbackText;
                        msg.streaming = false;
                        next[activeAssistantIndex] = msg;
                        messages = next;
                    } else if (fallbackText && fallbackText.length > 0) {
                        appendMessage("assistant", fallbackText, "");
                    }

                    activeAssistantIndex = -1;
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

                    if (inUl)
                        html += "</ul>";
                    if (inOl)
                        html += "</ol>";

                    return html;
                }

                function parseMarkdownBlocks(text) {
                    var lines = String(text).replace(/\r\n/g, "\n").split("\n");
                    var blocks = [];
                    var textBuffer = [];
                    var codeBuffer = [];
                    var inCode = false;
                    var codeLang = "";

                    function flushText() {
                        if (textBuffer.length === 0)
                            return;
                        blocks.push({ type: "text", text: textBuffer.join("\n") });
                        textBuffer = [];
                    }

                    function flushCode() {
                        blocks.push({ type: "code", lang: codeLang, text: codeBuffer.join("\n") });
                        codeBuffer = [];
                        codeLang = "";
                    }

                    for (var i = 0; i < lines.length; i++) {
                        var line = lines[i];
                        var trimmed = line.trim();

                        if (trimmed.startsWith("```")) {
                            if (!inCode) {
                                flushText();
                                inCode = true;
                                codeLang = trimmed.slice(3).trim();
                            } else {
                                flushCode();
                                inCode = false;
                            }
                            continue;
                        }

                        if (inCode)
                            codeBuffer.push(line);
                        else
                            textBuffer.push(line);
                    }

                    if (inCode)
                        flushCode();
                    flushText();

                    if (blocks.length === 0)
                        blocks.push({ type: "text", text: "" });

                    return blocks;
                }

                function copyToClipboard(text) {
                    var escaped = root.shellEscape(String(text));
                    Quickshell.execDetached([
                        "bash",
                        "-lc",
                        "printf %s " + escaped + " | (wl-copy || xclip -selection clipboard || xsel --clipboard --input)"
                    ]);
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
                    requestProc.streamBuffer = "";
                    requestProc.lastError = "";
                    chatPanel.beginAssistantStream();
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
                        "payload = {'model': model, 'messages': msgs, 'stream': True}\n" +
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
                        "    with urllib.request.urlopen(req, timeout=120) as resp:\n" +
                        "        for raw in resp:\n" +
                        "            line = raw.decode('utf-8', 'replace').strip()\n" +
                        "            if not line or not line.startswith('data:'):\n" +
                        "                continue\n" +
                        "            payload_line = line[5:].strip()\n" +
                        "            if payload_line == '[DONE]':\n" +
                        "                break\n" +
                        "            try:\n" +
                        "                data = json.loads(payload_line)\n" +
                        "            except Exception:\n" +
                        "                continue\n" +
                        "            choices = data.get('choices') or []\n" +
                        "            if not choices:\n" +
                        "                continue\n" +
                        "            c0 = choices[0] or {}\n" +
                        "            delta = c0.get('delta') or {}\n" +
                        "            content = delta.get('content', '')\n" +
                        "            if isinstance(content, list):\n" +
                        "                parts = []\n" +
                        "                for item in content:\n" +
                        "                    if isinstance(item, dict) and item.get('type') == 'text':\n" +
                        "                        parts.append(str(item.get('text', '')))\n" +
                        "                    elif isinstance(item, dict):\n" +
                        "                        parts.append(str(item.get('content', '')))\n" +
                        "                    else:\n" +
                        "                        parts.append(str(item))\n" +
                        "                content = ''.join(parts)\n" +
                        "            reasoning = delta.get('reasoning') or delta.get('reasoning_content') or c0.get('reasoning') or ''\n" +
                        "            if isinstance(reasoning, list):\n" +
                        "                rparts = []\n" +
                        "                for item in reasoning:\n" +
                        "                    if isinstance(item, dict) and item.get('type') == 'text':\n" +
                        "                        rparts.append(str(item.get('text', '')))\n" +
                        "                    elif isinstance(item, dict):\n" +
                        "                        rparts.append(str(item.get('content', '')))\n" +
                        "                    else:\n" +
                        "                        rparts.append(str(item))\n" +
                        "                reasoning = ''.join(rparts)\n" +
                        "            if content:\n" +
                        "                print('__STREAM_CONTENT__' + json.dumps(content, ensure_ascii=False), flush=True)\n" +
                        "            if reasoning:\n" +
                        "                print('__STREAM_REASONING__' + json.dumps(reasoning, ensure_ascii=False), flush=True)\n" +
                        "except urllib.error.HTTPError as e:\n" +
                        "    detail = e.read().decode('utf-8', 'replace')\n" +
                        "    print(f'__ERR__ HTTP {e.code}: {detail}')\n" +
                        "    raise SystemExit(0)\n" +
                        "except Exception as e:\n" +
                        "    print(f'__ERR__ {e}')\n" +
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
                                implicitHeight: reasoningBlocksColumn.implicitHeight + 12

                                Column {
                                    id: reasoningBlocksColumn

                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 6

                                    Repeater {
                                        model: chatPanel.parseMarkdownBlocks(modelData.reasoning)

                                        delegate: Item {
                                            required property var modelData

                                            width: reasoningBlocksColumn.width
                                            implicitHeight: modelData.type === "code" ? reasonCodeBox.implicitHeight : reasonText.implicitHeight

                                            TextEdit {
                                                id: reasonText

                                                visible: modelData.type === "text"
                                                width: parent.width
                                                readOnly: true
                                                selectByMouse: true
                                                text: chatPanel.renderMarkdown(modelData.text)
                                                textFormat: TextEdit.RichText
                                                wrapMode: TextEdit.Wrap
                                                color: "#c6c6c6"
                                                font.pixelSize: 11
                                            }

                                            Rectangle {
                                                id: reasonCodeBox
                                                property bool copied: false

                                                visible: modelData.type === "code"
                                                width: parent.width
                                                radius: 6
                                                color: "#151515"
                                                border.width: 1
                                                border.color: "#3c3c3c"
                                                implicitHeight: reasonCodeText.implicitHeight + 34

                                                Rectangle {
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    anchors.top: parent.top
                                                    height: 24
                                                    radius: 6
                                                    color: "#202020"

                                                    Text {
                                                        anchors.left: parent.left
                                                        anchors.leftMargin: 8
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        text: modelData.lang && modelData.lang.length > 0 ? modelData.lang : "code"
                                                        color: "#bcbcbc"
                                                        font.pixelSize: 10
                                                    }

                                                    Rectangle {
                                                        anchors.right: parent.right
                                                        anchors.rightMargin: 6
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        width: 46
                                                        height: 16
                                                        radius: 4
                                                        color: "#2f2f2f"

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: reasonCodeBox.copied ? "Copied" : "Copy"
                                                            color: "#e1e1e1"
                                                            font.pixelSize: 9
                                                        }

                                                        MouseArea {
                                                            anchors.fill: parent
                                                            onClicked: {
                                                                chatPanel.copyToClipboard(modelData.text)
                                                                reasonCodeBox.copied = true
                                                                reasonCopyTimer.restart()
                                                            }
                                                        }
                                                    }
                                                }

                                                Timer {
                                                    id: reasonCopyTimer
                                                    interval: 1200
                                                    repeat: false
                                                    onTriggered: reasonCodeBox.copied = false
                                                }

                                                TextEdit {
                                                    id: reasonCodeText

                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    anchors.top: parent.top
                                                    anchors.topMargin: 24
                                                    anchors.margins: 6
                                                    readOnly: true
                                                    selectByMouse: true
                                                    text: modelData.text
                                                    textFormat: TextEdit.PlainText
                                                    wrapMode: TextEdit.Wrap
                                                    color: "#e0e0e0"
                                                    font.pixelSize: 11
                                                    font.family: "monospace"
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Column {
                                id: contentBlocksColumn

                                width: bubbleColumn.width
                                spacing: 6

                                Repeater {
                                    model: chatPanel.parseMarkdownBlocks(modelData.content)

                                    delegate: Item {
                                        required property var modelData

                                        width: contentBlocksColumn.width
                                        implicitHeight: modelData.type === "code" ? codeBox.implicitHeight : contentText.implicitHeight

                                        TextEdit {
                                            id: contentText

                                            visible: modelData.type === "text"
                                            width: parent.width
                                            readOnly: true
                                            selectByMouse: true
                                            text: chatPanel.renderMarkdown(modelData.text)
                                            textFormat: TextEdit.RichText
                                            wrapMode: TextEdit.Wrap
                                            color: "#e6e6e6"
                                            font.pixelSize: 12
                                            cursorVisible: false
                                        }

                                        Rectangle {
                                            id: codeBox
                                            property bool copied: false

                                            visible: modelData.type === "code"
                                            width: parent.width
                                            radius: 6
                                            color: "#151515"
                                            border.width: 1
                                            border.color: "#3c3c3c"
                                            implicitHeight: codeText.implicitHeight + 34

                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.top: parent.top
                                                height: 24
                                                radius: 6
                                                color: "#202020"

                                                Text {
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 8
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: modelData.lang && modelData.lang.length > 0 ? modelData.lang : "code"
                                                    color: "#bcbcbc"
                                                    font.pixelSize: 10
                                                }

                                                Rectangle {
                                                    anchors.right: parent.right
                                                    anchors.rightMargin: 6
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 46
                                                    height: 16
                                                    radius: 4
                                                    color: "#2f2f2f"

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: codeBox.copied ? "Copied" : "Copy"
                                                        color: "#e1e1e1"
                                                        font.pixelSize: 9
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        onClicked: {
                                                            chatPanel.copyToClipboard(modelData.text)
                                                            codeBox.copied = true
                                                            codeCopyTimer.restart()
                                                        }
                                                    }
                                                }
                                            }

                                            Timer {
                                                id: codeCopyTimer
                                                interval: 1200
                                                repeat: false
                                                onTriggered: codeBox.copied = false
                                            }

                                            TextEdit {
                                                id: codeText

                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.top: parent.top
                                                anchors.topMargin: 24
                                                anchors.margins: 6
                                                readOnly: true
                                                selectByMouse: true
                                                text: modelData.text
                                                textFormat: TextEdit.PlainText
                                                wrapMode: TextEdit.Wrap
                                                color: "#e0e0e0"
                                                font.pixelSize: 11
                                                font.family: "monospace"
                                            }
                                        }
                                    }
                                }
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
                    property string streamBuffer: ""
                    property string lastError: ""

                    stdout: SplitParser {
                        onRead: data => {
                            requestProc.streamBuffer += data;

                            var idx = requestProc.streamBuffer.indexOf("\n");
                            while (idx !== -1) {
                                var line = requestProc.streamBuffer.slice(0, idx).trim();
                                requestProc.streamBuffer = requestProc.streamBuffer.slice(idx + 1);

                                if (line.startsWith("__STREAM_CONTENT__")) {
                                    try {
                                        var c = JSON.parse(line.substring(17));
                                        chatPanel.appendAssistantStream(String(c), "");
                                    } catch (e) {
                                    }
                                } else if (line.startsWith("__STREAM_REASONING__")) {
                                    try {
                                        var r = JSON.parse(line.substring(19));
                                        chatPanel.appendAssistantStream("", String(r));
                                    } catch (e) {
                                    }
                                } else if (line.startsWith("__ERR__")) {
                                    requestProc.lastError = line.substring(7).trim();
                                } else if (line.length > 0) {
                                    requestProc.outputBuffer += line + "\n";
                                }

                                idx = requestProc.streamBuffer.indexOf("\n");
                            }
                        }
                    }

                    onExited: {
                        chatPanel.requestPending = false;
                        if (requestProc.streamBuffer.trim().length > 0) {
                            var tailLine = requestProc.streamBuffer.trim();
                            if (tailLine.startsWith("__STREAM_CONTENT__")) {
                                try {
                                    var tc = JSON.parse(tailLine.substring(17));
                                    chatPanel.appendAssistantStream(String(tc), "");
                                } catch (e) {
                                }
                            } else if (tailLine.startsWith("__STREAM_REASONING__")) {
                                try {
                                    var tr = JSON.parse(tailLine.substring(19));
                                    chatPanel.appendAssistantStream("", String(tr));
                                } catch (e) {
                                }
                            } else if (tailLine.startsWith("__ERR__")) {
                                requestProc.lastError = tailLine.substring(7).trim();
                            } else {
                                requestProc.outputBuffer += tailLine;
                            }
                        }

                        var fallback = "";
                        if (requestProc.lastError.length > 0)
                            fallback = "Error: " + requestProc.lastError;
                        else if (requestProc.outputBuffer.trim().length > 0)
                            fallback = requestProc.outputBuffer.trim();
                        else
                            fallback = "(no response text)";

                        chatPanel.finishAssistantStream(fallback);
                        requestProc.outputBuffer = "";
                        requestProc.streamBuffer = "";
                        requestProc.lastError = "";
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
