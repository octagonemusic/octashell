import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Qt.labs.folderlistmodel
import "../../theme"

PanelWindow {
    id: wallpaperWindow

    anchors {
        bottom: true
        left: true
        right: true
    }

    margins {
        bottom: 24
        left: 24
        right: 24
    }

    implicitHeight: 352
    color: "transparent"
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "wallpaper_overlay"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusiveZone: -1

    WallpaperBackend {
        id: wallpaperBackend
    }

    onVisibleChanged: {
        if (!visible) {
            wallpaperBackend.isListReady = false;
            wallpaperBackend.layoutPending = false;
        }
    }

    function openMenu() {
        wallpaperBackend.isListReady = false;
        wallpaperBackend.layoutPending = true;
        wallpaperBackend.syncThumbnails();

        wallpaperWindow.visible = true;
    }

    function closeMenu() {
        wallpaperWindow.visible = false;
    }

    IpcHandler {
        target: "wallpaperSelector"

        function toggle() {
            if (!wallpaperWindow.visible) {
                wallpaperWindow.openMenu();
            } else {
                wallpaperWindow.closeMenu();
            }
        }
    }

    LazyLoader {
        id: contentLoader

        activeAsync: wallpaperWindow.visible

        component: Component {
            Item {
                id: lazyContentRoot

                parent: wallpaperWindow.contentItem
                anchors.fill: parent

                HyprlandFocusGrab {
                    id: focusGrab
                    windows: [wallpaperWindow]
                    onCleared: wallpaperWindow.closeMenu()
                }

                Timer {
                    id: waylandStabilizationTimer
                    interval: wallpaperBackend.waylandStabilizationDelay
                    repeat: false

                    onTriggered: {
                        if (!wallpaperBackend.layoutPending)
                            return;
                        if (wallModel.status !== FolderListModel.Ready)
                            return;

                        listView.forceLayout();
                        listView.highlightMoveDuration = 0;

                        let rawThemePath = Theme.wallpaper ? Theme.wallpaper.toString() : "";
                        let targetPath = wallpaperBackend.normalizePath(rawThemePath);
                        let found = false;

                        for (var i = 0; i < wallModel.count; i++) {
                            let modelPath = wallpaperBackend.normalizePath(wallModel.get(i, "fileUrl"));

                            if (modelPath === targetPath) {
                                listView.currentIndex = i;
                                listView.positionViewAtIndex(i, ListView.Center);
                                found = true;
                                break;
                            }
                        }

                        if (!found) {
                            listView.currentIndex = 0;
                            listView.positionViewAtIndex(0, ListView.Beginning);
                        }

                        listView.forceLayout();
                        listView.highlightMoveDuration = 150;

                        Qt.callLater(() => {
                            wallpaperBackend.isListReady = true;
                            focusGrab.active = true;
                            listView.forceActiveFocus();
                        });

                        wallpaperBackend.layoutPending = false;
                    }
                }

                Component.onCompleted: {
                    if (wallpaperBackend.layoutPending) {
                        waylandStabilizationTimer.restart();
                    }
                }

                Rectangle {
                    id: shadowCaster
                    anchors.fill: mainUi
                    anchors.margins: 4
                    radius: 32
                    color: "black"
                    visible: false
                }

                MultiEffect {
                    anchors.fill: shadowCaster
                    source: shadowCaster

                    shadowEnabled: true
                    shadowBlur: 2.0
                    shadowColor: "#80000000"
                    shadowVerticalOffset: 12
                }

                Rectangle {
                    id: mainUiMask
                    anchors.fill: mainUi
                    radius: 32
                    color: "black"

                    visible: false
                    layer.enabled: true
                }

                Rectangle {
                    id: mainUi

                    anchors.fill: parent

                    color: Theme.surface_container
                    radius: 32

                    layer.enabled: true
                    layer.smooth: true

                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: mainUiMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0
                    }

                    property string searchQuery: searchInput.text.trim()

                    Rectangle {
                        id: searchBarContainer
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 20
                        height: 56
                        radius: 28

                        color: searchInput.activeFocus ? Theme.surface_container_highest : Theme.surface_container_high
                        border.width: searchInput.activeFocus ? 2 : 0
                        border.color: searchInput.activeFocus ? Theme.primary : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.IBeamCursor
                            onClicked: {
                                searchInput.forceActiveFocus();
                                searchInput.cursorPosition = searchInput.text.length;
                            }
                        }

                        Text {
                            id: searchIcon
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 20
                            text: "search"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 25
                            color: searchInput.activeFocus ? Theme.primary : Theme.on_surface_variant
                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }
                        }

                        TextInput {
                            id: searchInput
                            anchors.left: searchIcon.right
                            anchors.right: clearIcon.visible ? clearIcon.left : parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12

                            color: Theme.on_surface
                            font.family: "Google Sans"
                            font.pixelSize: 18
                            verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true
                            clip: true

                            Text {
                                anchors.fill: parent
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Search wallpapers..."
                                color: Theme.on_surface_variant
                                opacity: 0.6
                                visible: !searchInput.text && !searchInput.activeFocus
                                font: searchInput.font
                                verticalAlignment: Text.AlignVCenter
                            }

                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Escape) {
                                    searchInput.focus = false;
                                    listView.forceActiveFocus();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return || event.key === Qt.Key_Down) {
                                    listView.forceActiveFocus();
                                    if (listView.count > 0 && listView.currentIndex === -1) {
                                        listView.currentIndex = 0;
                                    }
                                    event.accepted = true;
                                }
                            }
                        }

                        Text {
                            id: clearIcon
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.rightMargin: 20
                            text: "close"
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 20
                            color: clearMouseArea.containsMouse ? Theme.on_surface : Theme.on_surface_variant
                            visible: searchInput.text.length > 0

                            MouseArea {
                                id: clearMouseArea
                                anchors.fill: parent
                                anchors.margins: -10
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    searchInput.text = "";
                                    searchInput.forceActiveFocus();
                                }
                            }
                        }
                    }

                    FolderListModel {
                        id: wallModel

                        folder: "file://" + wallpaperBackend.wallDir
                        showDirs: false
                        caseSensitive: false

                        nameFilters: {
                            let q = mainUi.searchQuery;
                            if (q === "") {
                                return ["*.png", "*.jpg", "*.jpeg", "*.webp"];
                            } else {
                                return ["*" + q + "*.png", "*" + q + "*.jpg", "*" + q + "*.jpeg", "*" + q + "*.webp"];
                            }
                        }

                        onStatusChanged: {
                            if (status === FolderListModel.Ready && wallpaperWindow.visible && wallpaperBackend.layoutPending) {
                                waylandStabilizationTimer.restart();
                            }
                        }
                    }

                    Item {
                        id: listContainer
                        anchors.top: searchBarContainer.bottom
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right

                        ListView {
                            id: listView

                            anchors.fill: parent
                            anchors.topMargin: 16
                            anchors.bottomMargin: 20
                            anchors.leftMargin: 20
                            anchors.rightMargin: 20

                            orientation: ListView.Horizontal
                            spacing: 20
                            model: wallModel

                            snapMode: ListView.SnapToItem
                            highlightFollowsCurrentItem: true

                            cacheBuffer: wallpaperBackend.listCacheBuffer
                            reuseItems: true
                            displayMarginBeginning: wallpaperBackend.listRenderBuffer
                            displayMarginEnd: wallpaperBackend.listRenderBuffer

                            visible: wallpaperBackend.isListReady
                            opacity: wallpaperBackend.isListReady ? 1.0 : 0.0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 120
                                    easing.type: Easing.OutQuad
                                }
                            }

                            Keys.onPressed: event => {
                                if (event.modifiers !== Qt.NoModifier)
                                    return;
                                if (event.key === Qt.Key_Escape) {
                                    wallpaperWindow.closeMenu();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Slash) {
                                    searchInput.forceActiveFocus();
                                    searchInput.cursorPosition = searchInput.text.length;
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                                    listView.incrementCurrentIndex();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                                    listView.decrementCurrentIndex();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                                    if (listView.currentItem) {
                                        listView.currentItem.triggerSetWallpaper();
                                    }
                                    event.accepted = true;
                                }
                            }

                            delegate: WallpaperDelegate {
                                backend: wallpaperBackend
                                onWallpaperSelected: wallpaperWindow.closeMenu()
                            }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 80

                            opacity: listView.atXBeginning ? 0.0 : 1.0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 150
                                }
                            }

                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop {
                                    position: 0.0
                                    color: Theme.surface_container
                                }
                                GradientStop {
                                    position: 1.0
                                    color: "transparent"
                                }
                            }
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 80

                            opacity: listView.atXEnd || listView.count === 0 ? 0.0 : 1.0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 150
                                }
                            }

                            gradient: Gradient {
                                orientation: Gradient.Horizontal
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

                        Text {
                            anchors.centerIn: parent

                            text: mainUi.searchQuery === "" ? "No wallpapers found in\n" + wallpaperBackend.wallDir : "No results for '" + mainUi.searchQuery + "'"

                            horizontalAlignment: Text.AlignHCenter

                            visible: wallModel.count === 0 && wallModel.status === FolderListModel.Ready && wallpaperWindow.visible
                            opacity: wallpaperBackend.isListReady ? 1.0 : 0.0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutSine
                                }
                            }

                            color: Theme.on_surface_variant
                            font {
                                family: "Google Sans Medium"
                                pixelSize: 18
                            }
                        }
                    }
                }
            }
        }
    }
}
