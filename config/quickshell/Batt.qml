pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
  id: root

  readonly property var battery: UPower.displayDevice

  readonly property bool isPresent: battery.isPresent
  readonly property real percentage: battery.percentage
  readonly property real changeRate: battery.changeRate
  readonly property real timeToEmpty: battery.timeToEmpty
  readonly property real timeToFull: battery.timeToFull
}