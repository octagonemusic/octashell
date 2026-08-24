import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.theme
import qs.bar.widgets

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

            delegate: Item {
                id: trayItem
                visible: !root.hiddenApps.includes(modelData.id)

                readonly property real hitSize: 26

                width: 20
                height: 20

                transform: Scale {
                    origin.x: trayItem.width / 2
                    origin.y: trayItem.height / 2
                    xScale: trayMouse.pressed ? 1.12 : (trayMouse.containsMouse ? 1.08 : 1.0)
                    yScale: trayMouse.pressed ? 0.86 : (trayMouse.containsMouse ? 1.08 : 1.0)

                    Behavior on xScale {
                        NumberAnimation {
                            duration: trayMouse.pressed ? 100 : 150
                            easing.type: trayMouse.pressed ? Easing.OutQuad : Easing.OutBack
                            easing.overshoot: 1.1
                        }
                    }
                    Behavior on yScale {
                        NumberAnimation {
                            duration: trayMouse.pressed ? 100 : 150
                            easing.type: trayMouse.pressed ? Easing.OutQuad : Easing.OutBack
                            easing.overshoot: 1.1
                        }
                    }
                }

                // State layer: no static pill, just a soft circle that fades in on
                // hover/press so the tray stays visually quiet at rest.
                Rectangle {
                    id: stateLayer
                    anchors.centerIn: parent
                    width: trayItem.hitSize
                    height: trayItem.hitSize
                    radius: width / 2
                    color: Theme.on_surface_variant
                    opacity: trayMouse.pressed ? 0.10 : (trayMouse.containsMouse ? 0.08 : 0.0)

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutQuad
                        }
                    }

                    Ripple {
                        id: trayRipple
                        cornerRadius: stateLayer.radius
                        rippleColor: Theme.on_surface_variant
                    }
                }

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

                MouseArea {
                    id: trayMouse
                    anchors.centerIn: parent
                    width: trayItem.hitSize
                    height: trayItem.hitSize

                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onPressed: mouse => trayRipple.trigger(mouse.x, mouse.y)

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
                }
            }
        }
    }
}
