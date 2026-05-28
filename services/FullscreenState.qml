pragma Singleton

import Quickshell
import Quickshell.Hyprland
import QtQml

Singleton {
    property var specialVisible: ({})

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activespecial")
                return;
            const args = event.parse(2);
            const wsName = args[0];
            const monName = args[1];
            const updated = Object.assign({}, specialVisible);
            updated[monName] = wsName !== "";
            specialVisible = updated;
        }
    }

    readonly property var workspaceFullscreenStates: {
        return Hyprland.workspaces.values.map(ws => ({
                    id: ws.id,
                    hasFullscreen: ws.hasFullscreen,
                    monitorName: ws.monitor ? ws.monitor.name : null
                }));
    }

    function isFullscreen(monitor) {
        if (!monitor)
            return false;

        const monName = monitor.name;
        const specialIsOpen = specialVisible[monName] === true;

        if (specialIsOpen) {
            for (let i = 0; i < workspaceFullscreenStates.length; i++) {
                const ws = workspaceFullscreenStates[i];
                if (ws.id < 0 && ws.hasFullscreen && ws.monitorName === monName)
                    return true;
            }
            return false;
        } else {
            return !!(monitor.activeWorkspace?.hasFullscreen);
        }
    }
}
