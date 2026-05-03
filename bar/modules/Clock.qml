import QtQuick
import qs.services
import qs.theme

Rectangle {
    id: root
    implicitWidth: timeText.contentWidth + 20
    color: Theme.surface_container
    implicitHeight: timeText.contentHeight + 15
    radius: (timeText.contentHeight + 13) / 2

    Text {
        id: timeText
        text: Time.time
        color: Theme.on_surface_variant
        font.family: "Google Sans Medium"
        font.pointSize: 14
        anchors.centerIn: root
    }
}
