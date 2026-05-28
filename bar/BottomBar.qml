import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs.theme
import qs.services

/**
 * A transparent shell container positioned at the bottom of every connected screen.
 */
Variants {
    id: root
    model: Quickshell.screens

    delegate: PanelWindow {
        id: bottomBarWindow

        // --- Screen Mapping ---
        required property var modelData
        screen: modelData

        // --- Layer Shell Configuration ---
        WlrLayershell.layer: WlrLayer.Overlay

        readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
        visible: !FullscreenState.isFullscreen(monitor)

        // --- Geometry & Positioning ---
        anchors {
            left: true
            right: true
            bottom: true
        }

        // --- Visual Styling ---
        implicitHeight: Layout.bottomBarHeight
        color: "transparent"
    }
}
