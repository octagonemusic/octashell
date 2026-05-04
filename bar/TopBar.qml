import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import "modules"
import qs.theme

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: mainBar
        required property var modelData
        screen: modelData
        WlrLayershell.layer: WlrLayer.Overlay
        anchors {
            top: true
            left: true
            right: true
        }

        visible: {
            let monitor = Hyprland.monitors.values.find(m => m.name === modelData.name);
            return monitor && monitor.activeWorkspace ? !monitor.activeWorkspace.hasFullscreen : true;
        }

        color: "transparent"
        implicitHeight: Layout.topBarHeight

        Clock {
            anchors.centerIn: parent
        }

        Workspaces {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 15
            screenName: modelData.name
        }

        SystemStats {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 15
        }
    }
}
