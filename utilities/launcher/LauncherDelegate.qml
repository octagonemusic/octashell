import QtQuick
import Quickshell.Widgets
import "../../theme"

Item {
    id: delegateRoot
    width: ListView.view.width
    height: 72

    property bool isSelected: ListView.isCurrentItem
    property bool isHovered: itemMouseArea.containsMouse

    property string descriptionText: modelData.genericName ? modelData.genericName : (modelData.comment ? modelData.comment : "")

    function launch() {
        ctrl.launchApp(modelData);
    }

    Rectangle {
        id: itemBox
        anchors.centerIn: parent
        width: parent.width - 32
        height: parent.height - 4
        radius: 16

        scale: itemMouseArea.pressed ? 0.98 : (delegateRoot.isSelected || delegateRoot.isHovered ? 1.015 : 1.0)
        Behavior on scale {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutBack
            }
        }

        color: delegateRoot.isSelected ? Theme.secondary_container : (delegateRoot.isHovered ? Qt.lighter(Theme.surface_container_low, 1.08) : "transparent")
        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }

        Rectangle {
            id: activeIndicator
            width: 4
            height: delegateRoot.isSelected ? parent.height * 0.5 : 0
            opacity: delegateRoot.isSelected ? 1.0 : 0.0
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            radius: 2
            color: Theme.primary
            Behavior on height {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutQuart
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                }
            }
        }

        IconImage {
            id: appIcon
            width: 42
            height: 42
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter

            source: {
                if (!modelData.icon || modelData.icon === "") {
                    return "image://icon/application-x-executable";
                }
                if (modelData.icon.startsWith("/")) {
                    return "file://" + modelData.icon;
                }
                return "image://icon/" + modelData.icon;
            }

            onStatusChanged: {
                if (status === Image.Error) {
                    source = "image://icon/application-x-executable";
                }
            }
        }

        Column {
            anchors.left: appIcon.right
            anchors.right: launchPill.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 2

            Text {
                width: parent.width
                text: modelData.name
                color: delegateRoot.isSelected ? Theme.on_secondary_container : Theme.on_surface
                elide: Text.ElideRight
                font {
                    family: "Google Sans"
                    pixelSize: 16
                    weight: Font.DemiBold
                }
            }

            Text {
                width: parent.width
                text: delegateRoot.descriptionText
                visible: delegateRoot.descriptionText !== ""
                color: delegateRoot.isSelected ? Theme.on_secondary_container : Theme.on_surface_variant
                opacity: delegateRoot.isSelected ? 0.8 : 1.0
                elide: Text.ElideRight
                font {
                    family: "Google Sans"
                    pixelSize: 13
                }
            }
        }

        Rectangle {
            id: launchPill
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 86
            height: 32
            radius: 16
            color: Theme.primary
            opacity: delegateRoot.isSelected ? 1.0 : 0.0
            scale: delegateRoot.isSelected ? 1.0 : 0.8

            Behavior on opacity {
                NumberAnimation {
                    duration: 100
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 100
                    easing.type: Easing.OutBack
                }
            }

            Row {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    topPadding: 2
                    verticalAlignment: Text.AlignVCenter
                    text: "Launch"
                    color: Theme.on_primary
                    font {
                        family: "Google Sans Medium"
                        pixelSize: 13
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    topPadding: 2
                    verticalAlignment: Text.AlignVCenter
                    text: "keyboard_return"
                    color: Theme.on_primary
                    font {
                        family: "Material Symbols Rounded"
                        pixelSize: 16
                    }
                }
            }
        }

        MouseArea {
            id: itemMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: delegateRoot.ListView.view.currentIndex = index
            onClicked: delegateRoot.launch()
        }
    }
}
