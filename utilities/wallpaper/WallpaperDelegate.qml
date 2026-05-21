import QtQuick
import QtQuick.Effects
import "../../theme"

Item {
    id: delegateRoot

    required property url fileUrl
    required property var fileSize
    required property WallpaperBackend backend

    height: ListView.view ? ListView.view.height : 0
    width: backend ? height * backend.thumbAspectRatio : 0

    property bool isSelected: ListView.isCurrentItem
    property bool isActive: isSelected || wallMouseArea.containsMouse

    property string fileName: {
        if (!backend || !fileUrl)
            return "";
        let decoded = backend.safeDecodeURI(fileUrl.toString());
        return decoded.substring(decoded.lastIndexOf("/") + 1);
    }

    property string thumbUrl: backend && fileName !== "" ? "file://" + backend.thumbDir + "/" + encodeURIComponent(fileName) + ".jpg" : ""

    property string cacheBustString: ""
    property int retryCount: 0
    property bool hasFailed: false
    property bool thumbLoadedOnce: false

    signal wallpaperSelected

    onFileUrlChanged: {
        retryTimer.stop();
        cacheBustString = "";
        retryCount = 0;
        hasFailed = false;
        thumbLoadedOnce = false;
    }

    function triggerSetWallpaper() {
        if (backend) {
            backend.setWallpaper(delegateRoot.fileUrl);
            delegateRoot.wallpaperSelected();
        }
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

            layer.enabled: true
            layer.smooth: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: imgMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }

            Rectangle {
                anchors.fill: parent
                color: Theme.surface_variant

                visible: wallImg.status !== Image.Ready

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
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 60

                visible: wallImg.status === Image.Ready

                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: "transparent"
                    }
                    GradientStop {
                        position: 1.0
                        color: "#CC000000"
                    }
                }

                Column {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 12
                    spacing: 2

                    Text {
                        text: delegateRoot.fileName
                        color: "white"
                        font.family: "Google Sans Medium"
                        font.pixelSize: 13
                        elide: Text.ElideRight
                        width: parent.width
                    }

                    Text {
                        text: {
                            let bytes = delegateRoot.fileSize;
                            if (!bytes)
                                return "";
                            let kb = bytes / 1024;
                            if (kb < 1024)
                                return Math.round(kb) + " KB";
                            return (kb / 1024).toFixed(1) + " MB";
                        }
                        color: "#DDDDDD"
                        font.family: "Google Sans"
                        font.pixelSize: 11
                    }
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

            onClicked: delegateRoot.triggerSetWallpaper()
        }
    }
}
