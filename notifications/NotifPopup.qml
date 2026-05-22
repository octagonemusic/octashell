import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../theme"

Variants {
    id: root
    model: Quickshell.screens

    property int hoveredNotificationId: -1

    delegate: PanelWindow {
        id: notificationPopup

        required property var modelData
        screen: modelData

        ListModel {
            id: activeNotifications
        }

        function disposeNotification(notificationId) {
            for (let i = 0; i < activeNotifications.count; i++) {
                if (activeNotifications.get(i).notificationEntry.id === notificationId) {
                    activeNotifications.remove(i, 1);
                    break;
                }
            }
        }

        visible: true
        property bool hasNotifications: activeNotifications.count > 0

        Timer {
            id: exitTimer
            interval: 350
            running: !hasNotifications
        }

        readonly property bool surfaceMapped: hasNotifications || exitTimer.running

        property real stableHeight: 0

        Binding on stableHeight {
            when: hasNotifications
            value: notificationStack.contentHeight + 40
        }

        implicitWidth: surfaceMapped ? 390 : 0
        implicitHeight: surfaceMapped ? stableHeight : 0

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

        ListView {
            id: notificationStack

            visible: {
                const isFocused = Hyprland.focusedMonitor && modelData.name === Hyprland.focusedMonitor.name;
                return isFocused && activeNotifications.count > 0;
            }

            width: 350
            height: contentHeight
            interactive: false
            spacing: 14

            anchors {
                top: parent.top
                right: parent.right
                topMargin: 20
                rightMargin: 20
            }

            model: activeNotifications
            delegate: notificationDelegate

            add: Transition {
                ParallelAnimation {
                    NumberAnimation {
                        property: "x"
                        from: 390
                        to: 0
                        duration: 350
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.05
                    }
                    NumberAnimation {
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: 250
                    }
                }
            }

            remove: Transition {
                ParallelAnimation {
                    NumberAnimation {
                        property: "x"
                        to: 390
                        duration: 350
                        easing.type: Easing.InBack
                        easing.overshoot: 1.1
                    }
                    NumberAnimation {
                        property: "opacity"
                        to: 0
                        duration: 250
                    }
                }
            }

            displaced: Transition {
                ParallelAnimation {
                    NumberAnimation {
                        properties: "y"
                        duration: 350
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.05
                    }
                    NumberAnimation {
                        properties: "x"
                        to: 0
                        duration: 350
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.05
                    }
                    NumberAnimation {
                        property: "opacity"
                        to: 1
                        duration: 250
                    }
                }
            }
        }

        Component {
            id: notificationDelegate

            Item {
                id: delegateContainer

                width: 350
                height: notificationCard.height + 20

                required property var notificationEntry

                readonly property string applicationName: notificationEntry.appName || "Notification"
                readonly property var applicationIcon: notificationEntry.image || notificationEntry.appIcon || ""

                property real lifeSpanProgress: 1.0

                onNotificationEntryChanged: {
                    lifeSpanProgress = 1.0;
                    expiryTimer.restart();
                }

                Connections {
                    target: notificationEntry
                    function onClosed(reason) {
                        expiryTimer.stop();
                        notificationPopup.disposeNotification(notificationEntry.id);
                    }
                }

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
                            if (notificationPopup.visible && notificationEntry && typeof notificationEntry.expire === "function") {
                                notificationEntry.expire();
                            }
                        }
                    }
                }

                Rectangle {
                    id: notificationCard

                    width: parent.width
                    height: layoutContent.implicitHeight + 36
                    y: 4

                    // M3 Expressive Shape
                    radius: 28

                    border.width: 1
                    border.color: Qt.rgba(Theme.outline_variant.r, Theme.outline_variant.g, Theme.outline_variant.b, 0.55)

                    color: Theme.surface_container

                    scale: interactionArea.pressed ? 0.975 : 1.0
                    layer.enabled: true

                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: "#1A000000"
                        blurMax: 48
                        shadowBlur: interactionArea.containsMouse ? 1.0 : 0.6
                        shadowVerticalOffset: interactionArea.containsMouse ? 8 : 4

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

                    Behavior on scale {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutBack
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius

                        color: {
                            if (interactionArea.pressed)
                                return Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.10);
                            if (interactionArea.containsMouse)
                                return Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.08);
                            return "transparent";
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
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

                        width: parent.width - 40
                        anchors.centerIn: parent

                        spacing: 4

                        Item {
                            width: parent.width
                            height: 32

                            Item {
                                id: headerIconWrapper

                                width: 24
                                height: 24

                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left

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
                                            pixelSize: 13
                                            bold: true
                                        }
                                    }
                                }

                                Rectangle {
                                    id: headerMask
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: "black"
                                    visible: false
                                    layer.enabled: true
                                    layer.smooth: true
                                }

                                Image {
                                    anchors.fill: parent
                                    source: delegateContainer.applicationIcon
                                    fillMode: Image.PreserveAspectCrop
                                    visible: !!delegateContainer.applicationIcon
                                    layer.enabled: true
                                    layer.smooth: true

                                    layer.effect: MultiEffect {
                                        maskEnabled: true
                                        maskSource: headerMask
                                        maskThresholdMin: 0.5
                                        maskSpreadAtMin: 1.0
                                    }
                                }
                            }

                            Text {
                                text: delegateContainer.applicationName
                                color: Theme.primary

                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: headerIconWrapper.right
                                anchors.leftMargin: 12

                                font {
                                    family: "Google Sans Medium"
                                    pixelSize: 14
                                }
                            }

                            // =========================================
                            // Close Action
                            // =========================================
                            Rectangle {
                                id: closeAction

                                width: 32
                                height: 32
                                radius: 16
                                color: "transparent"

                                anchors {
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
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
                                        strokeColor: Qt.rgba(Theme.critical.r, Theme.critical.g, Theme.critical.b, 0.2)
                                        strokeWidth: 4
                                        capStyle: ShapePath.RoundCap

                                        PathAngleArc {
                                            centerX: closeAction.width / 2
                                            centerY: closeAction.height / 2
                                            radiusX: (closeAction.width / 2) - 2.5
                                            radiusY: (closeAction.height / 2) - 2.5
                                            startAngle: 0
                                            sweepAngle: 360
                                        }
                                    }

                                    ShapePath {
                                        fillColor: "transparent"
                                        strokeColor: Theme.critical
                                        strokeWidth: 4
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

                                    onEntered: closeAction.color = Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.08)
                                    onExited: closeAction.color = "transparent"
                                    onClicked: event => {
                                        event.accepted = true;
                                        notificationEntry.dismiss();
                                    }
                                }
                            }
                        }

                        Column {
                            width: parent.width
                            spacing: 4

                            Text {
                                text: notificationEntry.summary
                                color: Theme.on_surface

                                font {
                                    family: "Google Sans Medium"
                                    pixelSize: 16
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
                                    pixelSize: 14
                                }

                                width: parent.width
                                wrapMode: Text.WordWrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }
}
