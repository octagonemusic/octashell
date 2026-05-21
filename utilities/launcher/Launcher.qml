import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "../../theme"

PanelWindow {
    id: launcherWindow

    // Add any apps you want to hide to this list
    property var hiddenKeywords: ["avahi", "uuctl", "bssh", "bvnc"]

    implicitWidth: 800
    implicitHeight: 739
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

    function scoreMatch(text, query) {
        if (!text)
            return -1;
        var textLower = text.toString().toLowerCase();
        var queryLower = query.toLowerCase();

        // Exact match
        if (textLower === queryLower)
            return 1000;

        // Full string starts with query
        if (textLower.startsWith(queryLower))
            return 800;

        // Any word in the string starts with query
        var words = textLower.split(/[\s\-_]+/);
        for (var i = 0; i < words.length; i++) {
            if (words[i].startsWith(queryLower))
                return 600;
        }

        // single/double letter matches polluting short queries
        if (query.length >= 3 && textLower.indexOf(queryLower) !== -1)
            return 200;

        return -1;
    }

    function buildFilteredList() {
        var allApps = DesktopEntries.applications.values;
        var query = ctrl.searchText.trim();
        var queryLower = query.toLowerCase();

        if (query === "") {
            // No query: show all apps, but completely hide any app matching hiddenKeywords
            return allApps.filter(app => {
                if (!app.name)
                    return false;
                var n = app.name.toLowerCase();
                return !hiddenKeywords.some(keyword => n.includes(keyword));
            }).sort((a, b) => (a.name || "").localeCompare(b.name || ""));
        }

        // Check if the user's search explicitly contains any of the hidden keywords
        var isSearchingHidden = hiddenKeywords.some(keyword => queryLower.includes(keyword));
        var scored = [];

        for (var i = 0; i < allApps.length; i++) {
            var entry = allApps[i];

            // Hide apps matching hiddenKeywords unless explicitly searched for
            var nameLower = entry.name ? entry.name.toLowerCase() : "";
            var isHiddenApp = hiddenKeywords.some(keyword => nameLower.includes(keyword));

            if (isHiddenApp && !isSearchingHidden) {
                continue;
            }

            var best = scoreMatch(entry.name, query);

            // Check generic name (e.g., "Web Browser")
            if (entry.genericName) {
                var s = scoreMatch(entry.genericName, query);
                if (s >= 200)
                    best = Math.max(best, s - 50);
            }

            // Check comments
            if (entry.comment) {
                var s = scoreMatch(entry.comment, query);
                if (s >= 200)
                    best = Math.max(best, s - 100);
            }

            // Check keywords
            if (entry.keywords) {
                for (var j = 0; j < entry.keywords.length; j++) {
                    var s = scoreMatch(entry.keywords[j], query);
                    if (s >= 200)
                        best = Math.max(best, s - 20); // High weight for exact alias hits
                }
            }

            // Check the executable command
            if (entry.execString && entry.execString.toLowerCase().includes(queryLower)) {
                best = Math.max(best, 180);
            }

            if (best >= 0) {
                scored.push({
                    entry: entry,
                    score: best
                });
            }
        }

        scored.sort((a, b) => {
            if (b.score !== a.score)
                return b.score - a.score;
            return (a.entry.name || "").localeCompare(b.entry.name || "");
        });

        return scored.map(s => s.entry);
    }

    LauncherBackend {
        id: ctrl

        onOpenMenuRequested: {
            if (launcherWindow.visible) {
                closeMenu();
            } else {
                ctrl.searchText = ""; // Reset backend state
                launcherWindow.visible = true; // Triggers UI build
            }
        }

        onCloseMenuRequested: closeMenu()
    }

    function closeMenu() {
        launcherWindow.visible = false; // Destroys the UI and frees memory
    }

    LazyLoader {
        id: contentLoader

        activeAsync: launcherWindow.visible

        component: Component {
            Item {
                id: lazyContentRoot

                parent: launcherWindow.contentItem
                anchors.fill: parent

                anchors.margins: 80
                anchors.bottomMargin: 50

                HyprlandFocusGrab {
                    id: focusGrab
                    windows: [launcherWindow]
                    onCleared: launcherWindow.closeMenu()
                }

                Component.onCompleted: {
                    focusGrab.active = true;
                    searchField.forceActiveFocus();
                }

                Rectangle {
                    id: shadowCaster
                    anchors.fill: mainUi
                    anchors.margins: 2
                    radius: 26
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
                    layer.smooth: true
                }

                Rectangle {
                    id: mainUi
                    anchors.fill: parent
                    color: Theme.surface_container
                    radius: 28
                    focus: true

                    layer.enabled: true
                    layer.smooth: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: mainUiMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0
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
                            launcherWindow.closeMenu();
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
                        anchors.topMargin: 16
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
    }
}
