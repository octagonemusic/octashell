import QtQuick
import Quickshell.Io

Item {
    id: backend

    // UI Orchestration Signals
    signal openMenuRequested
    signal closeMenuRequested

    property string searchText: ""

    function launchApp(desktopEntry) {
        desktopEntry.execute();
        backend.closeMenuRequested();
    }

    IpcHandler {
        target: "appLauncher"
        function toggle() {
            backend.openMenuRequested();
        }
    }
}
