pragma Singleton
import QtQuick
import Quickshell

Singleton {
    // Empty uses the model selected in ~/.codex/config.toml.
    property string model: ""
    property string workingDirectory: Quickshell.env("HOME")
}
