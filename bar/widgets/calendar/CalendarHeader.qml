import QtQuick
import qs.theme

Item {
    id: root
    height: 36

    property bool isMonthYearView
    property int displayMonth
    property int displayYear

    signal toggleView
    signal jumpToToday
    signal previousClicked
    signal nextClicked

    Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: monthYearText.width + 24
        height: 36
        radius: 18
        color: monthYearMouse.containsMouse ? Theme.surface_variant : "transparent"
        scale: monthYearMouse.pressed ? 0.95 : 1.0

        Behavior on scale {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutBack
                easing.overshoot: 1.05
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }

        Text {
            id: monthYearText
            anchors.centerIn: parent
            text: root.isMonthYearView ? "Select Month" : Qt.formatDate(new Date(root.displayYear, root.displayMonth, 1), "MMMM yyyy")
            color: Theme.on_surface
            font.family: "Google Sans"
            font.pointSize: 16
            font.weight: Font.Medium
        }

        MouseArea {
            id: monthYearMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleView()
        }
    }

    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12
        opacity: root.isMonthYearView ? 0 : 1
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }

        // Today Button
        Rectangle {
            width: 72
            height: 36
            radius: 18
            color: todayMouse.containsMouse ? Theme.surface_variant : "transparent"
            border.color: Theme.outline_variant
            border.width: 1
            scale: todayMouse.pressed ? 0.95 : (todayMouse.containsMouse ? 1.05 : 1.0)

            Behavior on scale {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.05
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: 100
                }
            }

            Text {
                anchors.centerIn: parent
                text: "Today"
                color: Theme.primary
                font.family: "Google Sans"
                font.pointSize: 11
                font.weight: Font.Bold
            }
            MouseArea {
                id: todayMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.jumpToToday()
            }
        }

        // Prev Button
        Rectangle {
            width: 36
            height: 36
            radius: 18
            color: prevMouse.containsMouse ? Theme.surface_variant : "transparent"
            scale: prevMouse.pressed ? 0.9 : (prevMouse.containsMouse ? 1.05 : 1.0)

            Behavior on scale {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.05
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: 100
                }
            }

            Text {
                anchors.centerIn: parent
                text: "❮"
                color: Theme.on_surface
                font.pointSize: 12
            }
            MouseArea {
                id: prevMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.previousClicked()
            }
        }

        // Next Button
        Rectangle {
            width: 36
            height: 36
            radius: 18
            color: nextMouse.containsMouse ? Theme.surface_variant : "transparent"
            scale: nextMouse.pressed ? 0.9 : (nextMouse.containsMouse ? 1.05 : 1.0)

            Behavior on scale {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.05
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: 100
                }
            }

            Text {
                anchors.centerIn: parent
                text: "❯"
                color: Theme.on_surface
                font.pointSize: 12
            }
            MouseArea {
                id: nextMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.nextClicked()
            }
        }
    }
}
