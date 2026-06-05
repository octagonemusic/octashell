import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.services
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
            id: notifModel
        }

        function addOrUpdateNotification(notification) {
            for (let i = 0; i < notifModel.count; i++) {
                if (notifModel.get(i).notifId === notification.id) {
                    notifModel.setProperty(i, "notificationEntry", notification);
                    return;
                }
            }
            notifModel.insert(0, {
                notifId: notification.id,
                notificationEntry: notification
            });
        }

        function disposeNotification(notificationId) {
            for (let i = 0; i < notifModel.count; i++) {
                if (notifModel.get(i).notifId === notificationId) {
                    notifModel.remove(i, 1);
                    return;
                }
            }
        }

        visible: true
        property bool hasNotifications: notifModel.count > 0

        Timer {
            id: exitTimer
            interval: 350
            running: !hasNotifications
        }

        readonly property bool surfaceMapped: hasNotifications || exitTimer.running

        implicitWidth: surfaceMapped ? 390 : 0
        implicitHeight: surfaceMapped ? modelData.height : 0

        mask: Region {
            item: clickHitbox
        }

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
            target: NotifServer
            function onNotification(notification) {
                notificationPopup.addOrUpdateNotification(notification);
            }
        }

        Item {
            id: clickHitbox
            width: notificationStack.width
            height: notificationStack.activeStackHeight
            anchors {
                top: notificationStack.top
                right: notificationStack.right
            }
        }

        Item {
            id: notificationStack

            visible: {
                const isFocused = Hyprland.focusedMonitor && modelData.name === Hyprland.focusedMonitor.name;
                return isFocused && surfaceMapped;
            }

            width: 350
            height: parent.height

            anchors {
                top: parent.top
                right: parent.right
                topMargin: 20
                rightMargin: 20
            }

            property var cardHeights: []

            property real activeStackHeight: 0
            onCardHeightsChanged: {
                activeStackHeight = yForIndex(notifModel.count);
            }

            function getCardHeight(id) {
                for (let i = 0; i < cardHeights.length; i++) {
                    if (cardHeights[i].notifId === id)
                        return cardHeights[i].h;
                }
                return 0;
            }

            function setCardHeight(id, h) {
                for (let i = 0; i < cardHeights.length; i++) {
                    if (cardHeights[i].notifId === id) {
                        if (cardHeights[i].h === h)
                            return;  // no-op
                        cardHeights[i].h = h;
                        cardHeightsChanged();
                        return;
                    }
                }
                cardHeights.push({
                    notifId: id,
                    h: h
                });
                cardHeightsChanged();
            }

            function removeCardHeight(id) {
                const idx = cardHeights.findIndex(e => e.notifId === id);
                if (idx !== -1) {
                    cardHeights.splice(idx, 1);
                    cardHeightsChanged();
                }
            }

            function yForIndex(idx) {
                const spacing = 14;
                let y = 0;
                for (let i = 0; i < idx; i++) {
                    const id = notifModel.get(i).notifId;
                    y += getCardHeight(id) + spacing;
                }
                return y;
            }

            Repeater {
                model: notifModel

                delegate: Item {
                    id: cardDelegate

                    required property int index
                    required property int notifId
                    required property var notificationEntry

                    width: 350
                    height: notificationCard.height + 20

                    x: 0
                    y: notificationStack.yForIndex(index)

                    Behavior on y {
                        NumberAnimation {
                            duration: 320
                            easing.type: Easing.OutCubic
                        }
                    }

                    property bool slidingOut: false

                    function slideOut() {
                        if (slidingOut)
                            return;
                        slidingOut = true;
                        expiryAnim.stop();
                        slideOutAnim.start();
                    }

                    Component.onCompleted: {
                        notificationStack.setCardHeight(notifId, notificationCard.height);
                        x = 390;
                        opacity = 0;
                        slideIn.start();
                    }

                    Component.onDestruction: {
                        notificationStack.removeCardHeight(notifId);

                        if (root.hoveredNotificationId === notifId) {
                            root.hoveredNotificationId = -1;
                        }
                    }

                    onHeightChanged: {
                        notificationStack.setCardHeight(notifId, notificationCard.height);
                    }

                    ParallelAnimation {
                        id: slideIn
                        NumberAnimation {
                            target: cardDelegate
                            property: "x"
                            to: 0
                            duration: 350
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.05
                        }
                        NumberAnimation {
                            target: cardDelegate
                            property: "opacity"
                            to: 1
                            duration: 250
                        }
                    }

                    ParallelAnimation {
                        id: slideOutAnim
                        NumberAnimation {
                            target: cardDelegate
                            property: "x"
                            to: 390
                            duration: 320
                            easing.type: Easing.InBack
                            easing.overshoot: 1.1
                        }
                        NumberAnimation {
                            target: cardDelegate
                            property: "opacity"
                            to: 0
                            duration: 220
                        }
                        onFinished: notificationPopup.disposeNotification(notifId)
                    }

                    readonly property string applicationName: notificationEntry.appName || "Notification"
                    readonly property var applicationIcon: notificationEntry.image || notificationEntry.appIcon || ""

                    property real lifeSpanProgress: 1.0

                    onNotificationEntryChanged: {
                        if (slidingOut)
                            return;
                        lifeSpanProgress = 1.0;
                        expiryAnim.duration = 7000;
                        expiryAnim.restart();
                        updateExpiryPaused();
                    }

                    Connections {
                        target: notificationEntry
                        function onClosed(reason) {
                            cardDelegate.slideOut();
                        }
                    }

                    readonly property bool isOnFocusedScreen: Hyprland.focusedMonitor !== null && modelData.name === Hyprland.focusedMonitor.name

                    property bool expireCalled: false

                    function updateExpiryPaused() {
                        if (!expiryAnim.running)
                            return;
                        const shouldPause = !isOnFocusedScreen || root.hoveredNotificationId === notifId;
                        if (shouldPause && !expiryAnim.paused) {
                            expiryAnim.pause();
                        }
                        if (!shouldPause && expiryAnim.paused) {
                            expiryAnim.duration = 7000 * cardDelegate.lifeSpanProgress;
                            expiryAnim.resume();
                        }
                    }

                    Connections {
                        target: root
                        function onHoveredNotificationIdChanged() {
                            cardDelegate.updateExpiryPaused();
                        }
                    }

                    Connections {
                        target: Hyprland
                        function onFocusedMonitorChanged() {
                            cardDelegate.updateExpiryPaused();
                        }
                    }

                    NumberAnimation {
                        id: expiryAnim
                        target: cardDelegate
                        property: "lifeSpanProgress"
                        from: 1.0
                        to: 0.0
                        duration: 7000
                        running: true

                        onRunningChanged: {
                            if (running) {
                                cardDelegate.updateExpiryPaused();
                            }
                        }

                        onFinished: {
                            if (cardDelegate.lifeSpanProgress > 0.01)
                                return;
                            if (!notificationEntry)
                                return;
                            if (cardDelegate.slidingOut)
                                return;
                            if (cardDelegate.expireCalled)
                                return;
                            cardDelegate.expireCalled = true;
                            if (typeof notificationEntry.expire === "function")
                                notificationEntry.expire();
                        }
                    }

                    Rectangle {
                        id: notificationCard

                        width: parent.width
                        height: layoutContent.implicitHeight + 36
                        y: 4

                        radius: 28
                        color: Theme.surface_container

                        border.color: Theme.outline_variant !== undefined ? Theme.outline_variant : Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.15)
                        border.width: 1

                        scale: interactionArea.pressed ? 0.975 : 1.0
                        layer.enabled: true

                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: "#40000000"
                            blurMax: 32
                            shadowBlur: interactionArea.containsMouse ? 1.0 : 0.85
                            shadowVerticalOffset: interactionArea.containsMouse ? 6 : 4

                            Behavior on shadowBlur {
                                NumberAnimation {
                                    duration: 250
                                    easing.type: Easing.OutCubic
                                }
                            }
                            Behavior on shadowVerticalOffset {
                                NumberAnimation {
                                    duration: 250
                                    easing.type: Easing.OutCubic
                                }
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

                            onEntered: {
                                if (!cardDelegate.slidingOut) {
                                    root.hoveredNotificationId = notifId;
                                }
                            }
                            onExited: {
                                if (root.hoveredNotificationId === notifId) {
                                    root.hoveredNotificationId = -1;
                                }
                            }

                            onClicked: {
                                if (cardDelegate.slidingOut)
                                    return;

                                let invoked = false;
                                if (notificationEntry && notificationEntry.actions) {
                                    for (let i = 0; i < notificationEntry.actions.length; i++) {
                                        if (notificationEntry.actions[i].identifier === "default") {
                                            if (typeof notificationEntry.actions[i].invoke === "function") {
                                                notificationEntry.actions[i].invoke();
                                            }
                                            invoked = true;
                                            break;
                                        }
                                    }
                                }

                                if (!invoked && notificationEntry && typeof notificationEntry.dismiss === "function") {
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
                                        visible: !cardDelegate.applicationIcon

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
                                        source: cardDelegate.applicationIcon
                                        fillMode: Image.PreserveAspectCrop
                                        visible: !!cardDelegate.applicationIcon
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
                                    text: cardDelegate.applicationName
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: headerIconWrapper.right
                                    anchors.leftMargin: 12
                                    font {
                                        family: "Google Sans Medium"
                                        pixelSize: 14
                                    }
                                }

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
                                                sweepAngle: cardDelegate.lifeSpanProgress * 360
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

                                        onEntered: {
                                            if (!cardDelegate.slidingOut) {
                                                closeAction.color = Qt.rgba(Theme.on_surface.r, Theme.on_surface.g, Theme.on_surface.b, 0.08);
                                            }
                                        }
                                        onExited: closeAction.color = "transparent"

                                        onClicked: event => {
                                            event.accepted = true;
                                            if (cardDelegate.slidingOut)
                                                return;

                                            if (notificationEntry && typeof notificationEntry.dismiss === "function") {
                                                notificationEntry.dismiss();
                                            }
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
}
