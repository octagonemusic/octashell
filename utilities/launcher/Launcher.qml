import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "../../theme"

PanelWindow {
    id: launcherWindow

    implicitWidth: 760
    implicitHeight: 680
    color: "transparent"
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "launcher_overlay"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusiveZone: -1

    anchors {
        bottom: true
    }

    margins {
        bottom: 170
    }

    LauncherBackend {
        id: ctrl

        onOpenMenuRequested: {
            if (launcherWindow.visible) {
                closeMenu();
            } else {
                searchField.text = "";
                ctrl.searchText = "";
                launcherWindow.visible = true;
                focusGrab.active = true;

                // Starts directly in Search Mode
                searchField.forceActiveFocus();
                listView.currentIndex = 0;
            }
        }

        onCloseMenuRequested: closeMenu()
    }

    HyprlandFocusGrab {
        id: focusGrab
        windows: [launcherWindow]
        onCleared: closeMenu()
    }

    function closeMenu() {
        launcherWindow.visible = false;
        focusGrab.active = false;
    }

    Item {
        anchors.fill: parent
        anchors.margins: 40
        anchors.bottomMargin: 10

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
            shadowBlur: 2.5
            shadowColor: "#70000000"
            shadowVerticalOffset: 16
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

            // --- NORMAL MODE LOGIC (hjkl) ---
            Keys.onPressed: event => {
                if (searchField.activeFocus)
                    return;

                if (event.key === Qt.Key_Escape) {
                    closeMenu();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Slash || event.key === Qt.Key_I) {
                    searchField.forceActiveFocus();
                    event.accepted = true;
                } else if (event.key === Qt.Key_J || event.key === Qt.Key_Down) {
                    listView.incrementCurrentIndex();
                    event.accepted = true;
                } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) {
                    listView.decrementCurrentIndex();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                    if (listView.currentItem)
                        listView.currentItem.launch();
                    event.accepted = true;
                }
            }

            // --- HERO SEARCH AREA ---
            Item {
                id: searchArea
                width: parent.width
                height: 84 // Perfectly balanced for the new font size
                anchors.top: parent.top

                TextField {
                    id: searchField
                    anchors.fill: parent
                    leftPadding: 68
                    rightPadding: 32

                    font {
                        family: "Google Sans"
                        pixelSize: 26 // The sweet spot: Big, but not screaming

                        weight: Font.Medium
                    }
                    color: Theme.on_surface
                    selectionColor: Theme.primary_container
                    selectedTextColor: Theme.on_primary_container

                    // Restored your requested text
                    placeholderText: "What do you want to open?"
                    placeholderTextColor: Theme.on_surface_variant

                    background: Item {
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 24
                            anchors.verticalCenter: parent.verticalCenter
                            text: "search"
                            font {
                                family: "Material Symbols Rounded"
                                pixelSize: 32
                            }
                            color: searchField.activeFocus ? Theme.primary : Theme.on_surface_variant
                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }
                        }
                    }

                    onTextChanged: {
                        ctrl.searchText = text;
                        listView.currentIndex = 0;
                    }

                    // --- SEARCH MODE LOGIC ---
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            mainUi.forceActiveFocus(); // Drop into Normal Mode
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                            if (listView.currentItem)
                                listView.currentItem.launch();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_J && (event.modifiers & Qt.ControlModifier))) {
                            listView.incrementCurrentIndex();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up || (event.key === Qt.Key_K && (event.modifiers & Qt.ControlModifier))) {
                            listView.decrementCurrentIndex();
                            event.accepted = true;
                        }
                    }
                }

                // Subtle separator line
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 24
                    anchors.rightMargin: 24
                    height: 1
                    color: Theme.outline_variant
                    opacity: 0.4
                }
            }

            // --- RICH LIST AREA ---
            Item {
                id: listContainer
                anchors.top: searchArea.bottom
                anchors.bottom: footer.top
                anchors.left: parent.left
                anchors.right: parent.right
                clip: true

                ListView {
                    id: listView
                    anchors.fill: parent
                    topMargin: 12
                    bottomMargin: 24
                    spacing: 4

                    highlightMoveDuration: 120
                    highlightFollowsCurrentItem: true
                    delegate: LauncherDelegate {}

                    model: ScriptModel {
                        values: {
                            let allApps = DesktopEntries.applications.values;
                            let query = ctrl.searchText.toLowerCase().trim();
                            if (query === "")
                                return allApps;

                            return allApps.filter(entry => {
                                let str = entry.name.toLowerCase();
                                let i = 0, j = 0;
                                while (i < str.length && j < query.length) {
                                    if (str[i] === query[j])
                                        j++;
                                    i++;
                                }
                                return j === query.length;
                            });
                        }
                    }
                }

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
                text: "No matching applications"
                visible: listView.count === 0
                color: Theme.on_surface_variant
                font {
                    family: "Google Sans Medium"
                    pixelSize: 18
                }
            }

            // --- MINIMALIST FOOTER ---
            Item {
                id: footer
                anchors {
                    bottom: parent.bottom
                    left: parent.left
                    right: parent.right
                }
                height: 48

                Text {
                    anchors.centerIn: parent
                    text: "[/] Search  •  [Enter] Launch  •  [J/K] Navigate  •  [Esc] Close"
                    color: Theme.on_surface_variant
                    opacity: 0.7
                    font {
                        family: "Google Sans"
                        pixelSize: 12
                        weight: Font.Medium
                        letterSpacing: 0.5
                    }
                }
            }
        }
    }
}
