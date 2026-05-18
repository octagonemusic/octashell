//@ pragma IconTheme Papirus

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
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusiveZone: -1

    anchors {
        bottom: true
    }

    margins {
        bottom: 170
    }

    function scoreMatch(name, query) {
        var nameLower = name.toLowerCase();
        var queryLower = query.toLowerCase();

        // Exact match
        if (nameLower === queryLower)
            return 1000;

        // Full name starts with query
        if (nameLower.startsWith(queryLower))
            return 800;

        // Any word in the name starts with query
        var words = nameLower.split(/[\s\-_]+/);
        for (var i = 0; i < words.length; i++) {
            if (words[i].startsWith(queryLower))
                return 600;
        }

        // single/double letter matches polluting short queries
        if (query.length >= 3 && nameLower.indexOf(queryLower) !== -1)
            return 200;

        return -1;
    }

    function buildFilteredList() {
        var allApps = DesktopEntries.applications.values;
        var query = ctrl.searchText.trim();

        if (query === "") {
            return allApps.slice().sort((a, b) => a.name.localeCompare(b.name));
        }

        var scored = [];
        for (var i = 0; i < allApps.length; i++) {
            var entry = allApps[i];

            var best = scoreMatch(entry.name, query);

            if (best < 0) {
                if (entry.genericName) {
                    var gs = scoreMatch(entry.genericName, query);
                    if (gs >= 600) // only word-prefix or better from secondary fields
                        best = Math.max(best, gs - 100);
                }
            }

            if (best >= 0)
                scored.push({
                    entry: entry,
                    score: best
                });
        }

        scored.sort((a, b) => {
            if (b.score !== a.score)
                return b.score - a.score;
            return a.entry.name.localeCompare(b.entry.name);
        });

        return scored.map(s => s.entry);
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
        anchors.margins: 80
        anchors.bottomMargin: 50

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
            shadowBlur: 1.5
            shadowColor: "#60000000"
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

            Item {
                id: edgeBanner
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 180

                Image {
                    anchors.fill: parent
                    source: Theme.wallpaper
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                Rectangle {
                    anchors.fill: parent
                    color: Theme.primary
                    opacity: 0.15
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 80
                    gradient: Gradient {
                        GradientStop {
                            position: 0.0
                            color: "transparent"
                        }
                        GradientStop {
                            position: 1.0
                            color: "#40000000"
                        }
                    }
                }
            }

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

            Rectangle {
                id: searchArea
                height: 64
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 32
                anchors.rightMargin: 32

                anchors.verticalCenter: edgeBanner.bottom

                radius: height / 2
                color: Theme.surface_container_highest

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowBlur: 1.0
                    shadowColor: "#40000000"
                    shadowVerticalOffset: 4
                }

                TextField {
                    id: searchField
                    anchors.fill: parent
                    leftPadding: 60
                    rightPadding: 24

                    font {
                        family: "Google Sans"
                        pixelSize: 22
                        weight: Font.Medium
                    }
                    color: Theme.on_surface
                    selectionColor: Theme.primary_container
                    selectedTextColor: Theme.on_primary_container

                    placeholderText: "Search apps..."
                    placeholderTextColor: Theme.on_surface_variant

                    background: Item {
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 20
                            anchors.verticalCenter: parent.verticalCenter
                            text: "search"
                            font {
                                family: "Material Symbols Rounded"
                                pixelSize: 28
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

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            mainUi.forceActiveFocus();
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
            }

            Item {
                id: listContainer
                anchors.top: searchArea.bottom
                anchors.topMargin: 16 // Breathing room below the floating pill
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
                        values: launcherWindow.buildFilteredList()
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
