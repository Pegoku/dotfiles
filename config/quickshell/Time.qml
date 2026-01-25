pragma Singleton

import Quickshell
import QtQuick

Singleton {
  id:root

  readonly property string time: {
    Qt.formatDateTime(clock.date, "hh:mm")
  }

  readonly property var date: {
    Qt.formatDateTime(clock.date, "dddd, dd/MM" )
  }


  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }


}