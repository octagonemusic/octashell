import QtQuick
import qs.theme
import qs.bar.widgets

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
        id: monthYearPill
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: monthYearText.width + 24
        height: 36
        radius: 18
        color: "transparent"

        transform: Scale {
            origin.x: monthYearPill.width / 2
            origin.y: monthYearPill.height / 2
            xScale: monthYearMouse.pressed ? 1.05 : 1.0
            yScale: monthYearMouse.pressed ? 0.9 : 1.0

            Behavior on xScale {
                NumberAnimation {
                    duration: monthYearMouse.pressed ? 100 : 150
                    easing.type: monthYearMouse.pressed ? Easing.OutQuad : Easing.OutBack
                    easing.overshoot: 1.05
                }
            }
            Behavior on yScale {
                NumberAnimation {
                    duration: monthYearMouse.pressed ? 100 : 150
                    easing.type: monthYearMouse.pressed ? Easing.OutQuad : Easing.OutBack
                    easing.overshoot: 1.05
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.primary
            opacity: monthYearMouse.pressed ? 0.10 : (monthYearMouse.containsMouse ? 0.08 : 0.0)

            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutQuad
                }
            }
        }

        Ripple {
            id: monthYearRipple
            cornerRadius: monthYearPill.radius
            rippleColor: Theme.primary
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
            onPressed: mouse => monthYearRipple.trigger(mouse.x, mouse.y)
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
            id: todayButton
            width: 72
            height: 36
            radius: 18
            color: "transparent"
            border.color: Theme.outline_variant
            border.width: 1

            transform: Scale {
                origin.x: todayButton.width / 2
                origin.y: todayButton.height / 2
                xScale: todayMouse.pressed ? 1.06 : (todayMouse.containsMouse ? 1.05 : 1.0)
                yScale: todayMouse.pressed ? 0.88 : (todayMouse.containsMouse ? 1.05 : 1.0)

                Behavior on xScale {
                    NumberAnimation {
                        duration: todayMouse.pressed ? 100 : 150
                        easing.type: todayMouse.pressed ? Easing.OutQuad : Easing.OutBack
                        easing.overshoot: 1.05
                    }
                }
                Behavior on yScale {
                    NumberAnimation {
                        duration: todayMouse.pressed ? 100 : 150
                        easing.type: todayMouse.pressed ? Easing.OutQuad : Easing.OutBack
                        easing.overshoot: 1.05
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Theme.primary
                opacity: todayMouse.pressed ? 0.10 : (todayMouse.containsMouse ? 0.08 : 0.0)

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutQuad
                    }
                }
            }

            Ripple {
                id: todayRipple
                cornerRadius: todayButton.radius
                rippleColor: Theme.primary
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
                onPressed: mouse => todayRipple.trigger(mouse.x, mouse.y)
                onClicked: root.jumpToToday()
            }
        }

        // Prev Button
        Rectangle {
            id: prevButton
            width: 36
            height: 36
            radius: 18
            color: "transparent"

            transform: Scale {
                origin.x: prevButton.width / 2
                origin.y: prevButton.height / 2
                xScale: prevMouse.pressed ? 1.08 : (prevMouse.containsMouse ? 1.05 : 1.0)
                yScale: prevMouse.pressed ? 0.84 : (prevMouse.containsMouse ? 1.05 : 1.0)

                Behavior on xScale {
                    NumberAnimation {
                        duration: prevMouse.pressed ? 100 : 150
                        easing.type: prevMouse.pressed ? Easing.OutQuad : Easing.OutBack
                        easing.overshoot: 1.05
                    }
                }
                Behavior on yScale {
                    NumberAnimation {
                        duration: prevMouse.pressed ? 100 : 150
                        easing.type: prevMouse.pressed ? Easing.OutQuad : Easing.OutBack
                        easing.overshoot: 1.05
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Theme.on_surface
                opacity: prevMouse.pressed ? 0.10 : (prevMouse.containsMouse ? 0.08 : 0.0)

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutQuad
                    }
                }
            }

            Ripple {
                id: prevRipple
                cornerRadius: prevButton.radius
                rippleColor: Theme.primary
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
                onPressed: mouse => prevRipple.trigger(mouse.x, mouse.y)
                onClicked: root.previousClicked()
            }
        }

        // Next Button
        Rectangle {
            id: nextButton
            width: 36
            height: 36
            radius: 18
            color: "transparent"

            transform: Scale {
                origin.x: nextButton.width / 2
                origin.y: nextButton.height / 2
                xScale: nextMouse.pressed ? 1.08 : (nextMouse.containsMouse ? 1.05 : 1.0)
                yScale: nextMouse.pressed ? 0.84 : (nextMouse.containsMouse ? 1.05 : 1.0)

                Behavior on xScale {
                    NumberAnimation {
                        duration: nextMouse.pressed ? 100 : 150
                        easing.type: nextMouse.pressed ? Easing.OutQuad : Easing.OutBack
                        easing.overshoot: 1.05
                    }
                }
                Behavior on yScale {
                    NumberAnimation {
                        duration: nextMouse.pressed ? 100 : 150
                        easing.type: nextMouse.pressed ? Easing.OutQuad : Easing.OutBack
                        easing.overshoot: 1.05
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Theme.on_surface
                opacity: nextMouse.pressed ? 0.10 : (nextMouse.containsMouse ? 0.08 : 0.0)

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutQuad
                    }
                }
            }

            Ripple {
                id: nextRipple
                cornerRadius: nextButton.radius
                rippleColor: Theme.primary
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
                onPressed: mouse => nextRipple.trigger(mouse.x, mouse.y)
                onClicked: root.nextClicked()
            }
        }
    }
}
