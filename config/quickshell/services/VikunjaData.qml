pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string scriptPath: Qt.resolvedUrl("../scripts/vikunja-calendar.sh").toString().replace("file://", "")
    readonly property string defaultConfigPath: "~/.config/vikunja-calendar/vikunja.conf"
    readonly property bool available: configured || projects.length > 0

    property var projects: []
    property var tasks: []
    property var tasksByDate: ({})
    property var commandQueue: []
    property int defaultProjectId: 0
    property int outboxCount: 0
    property int localRevision: 0
    property int localSequence: 0
    property bool configured: false
    property bool loading: true
    property bool syncing: false
    property bool mutating: false
    property string error: ""
    property string configPath: defaultConfigPath
    property string lastSync: ""

    signal taskCreated(string dateKey)

    IpcHandler {
        target: "vikunja"

        function refresh(): void {
            root.refresh();
        }

        function status(): string {
            return JSON.stringify({
                configured: root.configured,
                available: root.available,
                loading: root.loading,
                syncing: root.syncing,
                mutating: root.mutating,
                projectCount: root.projects.length,
                taskCount: Object.keys(root.tasksByDate).reduce((total, key) => total + root.tasksByDate[key].length, 0),
                outboxCount: root.outboxCount,
                lastSync: root.lastSync,
                error: root.error
            });
        }
    }

    function dateKey(value) {
        var date = value instanceof Date ? value : new Date(value);
        if (isNaN(date.getTime()))
            return "";

        return date.getFullYear() + "-"
            + String(date.getMonth() + 1).padStart(2, "0") + "-"
            + String(date.getDate()).padStart(2, "0");
    }

    function rebuildTaskIndex() {
        var next = {};

        for (var i = 0; i < tasks.length; i++) {
            var task = tasks[i];
            if (!task || task.done || !task.due_date || String(task.due_date).startsWith("0001-"))
                continue;

            var key = dateKey(task.due_date);
            if (!key)
                continue;
            if (!next[key])
                next[key] = [];
            next[key].push(task);
        }

        for (var key in next) {
            next[key].sort((a, b) => {
                var priorityDifference = Number(b.priority || 0) - Number(a.priority || 0);
                if (priorityDifference !== 0)
                    return priorityDifference;
                return String(a.title || "").localeCompare(String(b.title || ""));
            });
        }

        tasksByDate = next;
    }

    function tasksForDate(value) {
        return tasksByDate[dateKey(value)] || [];
    }

    function projectForId(projectId) {
        var wanted = Number(projectId);
        for (var i = 0; i < projects.length; i++) {
            if (Number(projects[i].id) === wanted)
                return projects[i];
        }
        return null;
    }

    function normalizedColor(value, fallback) {
        var raw = String(value || "").trim();
        if (raw.length === 0)
            return fallback || "#596273";
        if (!raw.startsWith("#"))
            raw = "#" + raw;
        return /^#[0-9a-fA-F]{6}$/.test(raw) ? raw : (fallback || "#596273");
    }

    function projectColor(projectId) {
        var project = projectForId(projectId);
        return project ? normalizedColor(project.hex_color, "#596273") : "#596273";
    }

    function projectTitle(projectId) {
        var project = projectForId(projectId);
        return project ? String(project.title) : "Unknown project";
    }

    function projectSegmentsForDate(value) {
        var dayTasks = tasksForDate(value);
        var seen = {};
        var segments = [];

        for (var i = 0; i < dayTasks.length; i++) {
            var projectId = Number(dayTasks[i].project_id || 0);
            var key = String(projectId);
            if (seen[key] !== undefined) {
                segments[seen[key]].count++;
                continue;
            }

            seen[key] = segments.length;
            segments.push({
                projectId: projectId,
                title: projectTitle(projectId),
                color: projectColor(projectId),
                count: 1
            });
        }
        return segments;
    }

    function resolvedDefaultProjectId() {
        if (defaultProjectId > 0 && projectForId(defaultProjectId))
            return defaultProjectId;
        for (var i = 0; i < projects.length; i++) {
            if (!projects[i].is_archived)
                return Number(projects[i].id);
        }
        return 0;
    }

    function hasQueuedKind(kind) {
        if (apiProcess.running && apiProcess.currentKind === kind)
            return true;
        for (var i = 0; i < commandQueue.length; i++) {
            if (commandQueue[i].kind === kind)
                return true;
        }
        return false;
    }

    function queueCommand(kind, argumentsList, revision) {
        if (kind === "sync" && hasQueuedKind("sync"))
            return;

        var command = {
            kind: kind,
            argumentsList: argumentsList,
            revision: revision === undefined ? localRevision : revision
        };
        var next = commandQueue.slice();

        if (kind.startsWith("enqueue-")) {
            var syncIndex = next.findIndex(entry => entry.kind === "sync");
            if (syncIndex >= 0)
                next.splice(syncIndex, 0, command);
            else
                next.push(command);
        } else {
            next.push(command);
        }

        commandQueue = next;
        Qt.callLater(startNextCommand);
    }

    function startNextCommand() {
        if (apiProcess.running || commandQueue.length === 0)
            return;

        var next = commandQueue[0];
        commandQueue = commandQueue.slice(1);
        apiProcess.currentKind = next.kind;
        apiProcess.revisionAtStart = next.revision;
        apiProcess.outputBuffer = "";
        apiProcess.command = ["bash", scriptPath].concat(next.argumentsList);

        if (next.kind === "cache")
            loading = true;
        else if (next.kind === "sync")
            syncing = true;
        else if (next.kind.startsWith("enqueue-"))
            mutating = true;

        apiProcess.running = true;
    }

    function loadCache() {
        if (!hasQueuedKind("cache"))
            queueCommand("cache", ["cache"], localRevision);
    }

    function refresh() {
        queueCommand("sync", ["sync"], localRevision);
    }

    function createTask(title, projectId, dueDate) {
        var cleanTitle = String(title || "").trim();
        var numericProjectId = Number(projectId || 0);
        if (!cleanTitle || numericProjectId <= 0)
            return false;

        localSequence++;
        localRevision++;

        var localId = "local-" + Date.now() + "-" + localSequence;
        var localDue = new Date(dueDate.getFullYear(), dueDate.getMonth(), dueDate.getDate(), 12, 0, 0);
        var dueIso = localDue.toISOString();
        var optimisticTask = {
            id: localId,
            title: cleanTitle,
            project_id: numericProjectId,
            due_date: dueIso,
            done: false,
            priority: 0,
            hex_color: "",
            _sync_state: "pending"
        };

        tasks = tasks.concat([optimisticTask]);
        outboxCount++;
        rebuildTaskIndex();
        taskCreated(dateKey(dueDate));

        queueCommand("enqueue-create", ["enqueue-create", localId, String(numericProjectId), dueIso, cleanTitle], localRevision);
        queueCommand("sync", ["sync"], localRevision);
        return true;
    }

    function completeTask(taskId) {
        var wanted = String(taskId);
        var wasPendingCreate = wanted.startsWith("local-");
        var found = false;
        var next = [];

        for (var i = 0; i < tasks.length; i++) {
            if (String(tasks[i].id) === wanted) {
                found = true;
                continue;
            }
            next.push(tasks[i]);
        }
        if (!found)
            return false;

        localRevision++;
        tasks = next;
        outboxCount = wasPendingCreate ? Math.max(0, outboxCount - 1) : outboxCount + 1;
        rebuildTaskIndex();

        queueCommand("enqueue-complete", ["enqueue-complete", wanted], localRevision);
        queueCommand("sync", ["sync"], localRevision);
        return true;
    }

    function applySnapshot(response, includeLocalState) {
        configured = Boolean(response.configured);
        configPath = String(response.config_path || defaultConfigPath);
        defaultProjectId = Number(response.default_project_id || 0);
        lastSync = String(response.last_sync || "");
        error = String(response.sync_error || "");

        if (response.projects instanceof Array)
            projects = response.projects;

        if (includeLocalState) {
            tasks = response.tasks instanceof Array ? response.tasks : [];
            outboxCount = Number(response.outbox_count || 0);
            rebuildTaskIndex();
        }
    }

    Process {
        id: apiProcess

        property string outputBuffer: ""
        property string currentKind: ""
        property int revisionAtStart: 0

        running: false

        stdout: SplitParser {
            onRead: data => apiProcess.outputBuffer += data
        }

        onExited: (exitCode, exitStatus) => {
            var completedKind = apiProcess.currentKind;
            if (completedKind === "cache")
                root.loading = false;
            else if (completedKind === "sync")
                root.syncing = false;
            else if (completedKind.startsWith("enqueue-"))
                root.mutating = false;

            var response;
            try {
                response = JSON.parse(apiProcess.outputBuffer.trim());
            } catch (parseError) {
                root.error = "The local Vikunja worker returned an unreadable response";
                response = null;
            }

            if (response && response.ok) {
                root.applySnapshot(response, apiProcess.revisionAtStart === root.localRevision);
            } else if (response) {
                root.error = String(response.error || "Local Vikunja operation failed");
            }

            apiProcess.currentKind = "";
            if (completedKind.startsWith("enqueue-"))
                Qt.callLater(root.refresh);
            Qt.callLater(root.startNextCommand);
        }
    }

    Component.onCompleted: loadCache()
}
