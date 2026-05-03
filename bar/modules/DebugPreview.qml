import QtQuick
import Quickshell

PopupWindow {
    id: root

    // Hardcoded size and position to force visibility
    x: 500
    y: 500
    width: 200
    height: 100

    // Make sure it's on top
    visible: true
    color: "transparent"

    // Use a simple red rectangle
    Rectangle {
        anchors.fill: parent
        color: "red"
        border.color: "yellow"
        border.width: 5

        Text {
            anchors.centerIn: parent
            text: "IF YOU SEE THIS,\nTHE POPUP WORKS"
            color: "white"
        }
    }

    // Log when this object is created
    Component.onCompleted: console.log("DebugPreview: Created successfully!")
}
