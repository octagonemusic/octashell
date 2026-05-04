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
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell-topbar"
        anchors {
            top: true
            left: true
            right: true
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
