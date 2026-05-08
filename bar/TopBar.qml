import Quickshell
import Quickshell.Wayland
import QtQuick
import "modules"
import qs.theme

/**
 * The primary system status bar rendered across all monitors.
 */
Variants {
    id: root
    model: Quickshell.screens

    delegate: PanelWindow {
        id: mainBar

        // --- Screen Mapping ---
        required property var modelData
        screen: modelData

        // --- Layer Shell Configuration ---
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell-topbar"

        // --- Geometry & Positioning ---
        anchors {
            top: true
            left: true
            right: true
        }

        // --- Visual Styling ---
        color: "transparent"
        implicitHeight: Layout.topBarHeight

        // --- Core Modules ---

        // Workspace Switcher
        Workspaces {
            id: workspaceModule
            targetMonitor: modelData.name

            anchors {
                left: parent.left
                leftMargin: 15
                verticalCenter: parent.verticalCenter
            }
        }

        // Calendar
        Calendar {
            id: calendarModule
            anchors.centerIn: parent
        }

        // System Stats
        SystemStats {
            id: statusModule

            anchors {
                right: parent.right
                rightMargin: 15
                verticalCenter: parent.verticalCenter
            }
        }
    }
}
