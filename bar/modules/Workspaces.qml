import QtQuick
import Quickshell.Hyprland
import qs.theme

Rectangle {
    id: root

    // ... (WheelHandler and Dimensions logic remains the same) ...
    implicitWidth: row.width + 30
    implicitHeight: row.height + 18
    color: Theme.surface_container
    radius: height / 2

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 10

        Repeater {
            model: Hyprland.workspaces

            Rectangle {
                id: dot // We need this ID to anchor the tooltip
                visible: modelData.id >= 1

                // ... (Your standard width/height/color logic) ...
                width: {
                    if (!visible)
                        return 0;
                    if (modelData.focused || modelData.active)
                        return 40;
                    if (hoverHandler.hovered)
                        return 32;
                    return 24;
                }
                height: 20
                radius: 10

                color: {
                    if (modelData.focused)
                        return Theme.primary;
                    if (modelData.active)
                        return Theme.secondary_fixed;
                    if (hoverHandler.hovered)
                        return "#666666";
                    return "#4c4c4c";
                }

                // ... (Animations and TapHandler) ...
                Behavior on width {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutBack
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }

                TapHandler {
                    onTapped: modelData.activate()
                }

                HoverHandler {
                    id: hoverHandler
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }
}
