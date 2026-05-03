pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    readonly property string time: {
        Qt.formatDateTime(clock.date, " h:mm ap  •  ddd,  MMM d  ");
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
}
