import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "../../theme"

PanelWindow {
    id: clipboardWindow

    implicitWidth: 600
    implicitHeight: 750
    color: "transparent"
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "clipboard_overlay"
    exclusiveZone: -1

    anchors.bottom: true
    margins.bottom: 100

    // Hook up Backend Engine
    ClipboardBackend {
        id: ctrl

        onOpenMenuRequested: {
            if (clipboardWindow.visible) {
                closeMenu();
            } else {
                ctrl.triggerRefresh();
                searchField.text = "";
                ctrl.searchText = "";
                clipboardWindow.visible = true;
                focusGrab.active = true;
                mainUi.forceActiveFocus();
                listView.currentIndex = 0;
            }
        }

        onCloseMenuRequested: {
            closeMenu();
        }
    }

    HyprlandFocusGrab {
        id: focusGrab
        windows: [clipboardWindow]
        onCleared: closeMenu()
    }

    function closeMenu() {
        clipboardWindow.visible = false;
        focusGrab.active = false;
    }

    Item {
        id: delegateContainer
        anchors.fill: parent
        anchors.margins: 30

        Rectangle {
            id: shadowCaster
            anchors.fill: mainUi
            radius: 28
            color: "black"
            visible: false
        }

        MultiEffect {
            anchors.fill: shadowCaster
            source: shadowCaster
            shadowEnabled: true
            shadowBlur: 1.0
            shadowColor: "#60000000"
            shadowVerticalOffset: 12
        }

        Rectangle {
            id: mainUiMask
            anchors.fill: mainUi
            radius: 28
            color: "black"
            visible: false
            layer.enabled: true
        }

        Rectangle {
            id: mainUi
            anchors.fill: parent
            color: Theme.surface_container
            radius: 28
            focus: true

            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: mainUiMask
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_H) {
                    closeMenu();
                } else if (event.key === Qt.Key_X) {
                    if (listView.currentItem) {
                        listView.currentItem.remove();
                    }
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                    listView.incrementCurrentIndex();
                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                    listView.decrementCurrentIndex();
                } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return || event.key === Qt.Key_L) {
                    if (listView.currentItem)
                        listView.currentItem.select();
                } else if (event.key === Qt.Key_Slash) {
                    searchField.forceActiveFocus();
                    event.accepted = true;
                }
                event.accepted = true;
            }

            // Header Area
            Item {
                id: headerArea
                width: parent.width
                height: 72
                anchors.top: parent.top

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 24
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Clipboard"
                    color: Theme.on_surface
                    font {
                        family: "Google Sans Medium"
                        pixelSize: 26
                    }
                }

                Rectangle {
                    id: clearButton
                    anchors.right: parent.right
                    anchors.rightMargin: 24
                    anchors.verticalCenter: parent.verticalCenter
                    width: clearText.implicitWidth + 32
                    height: 36
                    radius: 18
                    scale: clearMouseArea.pressed ? 0.92 : (clearMouseArea.containsMouse ? 1.05 : 1.0)
                    color: clearMouseArea.containsMouse ? Theme.critical : "transparent"
                    border.width: 1
                    border.color: clearMouseArea.containsMouse ? Theme.critical : Theme.outline

                    Behavior on scale {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutBack
                        }
                    }

                    Text {
                        id: clearText
                        anchors.centerIn: parent
                        text: "Clear"
                        color: clearMouseArea.containsMouse ? Theme.on_critical : Theme.on_surface_variant
                        font {
                            family: "Google Sans Medium"
                            pixelSize: 16
                        }
                    }

                    MouseArea {
                        id: clearMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ctrl.clearAllHistory()
                    }
                }
            }

            // Search Bar Text Input Field
            Item {
                id: searchArea
                width: parent.width
                height: 80
                anchors.top: headerArea.bottom

                TextField {
                    id: searchField
                    anchors.fill: parent
                    anchors.margins: 12
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    leftPadding: 48
                    rightPadding: searchField.text !== "" ? 48 : 16
                    font {
                        family: "Google Sans"
                        pixelSize: 17
                    }
                    color: Theme.on_surface
                    selectionColor: Theme.primary_container
                    selectedTextColor: Theme.on_primary_container
                    placeholderText: "Search"
                    placeholderTextColor: Theme.on_surface_variant

                    background: Rectangle {
                        id: searchBg
                        color: searchField.activeFocus ? Theme.surface_container_highest : Theme.surface_container_high
                        radius: 28
                        border.width: searchField.activeFocus ? 2 : 1
                        border.color: searchField.activeFocus ? Theme.primary : Theme.outline_variant
                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            text: "search"
                            font {
                                family: "Material Symbols Rounded"
                                pixelSize: 22
                            }
                            color: searchField.activeFocus ? Theme.primary : Theme.on_surface_variant
                        }
                    }

                    onTextChanged: ctrl.searchText = text

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Down) {
                            listView.incrementCurrentIndex();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            listView.decrementCurrentIndex();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                            if (listView.currentItem)
                                listView.currentItem.select();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            mainUi.forceActiveFocus();
                            event.accepted = true;
                        }
                    }
                }
            }

            // List Render Area Layout Container
            Item {
                id: listContainer
                anchors.top: searchArea.bottom
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right

                clip: true

                ListView {
                    id: listView
                    anchors.fill: parent
                    topMargin: 12
                    bottomMargin: 48
                    model: ctrl.filteredItems
                    spacing: 8
                    highlightMoveDuration: 80
                    highlightFollowsCurrentItem: true

                    delegate: ClipboardDelegate {}
                }

                // Fade Gradient
                Rectangle {
                    anchors {
                        bottom: parent.bottom
                        left: parent.left
                        right: parent.right
                    }
                    height: 48
                    gradient: Gradient {
                        GradientStop {
                            position: 0.0
                            color: "transparent"
                        }
                        GradientStop {
                            position: 1.0
                            color: Theme.surface_container
                        }
                    }
                }
            }

            Text {
                id: emptyMessage
                anchors.centerIn: listContainer
                text: ctrl.allItems.length === 0 ? "Clipboard is empty :(" : "No results found :/"
                visible: ctrl.filteredItems.length === 0
                color: Theme.on_surface_variant
                font {
                    family: "Google Sans Medium"
                    pixelSize: 18
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            radius: 28
            border {
                width: 1
                color: Theme.outline_variant
            }
            z: 99
        }
    }
}
