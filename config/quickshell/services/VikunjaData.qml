pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string scriptPath: Qt.resolvedUrl("../scripts/vikunja-calendar.sh").toString().replace("file://", "")
    readonly property string defaultConfigPath: "~/.config/vikunja-calendar/config"

    property var projects: []
    property var tasks: []
    property var tasksByDate: ({})
    property int defaultProjectId: 0
    property bool configured: false
    property bool loading: false
    property bool mutating: false
    property bool refreshQueued: false
    property string error: ""
    property string configPath: defaultConfigPath
    property string lastAction: ""

    signal taskCreated(string dateKey)

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

    function refresh() {
        if (apiProcess.running) {
            refreshQueued = true;
            return;
        }

        loading = true;
        lastAction = "fetch";
        apiProcess.outputBuffer = "";
        apiProcess.command = ["bash", scriptPath, "fetch"];
        apiProcess.running = true;
    }

    function createTask(title, projectId, dueDate) {
        var cleanTitle = String(title || "").trim();
        if (!cleanTitle || apiProcess.running)
            return false;

        var localDue = new Date(dueDate.getFullYear(), dueDate.getMonth(), dueDate.getDate(), 12, 0, 0);
        mutating = true;
        error = "";
        lastAction = "create";
        apiProcess.outputBuffer = "";
        apiProcess.pendingDateKey = dateKey(dueDate);
        apiProcess.command = ["bash", scriptPath, "create", String(projectId), localDue.toISOString(), cleanTitle];
        apiProcess.running = true;
        return true;
    }

    function completeTask(taskId) {
        if (apiProcess.running)
            return false;

        mutating = true;
        error = "";
        lastAction = "complete";
        apiProcess.outputBuffer = "";
        apiProcess.command = ["bash", scriptPath, "complete", String(taskId)];
        apiProcess.running = true;
        return true;
    }

    Process {
        id: apiProcess

        property string outputBuffer: ""
        property string pendingDateKey: ""

        running: false

        stdout: SplitParser {
            onRead: data => apiProcess.outputBuffer += data
        }

        onExited: (exitCode, exitStatus) => {
            root.loading = false;
            root.mutating = false;

            var response;
            try {
                response = JSON.parse(apiProcess.outputBuffer.trim());
            } catch (parseError) {
                root.error = "Vikunja returned an unreadable response";
                response = null;
            }

            if (response && response.ok) {
                root.configured = true;
                root.error = "";

                if (response.action === "fetch") {
                    root.projects = response.projects || [];
                    root.tasks = response.tasks || [];
                    root.defaultProjectId = Number(response.default_project_id || 0);
                    root.rebuildTaskIndex();
                } else {
                    if (response.action === "create")
                        root.taskCreated(apiProcess.pendingDateKey);
                    root.refreshQueued = true;
                }
            } else if (response) {
                root.error = String(response.error || "Vikunja request failed");
                root.configPath = String(response.config_path || root.defaultConfigPath);
                if (root.lastAction === "fetch" && root.error === "Vikunja is not configured")
                    root.configured = false;
            }

            apiProcess.pendingDateKey = "";
            if (root.refreshQueued) {
                root.refreshQueued = false;
                Qt.callLater(root.refresh);
            }
        }
    }
}
