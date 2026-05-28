import QtQuick
import qs.theme

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

            // Sliding Selection Circle
            Rectangle {
                width: 46
                height: 46
                radius: 23
                color: Theme.primary
                opacity: root.activeCellIndex !== -1 ? 1 : 0
                x: (root.lastValidIndex % 7) * 54
                y: Math.floor(root.lastValidIndex / 7) * 54

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

                        color: (dayMouse.containsMouse && model.isCurrentMonth && !isSelectedDay) ? Theme.surface_variant : "transparent"
                        border.color: model.isToday && !isSelectedDay ? Theme.primary : "transparent"
                        border.width: model.isToday && !isSelectedDay ? 2 : 0
                        scale: dayMouse.pressed && model.isCurrentMonth ? 0.90 : (dayMouse.containsMouse && model.isCurrentMonth ? 1.1 : 1.0)

                        Behavior on scale {
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutBack
                                easing.overshoot: 1.1
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: 100
                            }
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
