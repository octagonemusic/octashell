import QtQuick
import "../../theme"

Item {
    id: delegateRoot
    width: GridView.view.cellWidth
    height: GridView.view.cellHeight

    property string emojiName: modelData.display
    property string emojiChar: modelData.emoji
    property bool isSelected: GridView.isCurrentItem
    property bool isHovered: itemMouseArea.containsMouse

    // Visual scale tracking (avoids QML's 'scale' blur)
    property real targetScale: itemMouseArea.pressed ? 0.85 : (isSelected ? 1.1 : (isHovered ? 1.05 : 1.0))

    Behavior on targetScale {
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutBack
            easing.overshoot: 2.0
        }
    }

    Rectangle {
        anchors.centerIn: parent

        // Dynamic dimension scaling
        width: 52 * delegateRoot.targetScale
        height: 52 * delegateRoot.targetScale
        radius: 16 * delegateRoot.targetScale
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

            // Math.round enforces pixel grid alignment for crisp rendering
            font.pixelSize: Math.round(28 * delegateRoot.targetScale)
            antialiasing: true
        }

        MouseArea {
            id: itemMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onEntered: delegateRoot.GridView.view.currentIndex = index
            onClicked: mouse => {
                emojiWindow.processSelection(delegateRoot.emojiChar, mouse.modifiers & Qt.ShiftModifier);
            }
        }
    }
}
