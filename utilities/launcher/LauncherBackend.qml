import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: backend

    // UI Orchestration Signals
    signal openMenuRequested
    signal closeMenuRequested

    property string searchText: ""

    // CHANGE THIS TO YOUR ACTUAL TERMINAL
    property string myTerminal: "kitty"

    function launchApp(desktopEntry) {
        var finalCommand = [];

        // Wrap the launch in UWSM so systemd tracks the app properly
        finalCommand.push("uwsm");
        finalCommand.push("app");
        finalCommand.push("--");

        if (desktopEntry.runInTerminal) {
            finalCommand.push(myTerminal);
            finalCommand.push("--");
        }

        finalCommand = finalCommand.concat(desktopEntry.command);

        Quickshell.execDetached({
            command: finalCommand,
            workingDirectory: desktopEntry.workingDirectory
        });

        backend.closeMenuRequested();
    }

    IpcHandler {
        target: "appLauncher"
        function toggle() {
            backend.openMenuRequested();
        }
    }
}
