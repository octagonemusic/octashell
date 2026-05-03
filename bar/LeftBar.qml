import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.theme

Variants {
    model: Quickshell.screens

    PanelWindow {
        required property var modelData
        screen: modelData
        WlrLayershell.layer: WlrLayer.Top

        anchors {
            top: true
            left: true
            bottom: true
        }

        implicitWidth: Layout.sideBarWidth
        color: "transparent"
    }
}
