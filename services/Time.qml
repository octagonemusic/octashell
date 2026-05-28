pragma Singleton

import Quickshell
import QtQuick

/** Global time provider for shell components. */
Singleton {
    id: root

    // Formatted string
    readonly property string time: Qt.formatDateTime(clock.date, " h:mm ap  •  ddd,  MMM d ")

    // Reactive clock source tracking seconds.
    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
}
