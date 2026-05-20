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

    // Configuration Paths
    readonly property string configDir: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string wallDir: homeDir + "/Pictures/walls"
    readonly property string thumbDir: (Quickshell.env("XDG_CACHE_HOME") || (homeDir + "/.cache")) + "/quickshell/thumbs"
    readonly property string setThemeScript: homeDir + "/.local/bin/set-theme"
    readonly property string thumbScript: configDir + "/quickshell/scripts/generate-thumbs.sh"

    // UI Configuration
    readonly property real thumbAspectRatio: 1.6
    readonly property int listRenderBuffer: 200
    readonly property int listCacheBuffer: 800
    readonly property int waylandStabilizationDelay: 40

    // Internal State
    property bool _isListReady: false
    property bool _layoutPending: false

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

    onVisibleChanged: {
        if (!visible) {
            _isListReady = false;
            _layoutPending = false;
        }
    }

    function safeDecodeURI(uri) {
        try {
            return decodeURIComponent(uri);
        } catch (e) {
            return uri;
        }
    }

    function normalizePath(uri) {
        let decoded = safeDecodeURI(uri.toString());
        return decoded.replace(/^file:\/{2,3}/, "/").replace(/\/+/g, '/');
    }

    function openMenu() {
        wallpaperWindow.visible = true;

        _isListReady = false;
        _layoutPending = true;

        waylandStabilizationTimer.restart();
        syncThumbnails();
    }

    function closeMenu() {
        wallpaperWindow.visible = false;
        focusGrab.active = false;
    }

    function syncThumbnails() {
        Quickshell.execDetached({
            command: ["bash", wallpaperWindow.thumbScript, wallpaperWindow.wallDir, wallpaperWindow.thumbDir]
        });
    }

    Timer {
        id: waylandStabilizationTimer
        interval: wallpaperWindow.waylandStabilizationDelay
        repeat: false

        onTriggered: {
            if (!_layoutPending)
                return;
            if (wallModel.status !== FolderListModel.Ready)
                return;

            listView.forceLayout();
            listView.highlightMoveDuration = 0;

            let rawThemePath = Theme.wallpaper ? Theme.wallpaper.toString() : "";
            let targetPath = normalizePath(rawThemePath);
            let found = false;

            for (var i = 0; i < wallModel.count; i++) {
                let modelPath = normalizePath(wallModel.get(i, "fileUrl"));

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
                wallpaperWindow._isListReady = true;
                focusGrab.active = true; // Grab focus securely once layer is mapped
                listView.forceActiveFocus();
            });

            _layoutPending = false;
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

                folder: "file://" + wallpaperWindow.wallDir
                nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
                showDirs: false

                onStatusChanged: {
                    if (status === FolderListModel.Ready && wallpaperWindow.visible && _layoutPending) {
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

                cacheBuffer: wallpaperWindow.listCacheBuffer
                reuseItems: true
                displayMarginBeginning: wallpaperWindow.listRenderBuffer
                displayMarginEnd: wallpaperWindow.listRenderBuffer

                visible: wallpaperWindow._isListReady
                opacity: wallpaperWindow._isListReady ? 1.0 : 0.0

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
                            listView.currentItem.setWallpaper();
                        }

                        event.accepted = true;
                    }
                }

                delegate: Item {
                    id: delegateRoot

                    height: listView.height
                    width: height * wallpaperWindow.thumbAspectRatio

                    required property url fileUrl

                    property bool isSelected: ListView.isCurrentItem
                    property bool isActive: isSelected || wallMouseArea.containsMouse

                    property string fileName: {
                        let decoded = safeDecodeURI(fileUrl.toString());
                        return decoded.substring(decoded.lastIndexOf("/") + 1);
                    }

                    property string thumbUrl: "file://" + wallpaperWindow.thumbDir + "/" + encodeURIComponent(fileName) + ".jpg"
                    property string cacheBustString: ""
                    property int retryCount: 0
                    property bool hasFailed: false
                    property bool thumbLoadedOnce: false

                    onFileUrlChanged: {
                        retryTimer.stop();
                        cacheBustString = "";
                        retryCount = 0;
                        hasFailed = false;
                        thumbLoadedOnce = false;
                    }

                    function setWallpaper() {
                        let path = normalizePath(delegateRoot.fileUrl);

                        Quickshell.execDetached({
                            command: ["bash", wallpaperWindow.setThemeScript, path]
                        });

                        wallpaperWindow.closeMenu();
                    }

                    Item {
                        anchors.centerIn: parent
                        width: parent.width
                        height: parent.height

                        scale: delegateRoot.isActive ? 1.04 : 1.0
                        z: delegateRoot.isActive ? 10 : 1

                        Behavior on scale {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutBack
                            }
                        }

                        Rectangle {
                            id: imgMask

                            anchors.fill: parent
                            anchors.margins: delegateRoot.isActive ? 0 : 8

                            radius: 20
                            color: "black"

                            visible: false
                            layer.enabled: true

                            Behavior on anchors.margins {
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutBack
                                }
                            }
                        }

                        Item {
                            anchors.fill: imgMask

                            Rectangle {
                                anchors.fill: parent
                                radius: 20
                                color: Theme.surface_variant

                                visible: wallImg.status !== Image.Ready

                                clip: true

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter

                                        text: delegateRoot.hasFailed ? "Failed to generate thumbnail :(" : "Generating Thumbnail"

                                        color: delegateRoot.hasFailed ? Theme.error : Theme.on_surface_variant

                                        font.family: "Google Sans Medium"
                                        font.pixelSize: 14

                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    Text {
                                        visible: !delegateRoot.hasFailed

                                        anchors.horizontalCenter: parent.horizontalCenter

                                        text: "Please wait..."
                                        color: Theme.on_surface_variant

                                        opacity: 0.7

                                        font.family: "Google Sans"
                                        font.pixelSize: 12
                                    }
                                }
                            }

                            Image {
                                id: wallImg

                                anchors.fill: parent

                                source: delegateRoot.thumbUrl + delegateRoot.cacheBustString

                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false

                                sourceSize.width: 256
                                sourceSize.height: 256

                                onStatusChanged: {
                                    if (status === Image.Ready) {
                                        thumbLoadedOnce = true;
                                        hasFailed = false;
                                        retryTimer.stop();
                                        return;
                                    }

                                    if (status === Image.Loading) {
                                        hasFailed = false;
                                        return;
                                    }

                                    if (status === Image.Error && source.toString().includes(delegateRoot.fileName)) {
                                        if (delegateRoot.retryCount < 15) {
                                            delegateRoot.retryCount++;
                                            retryTimer.start();
                                        } else {
                                            delegateRoot.hasFailed = true;
                                        }
                                    }
                                }

                                layer.enabled: true
                                layer.smooth: true

                                layer.effect: MultiEffect {
                                    maskEnabled: true
                                    maskSource: imgMask
                                    maskThresholdMin: 0.5
                                    maskSpreadAtMin: 1.0
                                }
                            }

                            Timer {
                                id: retryTimer

                                interval: Math.min(1000 + (delegateRoot.retryCount * 250), 4000)
                                repeat: false

                                onTriggered: {
                                    delegateRoot.cacheBustString = "?t=" + Date.now();
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: imgMask
                            radius: 20

                            color: "transparent"
                            border.color: Theme.primary
                            border.width: delegateRoot.isActive ? 4 : 0
                        }

                        MouseArea {
                            id: wallMouseArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: delegateRoot.setWallpaper()
                        }
                    }
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

                text: "No wallpapers found in\n" + wallpaperWindow.wallDir

                horizontalAlignment: Text.AlignHCenter

                visible: wallModel.count === 0 && wallModel.status === FolderListModel.Ready && wallpaperWindow.visible

                opacity: wallpaperWindow._isListReady ? 1.0 : 0.0

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
