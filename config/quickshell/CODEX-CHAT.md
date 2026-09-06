# Desktop Codex

Super+B opens the chat along the left edge of the focused monitor. Click inside
to type, or click any other app to keep using your desktop while Codex works.
The panel does not dim the desktop or grab exclusive keyboard focus. Escape
(while the panel has focus), Super+B, or the close button hides it; work continues
in the background. Enter sends, Shift+Enter adds a line.
Stop interrupts the active turn. New chat starts a fresh context; the outlined conversation cards
reopen previous conversations. History toggles the sidebar to give replies more room.

Requires Python 3 and a Codex CLI with the v2 app-server protocol (tested with
0.153.4). Run `codex login` to sign in with ChatGPT, then click Reconnect.
The account header shows the detected subscription. API-key accounts are
rejected; OpenRouter is no longer used. Normal subscription limits apply.

The folder field controls where Codex runs commands and edits files. The CLI
model and reasoning configuration are used initially, with the actual model
name displayed. The themed model menu and supported reasoning levels come from
your installed CLI. Selecting a model resets the slider to its recommended
reasoning level; you can then adjust it before sending. Existing threads restore
their model and reasoning settings when reopened. Defaults can be set in
`services/AiChatConfig.qml` and `~/.codex/config.toml`.

Replies default to English, including short prompts such as “test”. Ask explicitly
for another language when wanted. This preference is added to the CLI’s configured
developer instructions for both new and resumed conversations.

The bridge uses `codex app-server` over private stdin/stdout pipes, with live
web search, the OpenAI provider, workspace-write sandboxing and on-request
approvals. Command, file-change and permission requests appear in the panel
with Allow once / Deny controls. Tools needing user input show a reply form.
Configured MCP tools are available through Codex. Unsupported server interaction
methods return an explicit error instead of silently approving or hanging.

Replies support Markdown, selection, copying and HTTP(S) links. Tool cards
expand to show commands, output and diffs. Individual tool outputs are capped at
60,000 characters in the display; full history remains in Codex's own storage.
Scrolling up pauses automatic following; Latest resumes it.

A private index of the latest 50 chats is stored at
`$XDG_STATE_HOME/quickshell/codex-chat.json` (default `~/.local/state`).
Transcripts stay in Codex. No credentials are read or copied by the panel.
The bridge starts on first open and survives hiding the panel; a shell reload
stops it. After a reload or reconnect, select a saved chat to resume.

Protocol: https://learn.chatgpt.com/docs/app-server

Run the bridge regression tests without making model requests:

```sh
PYTHONDONTWRITEBYTECODE=1 python -m unittest discover -s config/quickshell/tests -v
```
