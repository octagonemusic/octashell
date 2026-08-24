import QtQuick
import QtQuick.Effects
import qs.theme
import qs.bar.widgets

Item {
    id: root

    property int displayYear
    property int displayMonth

    signal previousYear
    signal nextYear
    signal monthSelected(int monthIndex)

    Column {
        anchors.centerIn: parent
        spacing: 32

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 24

            Rectangle {
                id: yearPrevButton
                width: 40
                height: 40
                radius: 20
                color: "transparent"

                transform: Scale {
                    origin.x: yearPrevButton.width / 2
                    origin.y: yearPrevButton.height / 2
                    xScale: yearPrevMouse.pressed ? 1.1 : (yearPrevMouse.containsMouse ? 1.1 : 1.0)
                    yScale: yearPrevMouse.pressed ? 0.8 : (yearPrevMouse.containsMouse ? 1.1 : 1.0)

                    Behavior on xScale {
                        NumberAnimation {
                            duration: yearPrevMouse.pressed ? 100 : 150
                            easing.type: yearPrevMouse.pressed ? Easing.OutQuad : Easing.OutBack
                            easing.overshoot: 1.1
                        }
                    }
                    Behavior on yScale {
                        NumberAnimation {
                            duration: yearPrevMouse.pressed ? 100 : 150
                            easing.type: yearPrevMouse.pressed ? Easing.OutQuad : Easing.OutBack
                            easing.overshoot: 1.1
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Theme.on_surface
                    opacity: yearPrevMouse.pressed ? 0.10 : (yearPrevMouse.containsMouse ? 0.08 : 0.0)

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutQuad
                        }
                    }
                }

                Ripple {
                    id: yearPrevRipple
                    cornerRadius: yearPrevButton.radius
                    rippleColor: Theme.primary
                }

                Text {
                    anchors.centerIn: parent
                    text: "❮"
                    color: Theme.on_surface
                    font.pointSize: 14
                }
                MouseArea {
                    id: yearPrevMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => yearPrevRipple.trigger(mouse.x, mouse.y)
                    onClicked: root.previousYear()
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.displayYear.toString()
                color: Theme.on_surface
                font.family: "Google Sans"
                font.pointSize: 22
                font.weight: Font.Bold
            }

            Rectangle {
                id: yearNextButton
                width: 40
                height: 40
                radius: 20
                color: "transparent"

                transform: Scale {
                    origin.x: yearNextButton.width / 2
                    origin.y: yearNextButton.height / 2
                    xScale: yearNextMouse.pressed ? 1.1 : (yearNextMouse.containsMouse ? 1.1 : 1.0)
                    yScale: yearNextMouse.pressed ? 0.8 : (yearNextMouse.containsMouse ? 1.1 : 1.0)

                    Behavior on xScale {
                        NumberAnimation {
                            duration: yearNextMouse.pressed ? 100 : 150
                            easing.type: yearNextMouse.pressed ? Easing.OutQuad : Easing.OutBack
                            easing.overshoot: 1.1
                        }
                    }
                    Behavior on yScale {
                        NumberAnimation {
                            duration: yearNextMouse.pressed ? 100 : 150
                            easing.type: yearNextMouse.pressed ? Easing.OutQuad : Easing.OutBack
                            easing.overshoot: 1.1
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Theme.on_surface
                    opacity: yearNextMouse.pressed ? 0.10 : (yearNextMouse.containsMouse ? 0.08 : 0.0)

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutQuad
                        }
                    }
                }

                Ripple {
                    id: yearNextRipple
                    cornerRadius: yearNextButton.radius
                    rippleColor: Theme.primary
                }

                Text {
                    anchors.centerIn: parent
                    text: "❯"
                    color: Theme.on_surface
                    font.pointSize: 14
                }
                MouseArea {
                    id: yearNextMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => yearNextRipple.trigger(mouse.x, mouse.y)
                    onClicked: root.nextYear()
                }
            }
        }

        Item {
            width: monthGrid.implicitWidth
            height: monthGrid.implicitHeight
            anchors.horizontalCenter: parent.horizontalCenter

            // Sliding Pill
            Rectangle {
                width: 76
                height: 48
                radius: 24
                color: Theme.primary
                x: (root.displayMonth % 4) * 88
                y: Math.floor(root.displayMonth / 4) * 60

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowBlur: 0.6
                    shadowColor: "#40000000"
                    shadowVerticalOffset: 3
                }

                Behavior on x {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.1
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.1
                    }
                }
            }

            Grid {
                id: monthGrid
                columns: 4
                spacing: 12

                Repeater {
                    model: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
                    Rectangle {
                        id: monthCell
                        width: 76
                        height: 48
                        radius: 24
                        readonly property bool isSelectedMonth: index === root.displayMonth
                        color: "transparent"

                        transform: Scale {
                            origin.x: monthCell.width / 2
                            origin.y: monthCell.height / 2
                            xScale: monthMouse.pressed ? 1.06 : (monthMouse.containsMouse && !monthCell.isSelectedMonth ? 1.05 : 1.0)
                            yScale: monthMouse.pressed ? 0.82 : (monthMouse.containsMouse && !monthCell.isSelectedMonth ? 1.05 : 1.0)

                            Behavior on xScale {
                                NumberAnimation {
                                    duration: monthMouse.pressed ? 100 : 150
                                    easing.type: monthMouse.pressed ? Easing.OutQuad : Easing.OutBack
                                    easing.overshoot: 1.05
                                }
                            }
                            Behavior on yScale {
                                NumberAnimation {
                                    duration: monthMouse.pressed ? 100 : 150
                                    easing.type: monthMouse.pressed ? Easing.OutQuad : Easing.OutBack
                                    easing.overshoot: 1.05
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            visible: !monthCell.isSelectedMonth
                            color: Theme.on_surface
                            opacity: monthMouse.pressed ? 0.10 : (monthMouse.containsMouse ? 0.08 : 0.0)

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutQuad
                                }
                            }
                        }

                        Ripple {
                            id: monthRipple
                            cornerRadius: monthCell.radius
                            rippleColor: monthCell.isSelectedMonth ? Theme.on_primary : Theme.primary
                        }

                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: isSelectedMonth ? Theme.on_primary : Theme.on_surface
                            font.family: "Google Sans"
                            font.pointSize: 13
                            font.weight: isSelectedMonth ? Font.Bold : Font.Medium
                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }
                        }

                        MouseArea {
                            id: monthMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: mouse => monthRipple.trigger(mouse.x, mouse.y)
                            onClicked: root.monthSelected(index)
                        }
                    }
                }
            }
        }
    }
}
