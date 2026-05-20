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

    implicitHeight: 280
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
        wallpaperWindow.visible = true;

        wallpaperBackend.isListReady = false;
        wallpaperBackend.layoutPending = true;

        waylandStabilizationTimer.restart();
        wallpaperBackend.syncThumbnails();
    }

    function closeMenu() {
        wallpaperWindow.visible = false;
        focusGrab.active = false;
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

    HyprlandFocusGrab {
        id: focusGrab
        windows: [wallpaperWindow]

        onCleared: wallpaperWindow.closeMenu()
    }

    Item {
        anchors.fill: parent

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

            FolderListModel {
                id: wallModel

                folder: "file://" + wallpaperBackend.wallDir
                nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
                showDirs: false

                onStatusChanged: {
                    if (status === FolderListModel.Ready && wallpaperWindow.visible && wallpaperBackend.layoutPending) {
                        waylandStabilizationTimer.restart();
                    }
                }
            }

            ListView {
                id: listView

                anchors.fill: parent
                anchors.margins: 20

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
                    // This is now safely pointing to the distinct ID
                    backend: wallpaperBackend
                    onWallpaperSelected: wallpaperWindow.closeMenu()
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom

                width: 80

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

                text: "No wallpapers found in\n" + wallpaperBackend.wallDir

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
