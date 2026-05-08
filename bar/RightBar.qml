import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.theme

Variants {
    id: root
    model: Quickshell.screens

    delegate: PanelWindow {
        id: rightBarWindow

        // --- Screen Mapping ---
        required property var modelData
        screen: modelData

        // --- Layer Shell Configuration ---
        WlrLayershell.layer: WlrLayer.Top

        // --- Geometry & Positioning ---
        anchors {
            top: true
            right: true
            bottom: true
        }

        // --- Visual Styling ---
        implicitWidth: Layout.sideBarWidth
        color: "transparent"
    }
}
