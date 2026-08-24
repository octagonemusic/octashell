import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.theme

// Floating system tray icons (no pill background).
Item {
    id: root
    required property var windowHandle

    // Apps hidden from the tray entirely.
    readonly property var hiddenApps: ["nm-applet", "blueman"]

    // Apps whose default icon is replaced with a themed one. Matched as a
    // substring of id/title (e.g. "spotify" matches "spotify-client").
    readonly property var customIconApps: ["spotify", "steam"]

    function matchedCustomIcon(rawId, rawTitle) {
        const haystack = ((rawId || "") + " " + (rawTitle || "")).toLowerCase();
        return customIconApps.find(app => haystack.includes(app)) || "";
    }

    function iconSource(item) {
        const customName = matchedCustomIcon(item.id, item.title);
        if (customName)
            return Quickshell.iconPath(customName, true);
        if (item.icon)
            return item.icon;
        return Quickshell.iconPath("application-x-executable", true);
    }

    visible: contentLayout.implicitWidth > 0
    width: visible ? contentLayout.implicitWidth : 0
    height: contentLayout.implicitHeight

    Row {
        id: contentLayout
        anchors.verticalCenter: parent.verticalCenter
        spacing: 16

        Repeater {
            model: SystemTray.items

            delegate: MouseArea {
                visible: !root.hiddenApps.includes(modelData.id)

                width: 20
                height: 20

                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor

                onClicked: mouse => {
                    const mapped = mapToItem(windowHandle.contentItem, mouse.x, mouse.y);

                    switch (mouse.button) {
                    case Qt.LeftButton:
                        if (modelData.onlyMenu)
                            modelData.display(windowHandle, mapped.x, mapped.y);
                        else
                            modelData.activate();
                        break;
                    case Qt.RightButton:
                        if (modelData.hasMenu)
                            modelData.display(windowHandle, mapped.x, mapped.y);
                        break;
                    case Qt.MiddleButton:
                        modelData.secondaryActivate();
                        break;
                    }
                }

                onWheel: wheel => modelData.scroll(wheel.angleDelta.y, false)

                IconImage {
                    id: trayIcon
                    anchors.fill: parent
                    source: root.iconSource(modelData)

                    onStatusChanged: {
                        if (status === Image.Error)
                            source = Quickshell.iconPath("application-x-executable", true);
                    }
                }

                // Attention badge, per the SNI status contract.
                Rectangle {
                    anchors.top: trayIcon.top
                    anchors.right: trayIcon.right
                    anchors.topMargin: -3
                    anchors.rightMargin: -3

                    width: 7
                    height: 7
                    radius: 3.5

                    color: Theme.primary
                    visible: modelData.status === Status.NeedsAttention
                }
            }
        }
    }
}
