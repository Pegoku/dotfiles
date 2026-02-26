import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "./services"

Scope {
    id: root

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
                opacity: 0.35

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

                function appendMessage(role, content) {
                    var text = String(content);
                    messages = messages.concat([{ role: role, content: text }]);
                    Qt.callLater(() => {
                        listView.positionViewAtEnd();
                    });
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

                    appendMessage("user", prompt);
                    inputEdit.text = "";
                    requestPending = true;

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
                        "    if choices:\n" +
                        "        msg = choices[0].get('message') or {}\n" +
                        "        content = msg.get('content')\n" +
                        "        if isinstance(content, list):\n" +
                        "            parts = []\n" +
                        "            for item in content:\n" +
                        "                if isinstance(item, dict) and item.get('type') == 'text':\n" +
                        "                    parts.append(str(item.get('text', '')))\n" +
                        "            content = ''.join(parts)\n" +
                        "    if not content:\n" +
                        "        content = ((data.get('error') or {}).get('message') or '').strip()\n" +
                        "    print(content if content else '(no response text)')\n" +
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
                    topMargin: 40
                }
                width: 520
                color: "#16181f"
                border.width: 1
                border.color: "#2f3442"

                Row {
                    id: header

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 8

                    Text {
                        text: "AI Chat"
                        color: "#f0f3ff"
                        font.pixelSize: 16
                        font.bold: true
                    }

                    Item { width: Math.max(0, chatPanel.width - 300); height: 1 }

                    Rectangle {
                        width: 22
                        height: 22
                        radius: 5
                        color: "#2a3040"
                        Text { anchors.centerIn: parent; text: "<"; color: "#d2d8ea"; font.pixelSize: 12 }
                        MouseArea { anchors.fill: parent; onClicked: chatPanel.cycleModel(-1) }
                    }

                    Rectangle {
                        height: 22
                        radius: 5
                        color: "#232937"
                        implicitWidth: modelLabel.implicitWidth + 16
                        Text {
                            id: modelLabel
                            anchors.centerIn: parent
                            text: chatPanel.currentModelLabel()
                            color: "#e4e9f7"
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        width: 22
                        height: 22
                        radius: 5
                        color: "#2a3040"
                        Text { anchors.centerIn: parent; text: ">"; color: "#d2d8ea"; font.pixelSize: 12 }
                        MouseArea { anchors.fill: parent; onClicked: chatPanel.cycleModel(1) }
                    }

                    Rectangle {
                        width: 22
                        height: 22
                        radius: 5
                        color: "#3b2930"
                        Text { anchors.centerIn: parent; text: "x"; color: "#f1d8df"; font.pixelSize: 11 }
                        MouseArea { anchors.fill: parent; onClicked: GlobalStates.aiChatOpen = false }
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: header.bottom
                    anchors.margins: 12
                    height: 1
                    color: "#2e3546"
                }

                ListView {
                    id: listView

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: header.bottom
                    anchors.bottom: inputWrap.top
                    anchors.margins: 12
                    spacing: 8
                    clip: true
                    model: chatPanel.messages

                    delegate: Rectangle {
                        required property var modelData

                        width: listView.width
                        radius: 8
                        color: modelData.role === "user" ? "#29395e" : "#202637"
                        implicitHeight: msgText.implicitHeight + 14

                        Text {
                            id: msgText
                            anchors.fill: parent
                            anchors.margins: 7
                            text: modelData.content
                            wrapMode: Text.Wrap
                            color: "#e8ecfa"
                            font.pixelSize: 12
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
                    color: "#1f2433"
                    border.width: 1
                    border.color: "#32405a"

                    TextEdit {
                        id: inputEdit

                        anchors.left: parent.left
                        anchors.right: sendButton.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: 8
                        anchors.rightMargin: 6
                        color: "#f4f7ff"
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
                        color: "#7f8aa7"
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
                        color: chatPanel.requestPending ? "#3b465f" : "#4464a8"

                        Text {
                            anchors.centerIn: parent
                            text: chatPanel.requestPending ? "Wait" : "Send"
                            color: "#f1f4ff"
                            font.pixelSize: 11
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !chatPanel.requestPending
                            onClicked: chatPanel.sendPrompt()
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
                        chatPanel.appendMessage("assistant", response);
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
