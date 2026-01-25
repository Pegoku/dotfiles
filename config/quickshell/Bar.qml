import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root


    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData

            screen: modelData
            implicitHeight: 30

            anchors {
                top: true
                left: true
                right: true
            }

            ClockWidget {
                anchors.centerIn: parent
            }

        }

    }

}
