import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    PanelWindow {
        implicitHeight: 30

        anchors {
            top: true
            left: true
            right: true
        }

        Text {
            id: clock

            anchors.centerIn: parent

            Process {
                id: dateProc

                command: ["date"]
                running: true

                stdout: StdioCollector {
                    onStreamFinished: clock.text = this.text
                }

            }

        }

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: dateProc.running = true
        }

    }

}
