pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import "./services"

Item {
    id: root
    required property var screen
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property int workspacesShown: 10
    readonly property int rows: 2
    readonly property int columns: 5
    readonly property int focusedWorkspaceId: Math.max(1, monitor.activeWorkspace?.id ?? 1)
    readonly property int workspaceGroupStart: Math.floor((focusedWorkspaceId - 1) / workspacesShown) * workspacesShown + 1
    readonly property real baseScale: 0.15
    readonly property real minScale: 0.08
    readonly property real topClearance: 72
    readonly property real outerMargin: 24
    readonly property real launcherCollapsedHeight: 50
    readonly property real availableWidth: Math.max(320, screen.width - outerMargin * 2)
    readonly property real availableHeight: Math.max(240, screen.height - topClearance - outerMargin * 2)
    readonly property real widthLimitedScale: (availableWidth - padding * 4 - workspaceSpacing * Math.max(0, columns - 1)) / Math.max(1, monitor.width * columns)
    readonly property real heightLimitedScale: (availableHeight - padding * 4 - launcherCollapsedHeight - workspaceSpacing * Math.max(0, rows - 1)) / Math.max(1, monitor.height * rows)
    readonly property real scale: Math.max(minScale, Math.min(baseScale, widthLimitedScale, heightLimitedScale))

    property int draggingFromWorkspace: -1
    property int draggingTargetWorkspace: -1
    
    property real workspaceImplicitWidth: monitor.width * scale
    property real workspaceImplicitHeight: monitor.height * scale
    property real workspaceSpacing: 10
    property real padding: 20
    property int zCounter: 0
    property string appQuery: ""
    property var launcherActions: []
    property var filteredApps: []
    property int selectedAppIndex: 0
    property string activeQueryMode: "auto"
    property string commandProbe: ""
    property bool commandProbeExists: false
    property bool commandProbeResolved: true
    property string commandProbePending: ""
    readonly property bool hasSearchQuery: appQuery.trim().length > 0
    readonly property int resultCount: launcherActions.length + filteredApps.length
    readonly property string adwaitaSymbolicBase: "file:///usr/share/icons/Adwaita/symbolic/"
    readonly property int maxLauncherRows: 7
    readonly property int launcherRowHeight: 32
    readonly property int launcherRowSpacing: 2
    readonly property int launcherListPadding: 4
    readonly property var launcherShortcuts: [
        {
            kind: "shortcut",
            icon: adwaitaSymbolicBase + "legacy/system-search-symbolic.svg",
            title: "App search",
            detail: "Start typing to launch an app",
            value: "",
            keywords: "apps launch desktop entries search"
        },
        {
            kind: "shortcut",
            icon: adwaitaSymbolicBase + "legacy/web-browser-symbolic.svg",
            title: "Open in browser",
            detail: "Prefix with ? to open a URL or search the web",
            value: "? ",
            keywords: "browser web search url link open"
        },
        {
            kind: "shortcut",
            icon: adwaitaSymbolicBase + "legacy/utilities-terminal-symbolic.svg",
            title: "Run command",
            detail: "Prefix with > to run a command in a terminal",
            value: "> ",
            keywords: "command shell terminal exec run"
        },
        {
            kind: "shortcut",
            icon: adwaitaSymbolicBase + "legacy/accessories-calculator-symbolic.svg",
            title: "Calculate",
            detail: "Prefix with = to evaluate and copy a result",
            value: "= ",
            keywords: "calculator calc math evaluate copy"
        },
        {
            kind: "shortcut",
            icon: adwaitaSymbolicBase + "legacy/input-keyboard-symbolic.svg",
            title: "Move selection",
            detail: "Use Up and Down to move through results",
            value: "",
            keywords: "keyboard arrows up down navigation"
        },
        {
            kind: "shortcut",
            icon: adwaitaSymbolicBase + "legacy/input-keyboard-symbolic.svg",
            title: "Launch selection",
            detail: "Press Enter to launch or trigger the selected result",
            value: "",
            keywords: "keyboard enter return activate open"
        },
        {
            kind: "shortcut",
            icon: adwaitaSymbolicBase + "legacy/input-keyboard-symbolic.svg",
            title: "Close launcher",
            detail: "Press Escape to close the overview",
            value: "",
            keywords: "keyboard escape esc close dismiss"
        }
    ]
    readonly property int launcherViewportHeight: {
        var rows = Math.min(maxLauncherRows, resultCount);
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
        return workspaceGroupStart + row * columns + col
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

    function resolveIconSource(iconValue) {
        var icon = iconValue ? String(iconValue) : "";
        if (icon.length === 0)
            return "image://icon/application-x-executable";
        if (icon.indexOf("://") !== -1)
            return icon;
        if (icon.startsWith("/"))
            return "file://" + icon;

        return "image://icon/" + icon;
    }

    function appKeywords(entry) {
        if (!entry || !entry.keywords)
            return "";
        return String(entry.keywords).toLowerCase();
    }

    function parseQuery(text) {
        var raw = String(text).trim();
        var mode = "auto";
        var core = raw;

        if (raw === "?") {
            mode = "shortcuts";
            core = "";
        } else if (raw.startsWith(">")) {
            mode = "command";
            core = raw.slice(1).trim();
        } else if (raw.startsWith("?")) {
            mode = "browser";
            core = raw.slice(1).trim();
        } else if (raw.startsWith("=")) {
            mode = "calc";
            core = raw.slice(1).trim();
        }

        return { mode: mode, core: core };
    }

    function shellEscape(value) {
        return "'" + String(value).replace(/'/g, "'\"'\"'") + "'";
    }

    function isLikelyUrl(text) {
        var t = String(text).trim();
        if (t.length === 0)
            return false;
        if (/^https?:\/\//i.test(t))
            return true;
        return /^[^\s]+\.[^\s]{2,}(\/[^\s]*)?$/i.test(t);
    }

    function normalizeUrl(text) {
        var t = String(text).trim();
        if (/^https?:\/\//i.test(t))
            return t;
        return "https://" + t;
    }

    function evaluateArithmetic(text) {
        var expr = String(text).replace(/\s+/g, "");
        if (!/[0-9]/.test(expr))
            return null;
        if (!/^[0-9+\-*/().%]+$/.test(expr))
            return null;

        try {
            var value = Function("\"use strict\"; return (" + expr + ");")();
            if (typeof value !== "number" || !isFinite(value))
                return null;

            var rounded = Math.abs(value - Math.round(value)) < 1e-10 ? Math.round(value) : Number(value.toFixed(10));
            return String(rounded);
        } catch (e) {
            return null;
        }
    }

    function isLikelyCommand(text) {
        var t = String(text).trim();
        if (t.length === 0)
            return false;
        if (isLikelyUrl(t) || evaluateArithmetic(t) !== null)
            return false;
        if (/[|&;<>]/.test(t) || t.startsWith("./") || t.startsWith("/") || t.startsWith("~"))
            return true;
        return t.indexOf(" ") === -1;
    }

    function commandProbeFor(text) {
        var t = String(text).trim();
        if (!isLikelyCommand(t))
            return "";

        var parts = t.split(/\s+/);
        return parts.length > 0 ? parts[0] : "";
    }

    function requestCommandProbe(text) {
        var probe = commandProbeFor(text);

        if (probe === commandProbe && commandProbeResolved)
            return;

        commandProbe = probe;
        commandProbeExists = false;
        commandProbeResolved = probe.length === 0;
        commandProbePending = probe;

        if (probe.length === 0)
            return;

        if (!commandCheckProc.running)
            startCommandProbeCheck();
    }

    function resultIsAction(index) {
        if (activeQueryMode === "auto")
            return index >= filteredApps.length;
        return true;
    }

    function actionIndexForResult(index) {
        if (activeQueryMode === "auto")
            return index - filteredApps.length;
        return index;
    }

    function appIndexForResult(index) {
        return index;
    }

    function startCommandProbeCheck() {
        if (commandProbePending.length === 0)
            return;

        commandCheckProc.probe = commandProbePending;
        commandProbePending = "";
        commandCheckProc.outputBuffer = "";

        var escaped = shellEscape(commandCheckProc.probe);
        commandCheckProc.command = [
            "bash",
            "-lc",
            "p=" + escaped + "; " +
            "if [[ \"$p\" == ~* ]]; then p=\"${p/#\\~/$HOME}\"; fi; " +
            "if [[ \"$p\" == /* || \"$p\" == ./* || \"$p\" == ../* ]]; then " +
            "[ -x \"$p\" ] && echo YES || echo NO; " +
            "else " +
            "command -v -- \"$p\" >/dev/null 2>&1 && echo YES || echo NO; " +
            "fi"
        ];
        commandCheckProc.running = true;
    }

    function copyToClipboard(text) {
        var escaped = shellEscape(text);
        Quickshell.execDetached(["bash", "-lc", "printf %s " + escaped + " | (wl-copy || xclip -selection clipboard || xsel --clipboard --input)"]);
    }

    function openInBrowser(text) {
        var t = String(text).trim();
        if (t.length === 0)
            return;

        var target = isLikelyUrl(t) ? normalizeUrl(t) : "https://search.brave.com/search?q=" + encodeURIComponent(t);
        Quickshell.execDetached(["xdg-open", target]);
        GlobalStates.setOverviewOpen(false);
    }

    function runCommandInTerminal(text) {
        var t = String(text).trim();
        if (t.length === 0)
            return;

        var escaped = shellEscape(t);
        Quickshell.execDetached([
            "bash",
            "-lc",
            "q=" + escaped + "; term=''; " +
            "for x in kitty alacritty foot wezterm gnome-terminal konsole xterm; do command -v \"$x\" >/dev/null 2>&1 && { term=\"$x\"; break; }; done; " +
            "case \"$term\" in " +
            "kitty) exec kitty -e bash -lc \"$q\" ;; " +
            "alacritty) exec alacritty -e bash -lc \"$q\" ;; " +
            "foot) exec foot -e bash -lc \"$q\" ;; " +
            "wezterm) exec wezterm start -- bash -lc \"$q\" ;; " +
            "gnome-terminal) exec gnome-terminal -- bash -lc \"$q\" ;; " +
            "konsole) exec konsole -e bash -lc \"$q\" ;; " +
            "xterm) exec xterm -e bash -lc \"$q\" ;; " +
            "*) command -v notify-send >/dev/null 2>&1 && notify-send 'Overview launcher' 'No supported terminal found' ;; " +
            "esac"
        ]);
        GlobalStates.setOverviewOpen(false);
    }

    function refreshLauncherActions(mode, coreQuery, appCount, topAppScore) {
        var q = String(coreQuery).trim();

        if (mode === "shortcuts") {
            launcherActions = launcherShortcuts;
            return;
        }

        if (q.length === 0) {
            launcherActions = [];
            return;
        }

        var next = [];

        if (mode === "calc") {
            var prefCalcResult = evaluateArithmetic(q);
            if (prefCalcResult !== null) {
                next.push({
                    kind: "calc",
                    icon: adwaitaSymbolicBase + "legacy/accessories-calculator-symbolic.svg",
                    title: "Calculate",
                    detail: q + " = " + prefCalcResult,
                    value: prefCalcResult
                });
            }

            launcherActions = next;
            return;
        }

        if (mode === "browser") {
            next.push({
                kind: "browser",
                icon: adwaitaSymbolicBase + "legacy/web-browser-symbolic.svg",
                title: "Open in browser",
                detail: isLikelyUrl(q) ? normalizeUrl(q) : "Brave Search: " + q,
                value: q
            });

            launcherActions = next;
            return;
        }

        if (mode === "command") {
            requestCommandProbe(q);
            if (isLikelyCommand(q) && commandProbeFor(q) === commandProbe && commandProbeResolved && commandProbeExists) {
                next.push({
                    kind: "command",
                    icon: adwaitaSymbolicBase + "legacy/utilities-terminal-symbolic.svg",
                    title: "Run command",
                    detail: q,
                    value: q
                });
            }

            launcherActions = next;
            return;
        }

        var calcResult = evaluateArithmetic(q);
        if (calcResult !== null) {
            next.push({
                kind: "calc",
                icon: adwaitaSymbolicBase + "legacy/accessories-calculator-symbolic.svg",
                title: "Calculate",
                detail: q + " = " + calcResult,
                value: calcResult
            });
        }

        if (isLikelyUrl(q) || appCount === 0 || topAppScore < 900) {
            next.push({
                kind: "browser",
                icon: adwaitaSymbolicBase + "legacy/web-browser-symbolic.svg",
                title: "Open in browser",
                detail: isLikelyUrl(q) ? normalizeUrl(q) : "Brave Search: " + q,
                value: q
            });
        }

        requestCommandProbe(q);

        if (isLikelyCommand(q) && commandProbeFor(q) === commandProbe && commandProbeResolved && commandProbeExists && (appCount === 0 || topAppScore < 900)) {
            next.push({
                kind: "command",
                icon: adwaitaSymbolicBase + "legacy/utilities-terminal-symbolic.svg",
                title: "Run command",
                detail: q,
                value: q
            });
        }

        launcherActions = next;
    }

    function activateSelection(index) {
        if (index < 0 || index >= resultCount)
            return;

        if (resultIsAction(index)) {
            var action = launcherActions[actionIndexForResult(index)];
            if (!action)
                return;
            if (action.kind === "calc") {
                copyToClipboard(action.value);
                GlobalStates.setOverviewOpen(false);
            } else if (action.kind === "browser") {
                openInBrowser(action.value);
            } else if (action.kind === "command") {
                runCommandInTerminal(action.value);
            } else if (action.kind === "shortcut") {
                searchInput.text = action.value;
                searchInput.forceActiveFocus();
                searchInput.cursorPosition = searchInput.text.length;
            }
            return;
        }

        launchEntry(filteredApps[appIndexForResult(index)]);
    }

    function appMatches(entry, query) {
        return appScore(entry, query) > 0;
    }

    function fuzzyScore(haystack, needle, bias) {
        if (!haystack || !needle)
            return 0;

        var h = normalizeText(haystack);
        var n = normalizeText(needle);
        if (h.length === 0 || n.length === 0)
            return 0;

        if (h === n)
            return 1200 + bias;
        if (h.startsWith(n))
            return 900 + bias - Math.min(200, h.length - n.length);

        var idx = h.indexOf(n);
        if (idx >= 0)
            return 700 + bias - Math.min(400, idx * 3);

        var score = 0;
        var needlePos = 0;
        var streak = 0;

        for (var i = 0; i < h.length && needlePos < n.length; i++) {
            if (h[i] !== n[needlePos])
                continue;

            score += 12 + streak * 8;
            if (i === 0 || h[i - 1] === ' ' || h[i - 1] === '-' || h[i - 1] === '_' || h[i - 1] === '.')
                score += 14;
            if (needlePos === i)
                score += 6;

            needlePos += 1;
            streak += 1;
        }

        if (needlePos !== n.length)
            return 0;

        return score + bias;
    }

    function appScore(entry, query) {
        if (!entry)
            return 0;

        var best = 0;
        best = Math.max(best, fuzzyScore(entry.name, query, 120));
        best = Math.max(best, fuzzyScore(entry.genericName, query, 80));
        best = Math.max(best, fuzzyScore(entry.id, query, 60));
        best = Math.max(best, fuzzyScore(appKeywords(entry), query, 30));
        best = Math.max(best, fuzzyScore(entry.comment, query, 10));
        return best;
    }

    function refreshFilteredApps() {
        var apps = DesktopEntries.applications?.values ?? [];
        var parsed = parseQuery(appQuery);
        var rawQuery = parsed.core;
        var query = normalizeText(rawQuery);

        activeQueryMode = parsed.mode;

        if (activeQueryMode === "shortcuts") {
            filteredApps = [];
            refreshLauncherActions(activeQueryMode, rawQuery, 0, 0);
            if (selectedAppIndex >= resultCount)
                selectedAppIndex = Math.max(0, resultCount - 1);
            return;
        }

        if (query.length === 0) {
            refreshLauncherActions(activeQueryMode, rawQuery, 0, 0);
            filteredApps = [];
            selectedAppIndex = 0;
            return;
        }

        if (activeQueryMode !== "auto") {
            filteredApps = [];
            refreshLauncherActions(activeQueryMode, rawQuery, 0, 0);
            if (selectedAppIndex >= resultCount)
                selectedAppIndex = Math.max(0, resultCount - 1);
            return;
        }

        var next = [];

        for (var i = 0; i < apps.length; i++) {
            var app = apps[i];
            var score = appScore(app, query);
            if (score > 0)
                next.push({ entry: app, score: score });
        }

        next.sort((a, b) => {
            if (a.score === b.score)
                return normalizeText(a.entry.name).localeCompare(normalizeText(b.entry.name));
            return b.score - a.score;
        });

        filteredApps = next.map(item => item.entry);
        var topScore = next.length > 0 ? next[0].score : 0;
        refreshLauncherActions(activeQueryMode, rawQuery, filteredApps.length, topScore);

        if (selectedAppIndex >= resultCount)
            selectedAppIndex = Math.max(0, resultCount - 1);
    }

    function launchEntry(entry) {
        if (!entry)
            return;

        entry.execute();
        appQuery = "";
        refreshFilteredApps();
        GlobalStates.setOverviewOpen(false);
    }

    function ensureSelectedVisible() {
        if (!hasSearchQuery || resultCount === 0)
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
                                    if (root.resultCount > 0)
                                        root.selectedAppIndex = Math.min(root.resultCount - 1, root.selectedAppIndex + 1);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Up) {
                                    if (root.resultCount > 0)
                                        root.selectedAppIndex = Math.max(0, root.selectedAppIndex - 1);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    if (root.resultCount > 0)
                                        root.activateSelection(root.selectedAppIndex);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Escape) {
                                    GlobalStates.setOverviewOpen(false);
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
                            text: "Type to launch an app, or ? for shortcuts..."
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
                                    model: root.resultCount

                                    delegate: Rectangle {
                                        required property int index
                                        property bool isAction: root.resultIsAction(index)
                                        property var action: isAction ? root.launcherActions[root.actionIndexForResult(index)] : null
                                        property var entry: isAction ? null : root.filteredApps[root.appIndexForResult(index)]
                                        property bool selected: index === root.selectedAppIndex

                                        width: listContainer.width
                                        height: root.launcherRowHeight
                                        radius: 6
                                        color: selected ? "#314a72" : "transparent"

                                        Text {
                                            anchors.left: appIcon.right
                                            anchors.leftMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - appIcon.width - 26
                                            color: selected ? "#ffffff" : "#d7d7d7"
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                            text: isAction ? (action.title + " - " + action.detail) : ((entry?.name ?? "") + (entry?.genericName && entry.genericName.length > 0 ? " - " + entry.genericName : ""))
                                        }

                                        IconImage {
                                            id: appIcon

                                            anchors.left: parent.left
                                            anchors.leftMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            implicitSize: 16
                                            source: isAction ? action.icon : root.resolveIconSource(entry?.icon)
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onEntered: root.selectedAppIndex = index
                                            onClicked: root.activateSelection(index)
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
                            visible: root.hasSearchQuery && root.resultCount === 0
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
                                    property int workspaceValue: root.workspaceGroupStart + row.index * root.columns + colIndex
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
                                                GlobalStates.setOverviewOpen(false)
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
                            return win.workspace?.id >= root.workspaceGroupStart
                                && win.workspace?.id < root.workspaceGroupStart + root.workspacesShown;
                        })
                        
                        delegate: Loader {
                            id: windowLoader
                            required property var modelData
                            z: (item && item.dynamicZ !== undefined) ? item.dynamicZ : 0
                            
                            property int workspaceId: modelData.workspace?.id ?? root.workspaceGroupStart
                            property int localIndex: workspaceId - root.workspaceGroupStart
                            property int rowIndex: Math.floor(localIndex / root.columns)
                            property int colIndex: localIndex % root.columns
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

    Process {
        id: commandCheckProc

        property string probe: ""
        property string outputBuffer: ""

        running: false

        stdout: SplitParser {
            onRead: data => {
                commandCheckProc.outputBuffer += data;
            }
        }

        onExited: {
            var exists = commandCheckProc.outputBuffer.trim() === "YES";
            if (commandCheckProc.probe === root.commandProbe) {
                root.commandProbeExists = exists;
                root.commandProbeResolved = true;
                root.refreshLauncherActions(root.appQuery);
            }

            commandCheckProc.outputBuffer = "";

            if (root.commandProbePending.length > 0)
                root.startCommandProbeCheck();
        }
    }
}
