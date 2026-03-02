import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Item {
    id: root

    property string windowClass: ""
    property string windowTitle: ""

    width: 420
    height: 30

    function refresh() {
        if (!activeWindowProc.running)
            activeWindowProc.running = true;
    }

    Column {
        anchors.fill: parent
        spacing: 1

        Text {
            id: classText

            width: parent.width
            visible: root.windowClass.length > 0
            text: root.windowClass
            color: "#b0b0b0"
            opacity: 0.65
            font.pixelSize: 10
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: root.windowTitle
            color: "#f1f1f1"
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent() {
            root.refresh();
        }
    }

    Component.onCompleted: refresh()

    Process {
        id: activeWindowProc

        command: ["hyprctl", "activewindow", "-j"]
        running: false
        property string outputBuffer: ""

        stdout: SplitParser {
            onRead: data => {
                activeWindowProc.outputBuffer += data;
            }
        }

        onExited: {
            var cls = "";
            var title = "";

            if (outputBuffer.trim().length > 0) {
                try {
                    var win = JSON.parse(outputBuffer);
                    cls = win.class ? String(win.class) : "";
                    title = win.title ? String(win.title) : "";
                } catch (e) {
                }
            }

            root.windowClass = cls;
            root.windowTitle = title;
            outputBuffer = "";
        }
    }
}
