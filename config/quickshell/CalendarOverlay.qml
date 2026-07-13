import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    IpcHandler {
        target: "calendar"

        function toggle(): void {
            GlobalStates.calendarOpen = !GlobalStates.calendarOpen;
        }

        function open(): void {
            GlobalStates.calendarOpen = true;
        }

        function close(): void {
            GlobalStates.calendarOpen = false;
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: GlobalStates.calendarOpen
            color: "transparent"

            WlrLayershell.namespace: "quickshell:calendar"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: GlobalStates.calendarOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0

            FocusScope {
                anchors.fill: parent
                focus: GlobalStates.calendarOpen

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        if (calendarCard.selectedDate) {
                            calendarCard.closeDay();
                        } else {
                            GlobalStates.calendarOpen = false;
                        }
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Left) {
                        calendarCard.changeMonth(-1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Right) {
                        calendarCard.changeMonth(1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Home) {
                        calendarCard.showToday(true);
                        event.accepted = true;
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                onClicked: GlobalStates.calendarOpen = false
            }

            Rectangle {
                id: calendarCard

                property date today: new Date()
                property int shownYear: today.getFullYear()
                property int shownMonth: today.getMonth()
                property var selectedDate: null
                property bool editorOpen: false
                property string newTaskTitle: ""
                property int selectedProjectId: 0
                readonly property date firstOfMonth: new Date(shownYear, shownMonth, 1)
                readonly property int leadingDayCount: (firstOfMonth.getDay() + 6) % 7
                readonly property var weekdayLabels: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
                readonly property var selectedTasks: selectedDate ? VikunjaData.tasksForDate(selectedDate) : []
                readonly property var activeProjects: VikunjaData.projects.filter(project => !project.is_archived)
                readonly property int detailsHeight: {
                    if (!selectedDate)
                        return 0;
                    if (!VikunjaData.configured)
                        return 118;
                    if (selectedTasks.length === 0)
                        return 154;
                    return editorOpen ? 250 : 178;
                }

                function dateForCell(cellIndex) {
                    return new Date(shownYear, shownMonth, cellIndex - leadingDayCount + 1);
                }

                function sameDay(a, b) {
                    return a && b
                        && a.getFullYear() === b.getFullYear()
                        && a.getMonth() === b.getMonth()
                        && a.getDate() === b.getDate();
                }

                function isoWeekNumber(value) {
                    var date = new Date(Date.UTC(value.getFullYear(), value.getMonth(), value.getDate()));
                    var weekDay = date.getUTCDay() || 7;
                    date.setUTCDate(date.getUTCDate() + 4 - weekDay);
                    var yearStart = new Date(Date.UTC(date.getUTCFullYear(), 0, 1));
                    return Math.ceil((((date - yearStart) / 86400000) + 1) / 7);
                }

                function changeMonth(offset) {
                    var target = new Date(shownYear, shownMonth + offset, 1);
                    shownYear = target.getFullYear();
                    shownMonth = target.getMonth();
                    closeDay();
                }

                function showToday(selectDay) {
                    today = new Date();
                    shownYear = today.getFullYear();
                    shownMonth = today.getMonth();
                    if (selectDay)
                        selectDate(today);
                    else
                        closeDay();
                }

                function selectDate(value) {
                    selectedDate = new Date(value.getFullYear(), value.getMonth(), value.getDate());
                    selectedProjectId = VikunjaData.resolvedDefaultProjectId();
                    newTaskTitle = "";
                    editorOpen = VikunjaData.tasksForDate(selectedDate).length === 0;
                }

                function closeDay() {
                    selectedDate = null;
                    editorOpen = false;
                    newTaskTitle = "";
                }

                function submitTask() {
                    if (!selectedDate || newTaskTitle.trim().length === 0)
                        return;
                    if (VikunjaData.createTask(newTaskTitle, selectedProjectId, selectedDate))
                        taskTitleInput.focus = false;
                }

                z: 100
                width: Math.min(410, parent.width - 16)
                height: Math.min(parent.height - 54, 374 + detailsHeight)
                radius: 14
                color: "#1f1f1f"
                border.width: 1
                border.color: "#3d3d3d"
                clip: true
                anchors.top: parent.top
                anchors.topMargin: 46
                anchors.left: parent.left
                anchors.leftMargin: Math.max(8, Math.min(parent.width - width - 8, GlobalStates.calendarAnchorX - width / 2))

                Behavior on height {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    onClicked: mouse => mouse.accepted = true
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 0

                    Item {
                        width: parent.width
                        height: 46

                        Column {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            Text {
                                text: Qt.formatDate(calendarCard.firstOfMonth, "MMMM yyyy")
                                color: "#f2f2f2"
                                font.pixelSize: 17
                                font.bold: true
                            }

                            Text {
                                text: "Week " + calendarCard.isoWeekNumber(calendarCard.today) + " · " + Qt.formatDate(calendarCard.today, "dddd, d MMMM")
                                color: "#8f9fba"
                                font.pixelSize: 10
                            }
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Rectangle {
                                width: 28
                                height: 28
                                radius: 7
                                color: refreshMouse.containsMouse ? "#354058" : "#292d37"
                                border.width: 1
                                border.color: "#393f4d"

                                Text {
                                    anchors.centerIn: parent
                                    text: "↻"
                                    color: VikunjaData.loading ? "#7181a0" : "#dce3f2"
                                    font.pixelSize: 15
                                }

                                MouseArea {
                                    id: refreshMouse
                                    anchors.fill: parent
                                    enabled: !VikunjaData.loading && !VikunjaData.mutating
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: VikunjaData.refresh()
                                }
                            }

                            Repeater {
                                model: [
                                    { label: "‹", offset: -1 },
                                    { label: "›", offset: 1 }
                                ]

                                delegate: Rectangle {
                                    required property var modelData

                                    width: 28
                                    height: 28
                                    radius: 7
                                    color: navigationMouse.containsMouse ? "#3b4560" : "#2b2f3a"
                                    border.width: 1
                                    border.color: navigationMouse.containsMouse ? "#60739f" : "#393f4d"

                                    Text {
                                        anchors.centerIn: parent
                                        anchors.verticalCenterOffset: -1
                                        text: modelData.label
                                        color: "#e8edf8"
                                        font.pixelSize: 21
                                    }

                                    MouseArea {
                                        id: navigationMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: calendarCard.changeMonth(modelData.offset)
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#343843"
                    }

                    Item { width: 1; height: 6 }

                    Grid {
                        id: weekdayGrid
                        width: parent.width
                        columns: 7

                        Repeater {
                            model: calendarCard.weekdayLabels

                            delegate: Item {
                                required property string modelData
                                width: weekdayGrid.width / 7
                                height: 22

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: modelData === "SAT" || modelData === "SUN" ? "#7f91b3" : "#777f90"
                                    font.pixelSize: 9
                                    font.bold: true
                                    font.letterSpacing: 0.8
                                }
                            }
                        }
                    }

                    Grid {
                        id: monthGrid
                        width: parent.width
                        columns: 7

                        Repeater {
                            model: 42

                            delegate: Item {
                                id: dayCell

                                required property int index
                                readonly property date cellDate: calendarCard.dateForCell(index)
                                readonly property bool inShownMonth: cellDate.getMonth() === calendarCard.shownMonth
                                readonly property bool isToday: calendarCard.sameDay(cellDate, calendarCard.today)
                                readonly property bool isSelected: calendarCard.sameDay(cellDate, calendarCard.selectedDate)
                                readonly property bool isWeekend: index % 7 >= 5
                                readonly property var dayTasks: VikunjaData.tasksForDate(cellDate)
                                readonly property var taskSegments: VikunjaData.projectSegmentsForDate(cellDate)

                                width: monthGrid.width / 7
                                height: 39

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: Math.max(34, parent.width - 5)
                                    height: 35
                                    radius: 9
                                    color: dayCell.isToday ? "#3d527e" : dayMouse.containsMouse ? "#303746" : "#252831"
                                    border.width: dayCell.isSelected ? 2 : dayCell.isToday ? 1 : 0
                                    border.color: dayCell.isSelected ? "#a9bdea" : "#7893ce"
                                    clip: true

                                    Row {
                                        id: segmentTintRow
                                        anchors.fill: parent
                                        opacity: dayCell.inShownMonth ? 0.18 : 0.09

                                        Repeater {
                                            model: dayCell.taskSegments

                                            delegate: Rectangle {
                                                required property var modelData
                                                width: segmentTintRow.width / Math.max(1, dayCell.taskSegments.length)
                                                height: segmentTintRow.height
                                                color: modelData.color
                                            }
                                        }
                                    }

                                    Row {
                                        id: segmentRibbonRow
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        height: dayCell.taskSegments.length > 0 ? 4 : 0

                                        Repeater {
                                            model: dayCell.taskSegments

                                            delegate: Rectangle {
                                                required property var modelData
                                                width: segmentRibbonRow.width / Math.max(1, dayCell.taskSegments.length)
                                                height: segmentRibbonRow.height
                                                color: modelData.color
                                            }
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        anchors.verticalCenterOffset: dayCell.taskSegments.length > 0 ? -1 : 0
                                        text: dayCell.cellDate.getDate()
                                        color: {
                                            if (!dayCell.inShownMonth)
                                                return "#565e6c";
                                            if (dayCell.isToday || dayCell.isSelected)
                                                return "#ffffff";
                                            if (dayCell.isWeekend)
                                                return "#b6c2dc";
                                            return "#e2e4e9";
                                        }
                                        font.pixelSize: 12
                                        font.bold: dayCell.isToday || dayCell.isSelected
                                    }

                                    Rectangle {
                                        visible: dayCell.dayTasks.length > 0
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 3
                                        width: 13
                                        height: 12
                                        radius: 5
                                        color: "#222631"
                                        opacity: dayCell.inShownMonth ? 0.95 : 0.55

                                        Text {
                                            anchors.centerIn: parent
                                            text: dayCell.dayTasks.length > 9 ? "9+" : dayCell.dayTasks.length
                                            color: "#cdd6e9"
                                            font.pixelSize: 7
                                            font.bold: true
                                        }
                                    }

                                    MouseArea {
                                        id: dayMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: calendarCard.selectDate(dayCell.cellDate)
                                    }
                                }
                            }
                        }
                    }

                    Item { width: 1; height: 6 }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#343843"
                    }

                    Item {
                        width: parent.width
                        height: 34

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                color: VikunjaData.loading ? "#d5a85c" : VikunjaData.configured ? "#73b982" : "#69717e"
                            }

                            Text {
                                width: Math.min(220, implicitWidth)
                                elide: Text.ElideRight
                                text: {
                                    if (VikunjaData.loading)
                                        return "Syncing Vikunja…";
                                    if (!VikunjaData.configured)
                                        return "Vikunja setup needed";
                                    if (VikunjaData.error)
                                        return VikunjaData.error;
                                    return VikunjaData.tasks.length + " tasks synced";
                                }
                                color: VikunjaData.error ? "#d99898" : "#737c8d"
                                font.pixelSize: 9
                            }
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 54
                            height: 23
                            radius: 7
                            color: todayMouse.containsMouse ? "#3b4560" : "#2b2f3a"

                            Text {
                                anchors.centerIn: parent
                                text: "Today"
                                color: "#dce3f2"
                                font.pixelSize: 10
                                font.bold: true
                            }

                            MouseArea {
                                id: todayMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: calendarCard.showToday(true)
                            }
                        }
                    }

                    Item {
                        id: dayDrawer
                        visible: calendarCard.selectedDate !== null
                        width: parent.width
                        height: calendarCard.detailsHeight
                        clip: true

                        Rectangle {
                            anchors.top: parent.top
                            width: parent.width
                            height: 1
                            color: "#3b404c"
                        }

                        Column {
                            anchors.fill: parent
                            anchors.topMargin: 9
                            spacing: 7

                            Item {
                                width: parent.width
                                height: 29

                                Column {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 0

                                    Text {
                                        text: calendarCard.selectedDate ? Qt.formatDate(calendarCard.selectedDate, "dddd, d MMMM") : ""
                                        color: "#eef1f7"
                                        font.pixelSize: 13
                                        font.bold: true
                                    }

                                    Text {
                                        text: calendarCard.selectedTasks.length === 0 ? "No scheduled tasks" : calendarCard.selectedTasks.length + (calendarCard.selectedTasks.length === 1 ? " task" : " tasks")
                                        color: "#7e889b"
                                        font.pixelSize: 9
                                    }
                                }

                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 24
                                    height: 24
                                    radius: 7
                                    color: closeDayMouse.containsMouse ? "#363b47" : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "×"
                                        color: "#aab1bf"
                                        font.pixelSize: 16
                                    }

                                    MouseArea {
                                        id: closeDayMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: calendarCard.closeDay()
                                    }
                                }
                            }

                            Column {
                                visible: !VikunjaData.configured
                                width: parent.width
                                spacing: 4

                                Text {
                                    width: parent.width
                                    wrapMode: Text.Wrap
                                    text: "Connect Vikunja to see and create tasks for this date."
                                    color: "#c5cbd6"
                                    font.pixelSize: 10
                                }

                                Text {
                                    width: parent.width
                                    elide: Text.ElideMiddle
                                    text: VikunjaData.configPath
                                    color: "#7f91b3"
                                    font.pixelSize: 9
                                }

                                Text {
                                    visible: VikunjaData.error.length > 0 && VikunjaData.error !== "Vikunja is not configured"
                                    width: parent.width
                                    wrapMode: Text.Wrap
                                    text: VikunjaData.error
                                    color: "#d99898"
                                    font.pixelSize: 9
                                }
                            }

                            Flickable {
                                visible: VikunjaData.configured && calendarCard.selectedTasks.length > 0
                                width: parent.width
                                height: calendarCard.editorOpen ? 96 : 92
                                clip: true
                                contentWidth: width
                                contentHeight: taskListColumn.implicitHeight

                                Column {
                                    id: taskListColumn
                                    width: parent.width
                                    spacing: 4

                                    Repeater {
                                        model: calendarCard.selectedTasks

                                        delegate: Rectangle {
                                            required property var modelData

                                            width: taskListColumn.width
                                            height: 30
                                            radius: 7
                                            color: "#292d36"

                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.top: parent.top
                                                anchors.bottom: parent.bottom
                                                width: 4
                                                radius: 2
                                                color: VikunjaData.projectColor(modelData.project_id)
                                            }

                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.leftMargin: 9
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 15
                                                height: 15
                                                radius: 5
                                                color: completeMouse.containsMouse ? "#35425d" : "transparent"
                                                border.width: 1
                                                border.color: "#707c93"

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "✓"
                                                    visible: completeMouse.containsMouse
                                                    color: "#dce5f5"
                                                    font.pixelSize: 9
                                                }

                                                MouseArea {
                                                    id: completeMouse
                                                    anchors.fill: parent
                                                    enabled: !VikunjaData.mutating && !VikunjaData.loading
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: VikunjaData.completeTask(modelData.id)
                                                }
                                            }

                                            Text {
                                                anchors.left: parent.left
                                                anchors.leftMargin: 31
                                                anchors.right: projectLabel.left
                                                anchors.rightMargin: 8
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: modelData.title
                                                color: "#e0e3e9"
                                                font.pixelSize: 10
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                id: projectLabel
                                                anchors.right: parent.right
                                                anchors.rightMargin: 8
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: Math.min(100, implicitWidth)
                                                text: VikunjaData.projectTitle(modelData.project_id)
                                                color: VikunjaData.projectColor(modelData.project_id)
                                                font.pixelSize: 8
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                visible: VikunjaData.configured && calendarCard.selectedTasks.length > 0 && !calendarCard.editorOpen
                                width: parent.width
                                height: 28
                                radius: 7
                                color: newTaskMouse.containsMouse ? "#35405a" : "#292e3a"
                                border.width: 1
                                border.color: "#3e475b"

                                Text {
                                    anchors.centerIn: parent
                                    text: "+  New task"
                                    color: "#cdd7eb"
                                    font.pixelSize: 10
                                    font.bold: true
                                }

                                MouseArea {
                                    id: newTaskMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        calendarCard.editorOpen = true;
                                        taskTitleInput.forceActiveFocus();
                                    }
                                }
                            }

                            Column {
                                visible: VikunjaData.configured && (calendarCard.selectedTasks.length === 0 || calendarCard.editorOpen)
                                width: parent.width
                                spacing: 6

                                Flickable {
                                    width: parent.width
                                    height: 24
                                    contentWidth: projectChipRow.implicitWidth
                                    contentHeight: height
                                    clip: true

                                    Row {
                                        id: projectChipRow
                                        spacing: 5

                                        Repeater {
                                            model: calendarCard.activeProjects

                                            delegate: Rectangle {
                                                required property var modelData
                                                readonly property bool selected: Number(modelData.id) === calendarCard.selectedProjectId

                                                width: projectChipText.implicitWidth + 21
                                                height: 23
                                                radius: 7
                                                color: selected ? "#343d51" : "#282c34"
                                                border.width: selected ? 1 : 0
                                                border.color: VikunjaData.projectColor(modelData.id)

                                                Rectangle {
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 7
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 6
                                                    height: 6
                                                    radius: 3
                                                    color: VikunjaData.projectColor(modelData.id)
                                                }

                                                Text {
                                                    id: projectChipText
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 17
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: modelData.title
                                                    color: selected ? "#e5e9f1" : "#9ca4b3"
                                                    font.pixelSize: 9
                                                    font.bold: selected
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: calendarCard.selectedProjectId = Number(modelData.id)
                                                }
                                            }
                                        }
                                    }
                                }

                                Row {
                                    width: parent.width
                                    spacing: 6

                                    Rectangle {
                                        width: parent.width - addTaskButton.width - parent.spacing
                                        height: 31
                                        radius: 8
                                        color: "#262a32"
                                        border.width: taskTitleInput.activeFocus ? 1 : 0
                                        border.color: "#6176a4"

                                        Text {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 9
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: taskTitleInput.text.length === 0
                                            text: "What needs doing?"
                                            color: "#656d7b"
                                            font.pixelSize: 10
                                        }

                                        TextInput {
                                            id: taskTitleInput
                                            anchors.fill: parent
                                            anchors.leftMargin: 9
                                            anchors.rightMargin: 8
                                            verticalAlignment: TextInput.AlignVCenter
                                            text: calendarCard.newTaskTitle
                                            color: "#eceff4"
                                            selectionColor: "#526a9f"
                                            selectedTextColor: "#ffffff"
                                            font.pixelSize: 10
                                            clip: true

                                            onTextChanged: calendarCard.newTaskTitle = text
                                            onAccepted: calendarCard.submitTask()
                                        }
                                    }

                                    Rectangle {
                                        id: addTaskButton
                                        width: 52
                                        height: 31
                                        radius: 8
                                        color: addTaskMouse.enabled ? (addTaskMouse.containsMouse ? "#6681bd" : "#526da7") : "#303642"

                                        Text {
                                            anchors.centerIn: parent
                                            text: VikunjaData.mutating ? "…" : "Add"
                                            color: addTaskMouse.enabled ? "#ffffff" : "#6f7785"
                                            font.pixelSize: 10
                                            font.bold: true
                                        }

                                        MouseArea {
                                            id: addTaskMouse
                                            anchors.fill: parent
                                            enabled: calendarCard.newTaskTitle.trim().length > 0
                                                && calendarCard.selectedProjectId > 0
                                                && !VikunjaData.mutating
                                                && !VikunjaData.loading
                                            hoverEnabled: true
                                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onClicked: calendarCard.submitTask()
                                        }
                                    }
                                }

                                Text {
                                    visible: VikunjaData.error.length > 0
                                    width: parent.width
                                    text: VikunjaData.error
                                    color: "#d99898"
                                    font.pixelSize: 8
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }

                Timer {
                    interval: 60000
                    repeat: true
                    running: GlobalStates.calendarOpen
                    onTriggered: calendarCard.today = new Date()
                }

                Timer {
                    interval: 300000
                    repeat: true
                    running: GlobalStates.calendarOpen && VikunjaData.configured
                    onTriggered: VikunjaData.refresh()
                }

                Connections {
                    target: GlobalStates

                    function onCalendarOpenChanged() {
                        if (GlobalStates.calendarOpen) {
                            calendarCard.showToday(false);
                            VikunjaData.refresh();
                        }
                    }
                }

                Connections {
                    target: VikunjaData

                    function onTaskCreated(dateKey) {
                        if (calendarCard.selectedDate && VikunjaData.dateKey(calendarCard.selectedDate) === dateKey) {
                            calendarCard.newTaskTitle = "";
                            calendarCard.editorOpen = false;
                        }
                    }
                }
            }
        }
    }
}
