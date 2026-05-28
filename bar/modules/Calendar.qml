import QtQuick
import qs.services
import qs.theme
import qs.bar.widgets.calendar

Item {
    id: root

    implicitWidth: visualPill.implicitWidth
    implicitHeight: visualPill.implicitHeight

    Rectangle {
        id: visualPill
        anchors.centerIn: parent

        implicitWidth: timeLabel.implicitWidth + 32
        implicitHeight: timeLabel.implicitHeight + 16
        radius: height / 2

        // Use standard UI opacity overlays instead of jumping to primary_container
        color: {
            if (calendarWidget.visible)
                // 12% overlay for an active/toggled state
                return Qt.tint(Theme.surface_container, Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.12));
            if (pillMouse.containsMouse)
                // 8% overlay for a subtle hover state
                return Qt.tint(Theme.surface_container, Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.08));

            return Theme.surface_container; // Base state
        }

        // Tamed: Only scales down slightly when physically clicked
        scale: pillMouse.pressed ? 0.95 : 1.0

        // Snappy, non-bouncy transitions
        Behavior on color {
            ColorAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: calendarWidget.visible = !calendarWidget.visible
        }

        Text {
            id: timeLabel
            anchors.centerIn: parent
            text: Time.time

            // Keep the text color consistent. Changing text color is often
            // the biggest culprit of a "loud" interaction.
            color: Theme.on_surface

            font {
                family: "Google Sans"
                pointSize: 14
                weight: Font.Medium
            }

            Behavior on color {
                ColorAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    CalendarWidget {
        id: calendarWidget
        visible: false
    }
}
