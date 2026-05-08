import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import Qt5Compat.GraphicalEffects
import "../theme"

/**
 * Renders a stack of transient desktop notifications on the focused monitor.
 */
Variants {
    id: root
    model: Quickshell.screens

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
        // Logic: Visible only if monitor is focused and there are active notifications.
        visible: {
            const isFocused = Hyprland.focusedMonitor && modelData.name === Hyprland.focusedMonitor.name;
            return isFocused && activeNotifications.count > 0;
        }

        // --- LayerShell Properties ---
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "notification_overlay"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

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
                readonly property string applicationIcon: notificationEntry.image || notificationEntry.appIcon
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
                    duration: 5000
                    running: true
                    onFinished: if (lifeSpanProgress <= 0.01)
                        notificationEntry.expire()
                }

                // --- Visual Effects (Shadow) ---
                Rectangle {
                    id: shadowSource
                    anchors.fill: notificationCard
                    anchors.margins: -1
                    radius: notificationCard.radius
                    color: notificationCard.color
                    visible: false
                }

                DropShadow {
                    anchors.fill: shadowSource
                    source: shadowSource
                    radius: interactionArea.containsMouse ? 20 : 12
                    samples: 32
                    color: "#66000000"
                    verticalOffset: interactionArea.containsMouse ? 6 : 3

                    Behavior on radius {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on verticalOffset {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutCubic
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

                    color: interactionArea.containsMouse ? Qt.lighter(Theme.surface_container, 1.06) : Theme.surface_container

                    scale: interactionArea.pressed ? 0.98 : 1.0

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: 100
                            easing.type: Easing.OutCubic
                        }
                    }

                    MouseArea {
                        id: interactionArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            let invoked = false;

                            // Check if the application provided any actions
                            if (notificationEntry.actions) {
                                for (let i = 0; i < notificationEntry.actions.length; i++) {
                                    if (notificationEntry.actions[i].identifier === "default") {
                                        notificationEntry.actions[i].invoke();
                                        invoked = true;
                                        break;
                                    }
                                }
                            }

                            // Fallback: If no default action exists, just dismiss
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

                        // Header (Icon & Text)
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

                                // Icon Fallback
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
                                    id: iconMask
                                    anchors.fill: parent
                                    radius: width / 2
                                    visible: false
                                }

                                Image {
                                    anchors.fill: parent
                                    source: delegateContainer.applicationIcon
                                    fillMode: Image.PreserveAspectCrop
                                    visible: !!delegateContainer.applicationIcon
                                    layer.enabled: true
                                    layer.effect: OpacityMask {
                                        maskSource: iconMask
                                    }
                                }
                            }

                            // Text Content
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

                            // Close Action & Timer Ring
                            Rectangle {
                                id: closeAction
                                width: 24
                                height: 24
                                radius: 12
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

                                Canvas {
                                    id: countdownRing
                                    anchors.fill: parent
                                    antialiasing: true
                                    property real visualProgress: delegateContainer.lifeSpanProgress
                                    onVisualProgressChanged: requestPaint()

                                    onPaint: {
                                        var ctx = getContext("2d");
                                        ctx.clearRect(0, 0, width, height);
                                        var centerX = width / 2, centerY = height / 2;
                                        var radius = (width / 2) - 2.0;
                                        var startAngle = -Math.PI / 2;
                                        var endAngle = startAngle + (visualProgress * 2 * Math.PI);

                                        ctx.beginPath();
                                        ctx.arc(centerX, centerY, radius, startAngle, endAngle);
                                        ctx.lineWidth = 3;
                                        ctx.strokeStyle = Theme.critical;
                                        ctx.lineCap = "round";
                                        ctx.stroke();
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: -1
                                    text: "×"
                                    color: closeMouseArea.containsMouse ? Theme.on_surface : Theme.on_surface_variant
                                    font {
                                        pixelSize: 18
                                        bold: true
                                    }
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 150
                                        }
                                    }
                                }

                                MouseArea {
                                    id: closeMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: closeAction.color = Qt.lighter(Theme.surface_variant, 1.05)
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
