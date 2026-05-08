import QtQuick
import qs.services
import qs.theme

/**
 * A reactive clock component that displays the system time in a styled container.
 */
Rectangle {
    id: root

    // --- Dimensions ---
    implicitWidth: timeLabel.contentWidth + 20
    implicitHeight: timeLabel.contentHeight + 15

    // --- Styling ---
    color: Theme.surface_container
    radius: height / 2

    /**
     * Renders the current time string provided by the global Time service.
     */
    Text {
        id: timeLabel

        anchors.centerIn: parent

        // Direct binding to the Time service telemetry
        text: Time.time
        color: Theme.on_surface_variant

        font {
            family: "Google Sans Medium"
            pointSize: 14
        }
    }
}
