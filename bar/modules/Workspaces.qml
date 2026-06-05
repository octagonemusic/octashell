import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.theme

Rectangle {
    id: root

    property string targetMonitor: ""
    property Item currentActiveDot: null

    readonly property int animDurationShort: 150
    readonly property int dotHeight: 28
    readonly property int spacingAmount: 6

    readonly property var sortedWorkspaces: {
        var ws = Hyprland.workspaces.values;
        return ws.filter(w => w.id >= 1 && w.monitor?.name === root.targetMonitor).sort((a, b) => a.id - b.id);
    }

    implicitWidth: mainLayout.width + 16
    implicitHeight: mainLayout.height + 12
    color: Theme.surface_container
    radius: height / 2

    Component.onCompleted: {
        Hyprland.refreshToplevels();
        Hyprland.refreshWorkspaces();
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "openwindow" || event.name === "closewindow" || event.name === "movewindow") {
                Hyprland.refreshToplevels();
                Hyprland.refreshWorkspaces();
            }
        }
    }

    // The Global Sliding Highlight
    Rectangle {
        id: slidingHighlight

        // Calculate the static final X position instantly to prevent animation stutter
        property real targetX: {
            if (!currentActiveDot)
                return 0;
            let tx = 0;
            for (let i = 0; i < dotRepeater.count; i++) {
                let child = dotRepeater.itemAt(i);
                if (!child)
                    continue;
                if (child === currentActiveDot)
                    break;
                if (child.isVisible) {
                    tx += child.targetWidth + mainLayout.spacing;
                }
            }
            return tx;
        }

        y: mainLayout.y
        x: mainLayout.x + targetX
        width: currentActiveDot ? currentActiveDot.targetWidth : 0
        height: root.dotHeight
        radius: height / 2

        color: currentActiveDot?.isFocused ? (Theme.primary ?? "#6750A4") : (Theme.primary_container ?? "#EADDFF")
        Behavior on color {
            ColorAnimation {
                duration: root.animDurationShort
            }
        }

        // Clean Calendar Physics (No more stutter!)
        Behavior on x {
            NumberAnimation {
                duration: 280
                easing.type: Easing.OutBack
                easing.overshoot: 1.5
            }
        }
        Behavior on width {
            NumberAnimation {
                duration: 280
                easing.type: Easing.OutBack
                easing.overshoot: 1.5
            }
        }
    }

    Row {
        id: mainLayout
        anchors.centerIn: parent
        spacing: root.spacingAmount

        Repeater {
            id: dotRepeater
            model: ScriptModel {
                values: root.sortedWorkspaces
            }

            delegate: Item {
                id: workspaceDot

                readonly property bool isVisible: modelData.id >= 1 && modelData.monitor?.name === root.targetMonitor
                readonly property bool isFocused: modelData.focused
                readonly property bool isActive: modelData.active
                readonly property var toplevelValues: modelData.toplevels.values
                readonly property int windowCount: toplevelValues.length
                readonly property bool hasWindows: windowCount > 0

                visible: isVisible

                onIsFocusedChanged: if (isFocused)
                    root.currentActiveDot = workspaceDot
                onIsActiveChanged: if (isActive && !modelData.focused)
                    root.currentActiveDot = workspaceDot

                Component.onCompleted: {
                    if (isFocused || (isActive && !root.currentActiveDot)) {
                        root.currentActiveDot = workspaceDot;
                    }
                }

                // Instant target calculation for the highlight tracker
                readonly property real targetWidth: {
                    if (!isVisible)
                        return 0;
                    if (!hasWindows)
                        return isFocused || isActive ? 36 : (dotHover.hovered ? 24 : 16);
                    let padding = isFocused || isActive ? 20 : 16;
                    let minimum = isFocused || isActive ? 48 : (dotHover.hovered ? 44 : 36);
                    return Math.max(minimum, iconsRow.width + padding);
                }

                width: targetWidth
                height: root.dotHeight

                Behavior on width {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.1
                    }
                }

                Rectangle {
                    id: inactivePill
                    anchors.fill: parent
                    radius: height / 2

                    opacity: (workspaceDot.isFocused || workspaceDot.isActive) ? 0.0 : 1.0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                        }
                    }

                    color: dotHover.hovered ? (Theme.secondary_container ?? "#E8DEF8") : (Theme.surface_container_high ?? "#ECE6F0")
                    Behavior on color {
                        ColorAnimation {
                            duration: root.animDurationShort
                        }
                    }
                }

                scale: dotTap.pressed ? 0.92 : (dotHover.hovered ? 1.04 : 1.0)
                Behavior on scale {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.5
                    }
                }

                Row {
                    id: iconsRow
                    anchors.centerIn: parent
                    spacing: -8
                    visible: workspaceDot.hasWindows

                    Repeater {
                        model: workspaceDot.toplevelValues

                        delegate: Item {
                            id: iconSlot
                            visible: index < 3
                            width: visible ? 18 : 0
                            height: 18

                            readonly property string appClass: modelData.lastIpcObject?.class ?? ""
                            readonly property string appTitle: modelData.title ?? ""

                            readonly property var desktopEntry: {
                                if (appClass !== "") {
                                    var e = DesktopEntries.byId(appClass) || DesktopEntries.byId(appClass.toLowerCase()) || DesktopEntries.heuristicLookup(appClass);
                                    if (e)
                                        return e;
                                }
                                if (appTitle !== "") {
                                    var cleanTitle = appTitle.replace(/\s*[—–-].*$/, "").trim();
                                    return DesktopEntries.heuristicLookup(cleanTitle);
                                }
                                return null;
                            }

                            readonly property string iconSource: {
                                if (desktopEntry?.icon) {
                                    var icon = desktopEntry.icon;
                                    return icon.startsWith("/") ? "file://" + icon : "image://icon/" + icon;
                                }
                                if (appClass !== "")
                                    return "image://icon/" + appClass;
                                return "image://icon/application-x-executable";
                            }

                            IconImage {
                                id: iconImg
                                anchors.fill: parent
                                source: iconSlot.iconSource
                                smooth: true
                                visible: false

                                onStatusChanged: {
                                    if (status === Image.Error)
                                        source = "image://icon/application-x-executable";
                                }
                            }

                            MultiEffect {
                                anchors.fill: iconImg
                                source: iconImg

                                saturation: -0.3
                                colorizationColor: (workspaceDot.isFocused || workspaceDot.isActive) ? Theme.on_primary : (Theme.on_surface_variant ?? "#49454F")
                                colorization: 0.3

                                opacity: iconImg.status === Image.Ready ? 1.0 : 0.0
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 100
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        visible: workspaceDot.windowCount > 3
                        width: 18
                        height: 18
                        radius: 9
                        color: "transparent" // Matches natural overlap

                        border.color: (workspaceDot.isFocused || workspaceDot.isActive) ? Theme.on_primary : (Theme.on_surface_variant ?? "#49454F")
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "+" + (workspaceDot.windowCount - 3)
                            color: (workspaceDot.isFocused || workspaceDot.isActive) ? Theme.on_primary : (Theme.on_surface_variant ?? "#49454F")
                            font {
                                family: "Google Sans"
                                pixelSize: 9
                                weight: Font.Bold
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    visible: !workspaceDot.hasWindows

                    width: workspaceDot.isFocused ? 8 : (dotHover.hovered ? 7 : 5)
                    height: width
                    radius: width / 2

                    color: (workspaceDot.isFocused || workspaceDot.isActive) ? Theme.on_primary : (Theme.on_surface_variant ?? "#49454F")
                    opacity: workspaceDot.isFocused ? 1.0 : (dotHover.hovered ? 0.9 : 0.5)

                    Behavior on width {
                        NumberAnimation {
                            duration: 250
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.5
                        }
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: root.animDurationShort
                        }
                    }
                }

                TapHandler {
                    id: dotTap
                    margin: 8
                    onTapped: modelData.activate()
                }
                HoverHandler {
                    id: dotHover
                    margin: 8
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }
}
