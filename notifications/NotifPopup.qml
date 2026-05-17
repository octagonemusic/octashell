import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../theme"

/**
 * Renders a stack of transient desktop notifications on the focused monitor.
 */
Variants {
    id: root
    model: Quickshell.screens

    // track hovered state of notification
    property int hoveredNotificationId: -1

    delegate: PanelWindow {
        id: notificationPopup

        // --- Screen & Model Configuration ---
        required property var modelData
        screen: modelData

        ListModel {
            id: activeNotifications
        }

        /**
         * Removes a notification from the local model by ID.
         */
        function disposeNotification(notificationId) {
            for (let i = 0; i < activeNotifications.count; i++) {
                if (activeNotifications.get(i).notificationEntry.id === notificationId) {
                    activeNotifications.remove(i, 1);
                    break;
                }
            }
        }

        // --- Window State ---
        visible: {
            const isFocused = Hyprland.focusedMonitor && modelData.name === Hyprland.focusedMonitor.name;
            return isFocused && activeNotifications.count > 0;
        }

        // --- LayerShell Properties ---
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "notification_overlay"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        color: "transparent"

        anchors {
            top: true
            right: true
        }
        margins {
            top: 40
            right: 5
        }

        implicitWidth: 390
        implicitHeight: notificationStack.implicitHeight + 40

        // --- Notification Service Integration ---
        Connections {
            target: CentralNotifServer

            function onNotification(notification) {
                let existingIndex = -1;
                for (let i = 0; i < activeNotifications.count; i++) {
                    if (activeNotifications.get(i).notificationEntry.id === notification.id) {
                        existingIndex = i;
                        break;
                    }
                }

                if (existingIndex !== -1) {
                    activeNotifications.setProperty(existingIndex, "notificationEntry", notification);
                } else {
                    activeNotifications.insert(0, {
                        "notificationEntry": notification
                    });
                }
            }
        }

        // --- Notification Stack Layout ---
        Column {
            id: notificationStack
            width: 350
            spacing: 12
            anchors {
                top: parent.top
                right: parent.right
                topMargin: 20
                rightMargin: 20
            }

            Repeater {
                model: activeNotifications
                delegate: notificationDelegate
            }
        }

        // --- Notification Item Delegate ---
        Component {
            id: notificationDelegate

            Item {
                id: delegateContainer
                width: 350
                height: notificationCard.height + 20
                anchors.horizontalCenter: parent.horizontalCenter

                required property var notificationEntry

                readonly property string applicationName: notificationEntry.appName || "Notification"

                readonly property var applicationIcon: notificationEntry.image || notificationEntry.appIcon || ""

                property real lifeSpanProgress: 1.0

                Connections {
                    target: notificationEntry
                    function onClosed(reason) {
                        notificationPopup.disposeNotification(notificationEntry.id);
                    }
                }

                /** Automatic expiration timer */
                NumberAnimation {
                    id: expiryTimer
                    target: delegateContainer
                    property: "lifeSpanProgress"
                    from: 1.0
                    to: 0.0
                    duration: 7000
                    running: true

                    paused: root.hoveredNotificationId === notificationEntry.id

                    onFinished: {
                        if (lifeSpanProgress <= 0.01) {
                            if (notificationPopup.visible) {
                                notificationEntry.expire();
                            }
                        }
                    }
                }

                // --- Notification Card ---
                Rectangle {
                    id: notificationCard
                    width: parent.width
                    height: layoutContent.implicitHeight + 32
                    y: 4
                    radius: 12
                    border.width: 1
                    border.color: Theme.outline_variant

                    color: interactionArea.containsMouse ? Qt.lighter(Theme.surface_container, 1.04) : Theme.surface_container
                    scale: interactionArea.pressed ? 0.96 : 1.0

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: "#40000000"

                        blurMax: 32
                        shadowBlur: interactionArea.containsMouse ? 0.5 : 0.2
                        shadowVerticalOffset: interactionArea.containsMouse ? 6 : 2

                        Behavior on shadowBlur {
                            NumberAnimation {
                                duration: 250
                                easing.type: Easing.OutBack
                            }
                        }
                        Behavior on shadowVerticalOffset {
                            NumberAnimation {
                                duration: 250
                                easing.type: Easing.OutBack
                            }
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutBack
                        }
                    }

                    MouseArea {
                        id: interactionArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onEntered: root.hoveredNotificationId = notificationEntry.id
                        onExited: {
                            if (root.hoveredNotificationId === notificationEntry.id) {
                                root.hoveredNotificationId = -1;
                            }
                        }

                        onClicked: {
                            let invoked = false;

                            if (notificationEntry.actions) {
                                for (let i = 0; i < notificationEntry.actions.length; i++) {
                                    if (notificationEntry.actions[i].identifier === "default") {
                                        notificationEntry.actions[i].invoke();
                                        invoked = true;
                                        break;
                                    }
                                }
                            }

                            if (!invoked) {
                                notificationEntry.dismiss();
                            }
                        }
                    }

                    Column {
                        id: layoutContent
                        width: parent.width - 32
                        anchors.centerIn: parent
                        spacing: 12

                        Item {
                            width: parent.width
                            height: Math.max(iconWrapper.height, textStack.implicitHeight)

                            Item {
                                id: iconWrapper
                                width: 48
                                height: 48
                                anchors {
                                    left: parent.left
                                    top: parent.top
                                }

                                // Fallback icon / initial state
                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: Theme.primary_container
                                    visible: !delegateContainer.applicationIcon

                                    Text {
                                        anchors.centerIn: parent
                                        text: "!"
                                        color: Theme.on_primary_container
                                        font {
                                            family: "Google Sans Medium"
                                            pixelSize: 24
                                            bold: true
                                        }
                                    }
                                }

                                Rectangle {
                                    id: circleMask
                                    width: iconWrapper.width
                                    height: iconWrapper.height
                                    radius: width / 2
                                    color: "black"   // MUST be a solid color to work as a mask
                                    visible: false   // Hide from the visible UI layout
                                    layer.enabled: true // CRITICAL: Forces Qt to render the hidden mask in the background
                                }

                                Image {
                                    id: iconSrc
                                    anchors.fill: parent
                                    source: delegateContainer.applicationIcon
                                    fillMode: Image.PreserveAspectCrop
                                    visible: !!delegateContainer.applicationIcon

                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        maskEnabled: true
                                        maskSource: circleMask
                                    }
                                }
                            }

                            Column {
                                id: textStack
                                spacing: 4
                                anchors {
                                    left: iconWrapper.right
                                    right: closeAction.left
                                    top: parent.top
                                    leftMargin: 12
                                    rightMargin: 8
                                }

                                Text {
                                    text: delegateContainer.applicationName
                                    color: Theme.on_surface_variant
                                    font {
                                        family: "Google Sans Medium"
                                        pixelSize: 13
                                    }
                                    width: parent.width
                                }
                                Text {
                                    text: notificationEntry.summary
                                    color: Theme.on_surface
                                    font {
                                        family: "Google Sans Medium"
                                        pixelSize: 17
                                        bold: true
                                    }
                                    width: parent.width
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: notificationEntry.body
                                    color: Theme.on_surface_variant
                                    font {
                                        family: "Google Sans"
                                        pixelSize: 15
                                    }
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                }
                            }

                            Rectangle {
                                id: closeAction
                                width: 28
                                height: 28
                                radius: 14
                                color: "transparent"
                                anchors {
                                    top: parent.top
                                    right: parent.right
                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 150
                                    }
                                }

                                Shape {
                                    id: countdownRing
                                    anchors.fill: parent
                                    antialiasing: true
                                    preferredRendererType: Shape.CurveRenderer

                                    ShapePath {
                                        fillColor: "transparent"
                                        strokeColor: Theme.critical
                                        strokeWidth: 3
                                        capStyle: ShapePath.RoundCap

                                        PathAngleArc {
                                            centerX: closeAction.width / 2
                                            centerY: closeAction.height / 2
                                            radiusX: (closeAction.width / 2) - 2.5
                                            radiusY: (closeAction.height / 2) - 2.5
                                            startAngle: -90
                                            sweepAngle: delegateContainer.lifeSpanProgress * 360
                                        }
                                    }
                                }

                                Item {
                                    anchors.centerIn: parent
                                    width: 12
                                    height: 12
                                    rotation: 45

                                    Rectangle {
                                        width: 2
                                        height: parent.height
                                        anchors.centerIn: parent
                                        radius: 1
                                        color: closeMouseArea.containsMouse ? Theme.on_surface : Theme.on_surface_variant
                                        antialiasing: true
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 150
                                            }
                                        }
                                    }
                                    Rectangle {
                                        width: parent.width
                                        height: 2
                                        anchors.centerIn: parent
                                        radius: 1
                                        color: closeMouseArea.containsMouse ? Theme.on_surface : Theme.on_surface_variant
                                        antialiasing: true
                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 150
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: closeMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: closeAction.color = Qt.rgba(Theme.surface_variant.r, Theme.surface_variant.g, Theme.surface_variant.b, 0.4)
                                    onExited: closeAction.color = "transparent"
                                    onClicked: event => {
                                        event.accepted = true;
                                        notificationEntry.dismiss();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
