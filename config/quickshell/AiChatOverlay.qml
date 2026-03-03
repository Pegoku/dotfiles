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
                property bool showReasoning: true
                property bool autoFollowOutput: false
                property string pendingModelLabel: ""
                property int activeAssistantIndex: -1

                function maybeScrollToEnd(force) {
                    if (!force && !autoFollowOutput)
                        return;
                    Qt.callLater(() => {
                        listView.positionViewAtEnd();
                    });
                }

                function nowLabel() {
                    var d = new Date();
                    return d.toLocaleTimeString(Qt.locale(), "h:mm AP");
                }

                function appendMessage(role, content, reasoning) {
                    var text = String(content);
                    var reason = reasoning ? String(reasoning) : "";
                    messages = messages.concat([{ role: role, content: text, reasoning: reason, streaming: false, model: pendingModelLabel, at: nowLabel() }]);
                    maybeScrollToEnd(false);
                }

                function beginAssistantStream() {
                    messages = messages.concat([{ role: "assistant", content: "", reasoning: "", streaming: true, model: pendingModelLabel, at: nowLabel() }]);
                    activeAssistantIndex = messages.length - 1;
                    maybeScrollToEnd(true);
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
                    maybeScrollToEnd(false);
                }

                function finishAssistantStream(fallbackText) {
                    if (activeAssistantIndex >= 0 && activeAssistantIndex < messages.length) {
                        var next = messages.slice();
                        var msg = Object.assign({}, next[activeAssistantIndex]);
                        if ((!msg.content || msg.content.length === 0) && msg.reasoning && msg.reasoning.length > 0)
                            msg.content = "(reasoning available - expand to view)";
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
                        "    print('__QS__' + json.dumps({'type': 'error', 'data': 'Missing OPENROUTER_API_KEY'}, ensure_ascii=False), flush=True)\n" +
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
                        "emitted = [False]\n" +
                        "def emit(kind, data):\n" +
                        "    print('__QS__' + json.dumps({'type': kind, 'data': data}, ensure_ascii=False), flush=True)\n" +
                        "def emit_from_chunk_obj(obj):\n" +
                        "    choices = obj.get('choices') or []\n" +
                        "    if not choices:\n" +
                        "        err = (obj.get('error') or {}).get('message')\n" +
                        "        if err:\n" +
                        "            emit('error', str(err))\n" +
                        "        return\n" +
                        "    emitted[0] = True\n" +
                        "    c0 = choices[0] or {}\n" +
                        "    delta = c0.get('delta') or c0.get('message') or {}\n" +
                        "    content = delta.get('content', '')\n" +
                        "    if isinstance(content, list):\n" +
                        "        parts = []\n" +
                        "        for item in content:\n" +
                        "            if isinstance(item, dict) and item.get('type') == 'text':\n" +
                        "                parts.append(str(item.get('text', '')))\n" +
                        "            elif isinstance(item, dict):\n" +
                        "                parts.append(str(item.get('content', '')))\n" +
                        "            else:\n" +
                        "                parts.append(str(item))\n" +
                        "        content = ''.join(parts)\n" +
                        "    reasoning = delta.get('reasoning') or delta.get('reasoning_content') or c0.get('reasoning') or ''\n" +
                        "    if isinstance(reasoning, list):\n" +
                        "        rparts = []\n" +
                        "        for item in reasoning:\n" +
                        "            if isinstance(item, dict) and item.get('type') == 'text':\n" +
                        "                rparts.append(str(item.get('text', '')))\n" +
                        "            elif isinstance(item, dict):\n" +
                        "                rparts.append(str(item.get('content', '')))\n" +
                        "            else:\n" +
                        "                rparts.append(str(item))\n" +
                        "        reasoning = ''.join(rparts)\n" +
                        "    if content:\n" +
                        "        emit('content', content)\n" +
                        "    if reasoning:\n" +
                        "        emit('reasoning', reasoning)\n" +
                        "try:\n" +
                        "    with urllib.request.urlopen(req, timeout=120) as resp:\n" +
                        "        ctype = (resp.headers.get('Content-Type') or '').lower()\n" +
                        "        if 'text/event-stream' in ctype:\n" +
                        "            buf = ''\n" +
                        "            while True:\n" +
                        "                chunk = resp.read(1024)\n" +
                        "                if not chunk:\n" +
                        "                    break\n" +
                        "                buf += chunk.decode('utf-8', 'replace')\n" +
                        "                while '\\n' in buf:\n" +
                        "                    line, buf = buf.split('\\n', 1)\n" +
                        "                    line = line.strip()\n" +
                        "                    if not line or not line.startswith('data:'):\n" +
                        "                        continue\n" +
                        "                    payload_line = line[5:].strip()\n" +
                        "                    if payload_line == '[DONE]':\n" +
                        "                        break\n" +
                        "                    try:\n" +
                        "                        emit_from_chunk_obj(json.loads(payload_line))\n" +
                        "                    except Exception:\n" +
                        "                        pass\n" +
                        "            if not emitted[0] and buf.strip():\n" +
                        "                try:\n" +
                        "                    raw = buf.strip()\n" +
                        "                    if raw.startswith('data:'):\n" +
                        "                        raw = raw[5:].strip()\n" +
                        "                    if raw and raw != '[DONE]':\n" +
                        "                        emit_from_chunk_obj(json.loads(raw))\n" +
                        "                except Exception:\n" +
                        "                    pass\n" +
                        "        else:\n" +
                        "            body = resp.read().decode('utf-8', 'replace')\n" +
                        "            data = json.loads(body)\n" +
                        "            emit_from_chunk_obj(data)\n" +
                        "        if not emitted[0]:\n" +
                        "            payload2 = {'model': model, 'messages': msgs}\n" +
                        "            req2 = urllib.request.Request(\n" +
                        "                'https://openrouter.ai/api/v1/chat/completions',\n" +
                        "                data=json.dumps(payload2).encode('utf-8'),\n" +
                        "                headers={\n" +
                        "                    'Authorization': f'Bearer {api}',\n" +
                        "                    'Content-Type': 'application/json',\n" +
                        "                    'HTTP-Referer': site,\n" +
                        "                    'X-Title': title,\n" +
                        "                }\n" +
                        "            )\n" +
                        "            try:\n" +
                        "                with urllib.request.urlopen(req2, timeout=120) as resp2:\n" +
                        "                    body2 = resp2.read().decode('utf-8', 'replace')\n" +
                        "                emit_from_chunk_obj(json.loads(body2))\n" +
                        "            except Exception as e:\n" +
                        "                emit('error', str(e))\n" +
                        "except urllib.error.HTTPError as e:\n" +
                        "    detail = e.read().decode('utf-8', 'replace')\n" +
                        "    emit('error', f'HTTP {e.code}: {detail}')\n" +
                        "    raise SystemExit(0)\n" +
                        "except Exception as e:\n" +
                        "    emit('error', str(e))\n" +
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

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8

                        Rectangle {
                            width: 144
                            height: 24
                            radius: 6
                            color: chatPanel.showReasoning ? "#2b3447" : "#232323"
                            border.width: 1
                            border.color: chatPanel.showReasoning ? "#5a6e98" : "#3a3a3a"

                            Text {
                                anchors.centerIn: parent
                                text: chatPanel.showReasoning ? "Reasoning: On" : "Reasoning: Off"
                                color: "#d7deee"
                                font.pixelSize: 10
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: chatPanel.showReasoning = !chatPanel.showReasoning
                            }
                        }

                        Rectangle {
                            width: 144
                            height: 24
                            radius: 6
                            color: chatPanel.autoFollowOutput ? "#274233" : "#232323"
                            border.width: 1
                            border.color: chatPanel.autoFollowOutput ? "#4f8b6e" : "#3a3a3a"

                            Text {
                                anchors.centerIn: parent
                                text: chatPanel.autoFollowOutput ? "Follow Output: On" : "Follow Output: Off"
                                color: "#d7deee"
                                font.pixelSize: 10
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    chatPanel.autoFollowOutput = !chatPanel.autoFollowOutput
                                    if (chatPanel.autoFollowOutput)
                                        chatPanel.maybeScrollToEnd(true)
                                }
                            }
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
                        property bool hasReasoningRaw: modelData.reasoning && modelData.reasoning.length > 0
                        property bool hasReasoning: chatPanel.showReasoning && hasReasoningRaw
                        property bool hasContent: modelData.content && modelData.content.trim().length > 0
                        property bool showLiveReasoning: isAssistant && modelData.streaming && !hasContent && hasReasoning
                        property bool reasoningExpanded: false
                        property bool isAssistant: modelData.role === "assistant"

                        width: listView.width
                        radius: 8
                        color: isAssistant ? "transparent" : "#252525"
                        implicitHeight: bubbleColumn.implicitHeight + 14

                        Column {
                            id: bubbleColumn

                            anchors.fill: parent
                            anchors.margins: 7
                            spacing: 6

                            Rectangle {
                                visible: isAssistant
                                width: bubbleColumn.width
                                height: modelMeta.implicitHeight
                                color: "transparent"

                                Row {
                                    id: modelMeta
                                    spacing: 8

                                    Text {
                                        text: modelData.model && modelData.model.length > 0 ? modelData.model : chatPanel.currentModelLabel()
                                        color: "#e3e7f0"
                                        font.pixelSize: 12
                                        font.bold: true
                                    }

                                    Text {
                                        text: modelData.at ? "Today at " + modelData.at : ""
                                        color: "#9aa3b7"
                                        font.pixelSize: 11
                                    }
                                }
                            }

                            Rectangle {
                                visible: isAssistant && modelData.streaming && !showLiveReasoning
                                width: bubbleColumn.width
                                height: 24
                                radius: 6
                                color: "#161b25"

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Thinking..."
                                    color: "#98a2b8"
                                    font.pixelSize: 10
                                }
                            }

                            Rectangle {
                                visible: isAssistant && !modelData.streaming
                                width: bubbleColumn.width
                                height: 24
                                radius: 6
                                color: "#161b25"

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
                                    color: "#98a2b8"
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

                            Rectangle {
                                visible: showLiveReasoning
                                width: bubbleColumn.width
                                radius: 6
                                color: "#1f1f1f"
                                border.width: 1
                                border.color: "#343434"
                                implicitHeight: liveReasoningColumn.implicitHeight + 12

                                Column {
                                    id: liveReasoningColumn

                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 6

                                    Text {
                                        width: parent.width
                                        text: "Thinking..."
                                        color: "#98a2b8"
                                        font.pixelSize: 10
                                    }

                                    Repeater {
                                        model: chatPanel.parseMarkdownBlocks(modelData.reasoning)

                                        delegate: Item {
                                            required property var modelData

                                            width: liveReasoningColumn.width
                                            implicitHeight: modelData.type === "code" ? liveReasonCodeBox.implicitHeight : liveReasonText.implicitHeight

                                            TextEdit {
                                                id: liveReasonText

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
                                                id: liveReasonCodeBox
                                                property bool copied: false

                                                visible: modelData.type === "code"
                                                width: parent.width
                                                radius: 6
                                                color: "#151515"
                                                border.width: 1
                                                border.color: "#3c3c3c"
                                                implicitHeight: liveReasonCodeText.implicitHeight + 34

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
                                                            text: liveReasonCodeBox.copied ? "Copied" : "Copy"
                                                            color: "#e1e1e1"
                                                            font.pixelSize: 9
                                                        }

                                                        MouseArea {
                                                            anchors.fill: parent
                                                            onClicked: {
                                                                chatPanel.copyToClipboard(modelData.text)
                                                                liveReasonCodeBox.copied = true
                                                                liveReasonCopyTimer.restart()
                                                            }
                                                        }
                                                    }
                                                }

                                                Timer {
                                                    id: liveReasonCopyTimer
                                                    interval: 1200
                                                    repeat: false
                                                    onTriggered: liveReasonCodeBox.copied = false
                                                }

                                                TextEdit {
                                                    id: liveReasonCodeText

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

                    function processStreamBuffer(flush) {
                        var marker = "__QS__";
                        var buf = requestProc.streamBuffer;

                        function parseJsonObjectEnd(text, startIndex) {
                            var depth = 0;
                            var inString = false;
                            var escaped = false;

                            for (var i = startIndex; i < text.length; i++) {
                                var ch = text.charAt(i);

                                if (inString) {
                                    if (escaped)
                                        escaped = false;
                                    else if (ch === "\\")
                                        escaped = true;
                                    else if (ch === "\"")
                                        inString = false;
                                    continue;
                                }

                                if (ch === "\"") {
                                    inString = true;
                                    continue;
                                }

                                if (ch === "{")
                                    depth++;
                                else if (ch === "}") {
                                    depth--;
                                    if (depth === 0)
                                        return i + 1;
                                }
                            }

                            return -1;
                        }

                        while (true) {
                            var start = buf.indexOf(marker);

                            if (start === -1) {
                                if (flush) {
                                    if (buf.trim().length > 0)
                                        requestProc.outputBuffer += buf;
                                    buf = "";
                                } else {
                                    var keep = Math.min(marker.length - 1, buf.length);
                                    var passthrough = buf.slice(0, buf.length - keep);
                                    if (passthrough.trim().length > 0)
                                        requestProc.outputBuffer += passthrough;
                                    buf = buf.slice(buf.length - keep);
                                }
                                break;
                            }

                            if (start > 0) {
                                var leading = buf.slice(0, start);
                                if (leading.trim().length > 0)
                                    requestProc.outputBuffer += leading;
                                buf = buf.slice(start);
                            }

                            var jsonStart = marker.length;
                            while (jsonStart < buf.length && /\s/.test(buf.charAt(jsonStart)))
                                jsonStart++;

                            if (jsonStart >= buf.length || buf.charAt(jsonStart) !== "{") {
                                if (!flush)
                                    break;
                                requestProc.outputBuffer += buf;
                                buf = "";
                                break;
                            }

                            var jsonEnd = parseJsonObjectEnd(buf, jsonStart);
                            if (jsonEnd === -1) {
                                if (!flush)
                                    break;
                                requestProc.outputBuffer += buf;
                                buf = "";
                                break;
                            }

                            var payload = buf.slice(jsonStart, jsonEnd);
                            try {
                                var event = JSON.parse(payload);
                                var kind = String(event.type || "");
                                var data = String(event.data || "");

                                if (kind === "content")
                                    chatPanel.appendAssistantStream(data, "");
                                else if (kind === "reasoning")
                                    chatPanel.appendAssistantStream("", data);
                                else if (kind === "error")
                                    requestProc.lastError = data;
                            } catch (e) {
                                requestProc.outputBuffer += payload;
                            }

                            buf = buf.slice(jsonEnd);
                        }

                        requestProc.streamBuffer = buf;
                    }

                    stdout: SplitParser {
                        onRead: data => {
                            requestProc.streamBuffer += data;
                            requestProc.processStreamBuffer(false);
                        }
                    }

                    onExited: {
                        chatPanel.requestPending = false;
                        requestProc.processStreamBuffer(true);

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
