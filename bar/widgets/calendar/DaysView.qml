import QtQuick
import QtQuick.Effects
import qs.theme
import qs.bar.widgets

Item {
    id: root

    property alias model: daysRepeater.model
    property int activeCellIndex
    property int lastValidIndex
    property int selectedDay
    property int selectedMonth
    property int selectedYear
    property int displayMonth
    property int displayYear

    signal daySelected(int day)

    Column {
        id: gridContainer
        spacing: 12
        anchors.centerIn: parent

        // Days of week header
        Grid {
            columns: 7
            spacing: 8
            Repeater {
                model: ["S", "M", "T", "W", "T", "F", "S"]
                Item {
                    width: 46
                    height: 24
                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: Theme.on_surface_variant
                        font.family: "Google Sans"
                        font.pointSize: 12
                        font.weight: Font.Medium
                    }
                }
            }
        }

        Item {
            width: daysGrid.implicitWidth
            height: daysGrid.implicitHeight

            // Soft glow echoing the ClockPane's blob motif, tied to the selection
            Rectangle {
                width: 62
                height: 62
                radius: 31
                color: Theme.primary
                opacity: root.activeCellIndex !== -1 ? 0.16 : 0
                x: (root.lastValidIndex % 7) * 54 - 8
                y: Math.floor(root.lastValidIndex / 7) * 54 - 8
                transformOrigin: Item.Center

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
                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                    }
                }

                SequentialAnimation on scale {
                    loops: Animation.Infinite
                    running: root.activeCellIndex !== -1
                    NumberAnimation {
                        to: 1.12
                        duration: 1800
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: 1.0
                        duration: 1800
                        easing.type: Easing.InOutSine
                    }
                }
            }

            // Sliding Selection Circle
            Rectangle {
                id: selectionCircle
                width: 46
                height: 46
                radius: 23
                color: Theme.primary
                opacity: root.activeCellIndex !== -1 ? 1 : 0
                x: (root.lastValidIndex % 7) * 54
                y: Math.floor(root.lastValidIndex / 7) * 54

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
                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }
                }
            }

            Grid {
                id: daysGrid
                columns: 7
                spacing: 8

                Repeater {
                    id: daysRepeater
                    Rectangle {
                        id: dayCell
                        width: 46
                        height: 46
                        radius: 23
                        readonly property bool isSelectedDay: (model.isCurrentMonth && parseInt(model.dayText) === root.selectedDay && root.displayMonth === root.selectedMonth && root.displayYear === root.selectedYear)

                        color: "transparent"
                        border.color: model.isToday && !isSelectedDay ? Theme.primary : "transparent"
                        border.width: model.isToday && !isSelectedDay ? 2 : 0

                        transform: Scale {
                            origin.x: dayCell.width / 2
                            origin.y: dayCell.height / 2
                            xScale: dayMouse.pressed && model.isCurrentMonth ? 1.08 : (dayMouse.containsMouse && model.isCurrentMonth ? 1.1 : 1.0)
                            yScale: dayMouse.pressed && model.isCurrentMonth ? 0.86 : (dayMouse.containsMouse && model.isCurrentMonth ? 1.1 : 1.0)

                            Behavior on xScale {
                                NumberAnimation {
                                    duration: dayMouse.pressed ? 100 : 150
                                    easing.type: dayMouse.pressed ? Easing.OutQuad : Easing.OutBack
                                    easing.overshoot: 1.1
                                }
                            }
                            Behavior on yScale {
                                NumberAnimation {
                                    duration: dayMouse.pressed ? 100 : 150
                                    easing.type: dayMouse.pressed ? Easing.OutQuad : Easing.OutBack
                                    easing.overshoot: 1.1
                                }
                            }
                        }

                        // State layer: fractional-opacity overlay per M3 spec (8% hover, 10% pressed)
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            visible: model.isCurrentMonth && !dayCell.isSelectedDay
                            color: Theme.on_surface
                            opacity: dayMouse.pressed ? 0.10 : (dayMouse.containsMouse ? 0.08 : 0.0)

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutQuad
                                }
                            }
                        }

                        Ripple {
                            id: dayRipple
                            cornerRadius: dayCell.radius
                            rippleColor: dayCell.isSelectedDay ? Theme.on_primary : Theme.primary
                        }

                        Text {
                            anchors.centerIn: parent
                            text: model.dayText
                            font.family: "Google Sans"
                            font.pointSize: 13
                            font.weight: dayCell.isSelectedDay || model.isToday ? Font.Bold : Font.Medium
                            color: dayCell.isSelectedDay ? Theme.on_primary : (model.isToday ? Theme.primary : (!model.isCurrentMonth ? Theme.outline : Theme.on_surface))
                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }
                        }

                        MouseArea {
                            id: dayMouse
                            anchors.fill: parent
                            hoverEnabled: model.isCurrentMonth
                            cursorShape: model.isCurrentMonth ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onPressed: mouse => {
                                if (model.isCurrentMonth)
                                    dayRipple.trigger(mouse.x, mouse.y);
                            }
                            onClicked: {
                                if (model.isCurrentMonth) {
                                    root.daySelected(parseInt(model.dayText));
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
