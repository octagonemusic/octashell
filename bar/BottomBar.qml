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
            left: true
            right: true
            bottom: true
        }

        implicitHeight: Layout.bottomBarHeight
        color: "transparent"
    }
}
