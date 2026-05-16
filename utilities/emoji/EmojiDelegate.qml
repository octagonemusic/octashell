import QtQuick
import "../../theme"

Item {
    id: delegateRoot
    width: GridView.view.cellWidth
    height: GridView.view.cellHeight

    property string emojiName: modelData.display
    property string emojiChar: modelData.emoji // Extracted to be readable by the picker
    property bool isSelected: GridView.isCurrentItem
    property bool isHovered: itemMouseArea.containsMouse

    // We define our target scale value here, but we will NOT use QML's 'scale' property.
    property real targetScale: itemMouseArea.pressed ? 0.85 : (delegateRoot.isSelected ? 1.1 : (delegateRoot.isHovered ? 1.05 : 1.0))

    // Smoothly animate the target multiplier
    Behavior on targetScale {
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutBack
            easing.overshoot: 2.0
        }
    }

    Rectangle {
        anchors.centerIn: parent

        // Multiply the base sizes by our animated value
        width: 52 * delegateRoot.targetScale
        height: 52 * delegateRoot.targetScale
        radius: 16 * delegateRoot.targetScale

        // Explicitly enforce smooth corner rendering
        antialiasing: true

        color: delegateRoot.isSelected ? Theme.primary_container : (delegateRoot.isHovered ? Theme.surface_container_highest : "transparent")

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }

        Text {
            anchors.centerIn: parent
            text: modelData.emoji
            font.family: "Noto Color Emoji"

            // Dynamically redraw the font at exact pixel sizes instead of stretching it
            // Math.round ensures the font aligns perfectly to the pixel grid, avoiding sub-pixel blur
            font.pixelSize: Math.round(28 * delegateRoot.targetScale)

            // Force text anti-aliasing
            antialiasing: true
        }

        MouseArea {
            id: itemMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: delegateRoot.GridView.view.currentIndex = index
            onClicked: mouse => {
                let isShift = mouse.modifiers & Qt.ShiftModifier;
                emojiWindow.processSelection(delegateRoot.emojiChar, isShift);
            }
        }
    }
}
