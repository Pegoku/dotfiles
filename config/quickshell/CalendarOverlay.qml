import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
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
                        GlobalStates.calendarOpen = false;
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Left) {
                        calendarCard.changeMonth(-1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Right) {
                        calendarCard.changeMonth(1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Home) {
                        calendarCard.showToday();
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
                readonly property date firstOfMonth: new Date(shownYear, shownMonth, 1)
                readonly property int leadingDayCount: (firstOfMonth.getDay() + 6) % 7
                readonly property var weekdayLabels: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

                function dateForCell(cellIndex) {
                    return new Date(shownYear, shownMonth, cellIndex - leadingDayCount + 1);
                }

                function sameDay(a, b) {
                    return a.getFullYear() === b.getFullYear()
                        && a.getMonth() === b.getMonth()
                        && a.getDate() === b.getDate();
                }

                function changeMonth(offset) {
                    var target = new Date(shownYear, shownMonth + offset, 1);
                    shownYear = target.getFullYear();
                    shownMonth = target.getMonth();
                }

                function showToday() {
                    today = new Date();
                    shownYear = today.getFullYear();
                    shownMonth = today.getMonth();
                }

                z: 100
                width: 350
                height: 360
                radius: 14
                color: "#1f1f1f"
                border.width: 1
                border.color: "#3d3d3d"
                anchors.top: parent.top
                anchors.topMargin: 46
                anchors.left: parent.left
                anchors.leftMargin: Math.max(8, Math.min(parent.width - width - 8, GlobalStates.calendarAnchorX - width / 2))

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    onClicked: mouse => mouse.accepted = true
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 0

                    Item {
                        width: parent.width
                        height: 42

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
                                text: "Week " + Qt.formatDate(calendarCard.today, "ww") + " · " + Qt.formatDate(calendarCard.today, "dddd, d MMMM")
                                color: "#8f9fba"
                                font.pixelSize: 10
                            }
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            Repeater {
                                model: [
                                    { label: "‹", offset: -1, hint: "Previous month" },
                                    { label: "›", offset: 1, hint: "Next month" }
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

                    Item { width: 1; height: 8 }

                    Grid {
                        width: parent.width
                        columns: 7

                        Repeater {
                            model: calendarCard.weekdayLabels

                            delegate: Item {
                                required property string modelData
                                width: 46
                                height: 24

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
                                readonly property bool isWeekend: index % 7 >= 5

                                width: 46
                                height: 36

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 32
                                    height: 30
                                    radius: 9
                                    color: dayCell.isToday ? "#5876b7" : dayMouse.containsMouse ? "#303746" : "transparent"
                                    border.width: dayCell.isToday ? 1 : 0
                                    border.color: "#7893ce"

                                    Text {
                                        anchors.centerIn: parent
                                        text: dayCell.cellDate.getDate()
                                        color: {
                                            if (!dayCell.inShownMonth)
                                                return "#555b67";
                                            if (dayCell.isToday)
                                                return "#ffffff";
                                            if (dayCell.isWeekend)
                                                return "#aebbd4";
                                            return "#e2e4e9";
                                        }
                                        font.pixelSize: 12
                                        font.bold: dayCell.isToday
                                    }

                                    MouseArea {
                                        id: dayMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                    }
                                }
                            }
                        }
                    }

                    Item { width: 1; height: 7 }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#343843"
                    }

                    Item {
                        width: parent.width
                        height: 33

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "←  →  change month    Home  return to today"
                            color: "#686f7d"
                            font.pixelSize: 9
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
                                onClicked: calendarCard.showToday()
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

                Connections {
                    target: GlobalStates

                    function onCalendarOpenChanged() {
                        if (GlobalStates.calendarOpen)
                            calendarCard.showToday();
                    }
                }
            }
        }
    }
}
