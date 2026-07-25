import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.theme

Rectangle {
    id: root

    property string targetMonitor: ""

    // Animation state.
    property bool windowVisible: true
    property bool isLoaded: false
    readonly property bool allowAnimations: isLoaded && windowVisible

    readonly property int animDurationShort: 150
    readonly property int dotHeight: 28
    readonly property int spacingAmount: 6

    // Icon cache.
    property var iconCache: ({})

    function resolveIconSource(appClass, appTitle) {
        var lowerClass = (appClass || "").toLowerCase();
        var cacheKey = lowerClass !== "" ? lowerClass : ("title:" + appTitle);

        if (root.iconCache.hasOwnProperty(cacheKey))
            return root.iconCache[cacheKey];

        var exactTitle = (appTitle || "").trim().toLowerCase();
        var desktopEntry = null;

        if (lowerClass !== "") {
            // Exact lookup.
            desktopEntry = DesktopEntries.byId(appClass) || DesktopEntries.byId(lowerClass) || DesktopEntries.byId(lowerClass.replace(/_/g, "-"));

            var apps = DesktopEntries.applications.values;

            // WMClass lookup.
            if (!desktopEntry) {
                for (var i = 0; i < apps.length; i++) {
                    if ((apps[i].startupWmClass || "").toLowerCase() === lowerClass) {
                        desktopEntry = apps[i];
                        break;
                    }
                }
            }

            // Steam AppID lookup.
            if (!desktopEntry) {
                var uniqueIdMatch = lowerClass.match(/\d{4,}/);
                if (uniqueIdMatch) {
                    var numericId = uniqueIdMatch[0];
                    for (var k = 0; k < apps.length; k++) {
                        if (apps[k].id.includes(numericId)) {
                            desktopEntry = apps[k];
                            break;
                        }
                    }
                }
            }

            // Title lookup.
            if (!desktopEntry && exactTitle !== "") {
                for (var j = 0; j < apps.length; j++) {
                    var appName = (apps[j].name || "").toLowerCase();
                    if (appName !== "" && (exactTitle === appName || exactTitle.startsWith(appName))) {
                        desktopEntry = apps[j];
                        break;
                    }
                }
            }

            if (!desktopEntry)
                desktopEntry = DesktopEntries.heuristicLookup(appClass);
        }

        var guesses = [];

        if (desktopEntry && desktopEntry.icon)
            guesses.push(desktopEntry.icon);

        if (appClass !== "") {
            guesses.push(appClass);
            guesses.push(lowerClass);
            guesses.push(lowerClass.replace(/_/g, "-"));

            // Steam icon fallback.
            if (lowerClass.includes("app"))
                guesses.push(lowerClass.replace("app", "icon"));

            // Filter generic tokens.
            var ignoreList = ["app", "desktop", "com", "org", "net", "io", "www", "bin"];
            var tokens = lowerClass.split(/[^a-z0-9]/).filter(t => t.length > 2 && !ignoreList.includes(t));

            for (var t = tokens.length - 1; t >= 0; t--)
                guesses.push(tokens[t]);
        }

        var resolved = Quickshell.iconPath("application-x-executable", true);
        for (var g = 0; g < guesses.length; g++) {
            var guess = guesses[g];
            if (!guess)
                continue;

            if (guess.startsWith("/")) {
                resolved = "file://" + guess;
                break;
            }

            var path = Quickshell.iconPath(guess, true);
            if (path && path !== "") {
                resolved = path;
                break;
            }
        }

        root.iconCache[cacheKey] = resolved;
        return resolved;
    }

    readonly property var sortedWorkspaces: {
        var ws = Hyprland.workspaces.values;
        return ws.filter(w => w.id >= 1 && w.monitor?.name === root.targetMonitor).sort((a, b) => a.id - b.id);
    }

    // Focused workspace.
    readonly property var focusedWorkspace: {
        for (let i = 0; i < sortedWorkspaces.length; i++) {
            if (sortedWorkspaces[i].focused)
                return sortedWorkspaces[i];
        }
        for (let i = 0; i < sortedWorkspaces.length; i++) {
            if (sortedWorkspaces[i].active)
                return sortedWorkspaces[i];
        }
        return null;
    }

    // Active workspace item.
    readonly property Item currentActiveDot: {
        if (!root.focusedWorkspace)
            return null;
        for (let i = 0; i < dotRepeater.count; i++) {
            let child = dotRepeater.itemAt(i);
            if (child && child.modelDataId === root.focusedWorkspace.id)
                return child;
        }
        return null;
    }

    implicitWidth: mainLayout.width + 16
    implicitHeight: mainLayout.height + 16
    color: Theme.surface_container
    radius: height / 2

    Component.onCompleted: {
        Hyprland.refreshToplevels();
        Hyprland.refreshWorkspaces();
        Qt.callLater(() => {
            root.isLoaded = true;
        });
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

    // Active highlight.
    Rectangle {
        id: slidingHighlight

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
                if (child.isVisible)
                    tx += child.targetWidth + mainLayout.spacing;
            }
            return tx;
        }

        y: mainLayout.y
        x: mainLayout.x + targetX
        width: currentActiveDot ? currentActiveDot.targetWidth : 0
        height: root.dotHeight

        // Active pill shape.
        topLeftRadius: height * 0.15
        topRightRadius: height * 0.9
        bottomRightRadius: height * 0.15
        bottomLeftRadius: height * 0.9

        color: currentActiveDot?.isFocused ? (Theme.primary ?? "#6750A4") : (Theme.primary_container ?? "#EADDFF")

        Behavior on color {
            enabled: root.allowAnimations
            ColorAnimation {
                duration: root.animDurationShort
            }
        }

        Behavior on x {
            enabled: root.allowAnimations
            NumberAnimation {
                duration: 280
                easing.type: Easing.OutBack
                easing.overshoot: 1.5
            }
        }

        Behavior on width {
            enabled: root.allowAnimations
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

                readonly property int modelDataId: modelData.id
                readonly property bool isVisible: modelData.id >= 1 && modelData.monitor?.name === root.targetMonitor
                readonly property bool isFocused: modelData.focused
                readonly property bool isActive: modelData.active
                readonly property var toplevelValues: modelData.toplevels.values
                readonly property int windowCount: toplevelValues.length
                readonly property bool hasWindows: windowCount > 0

                visible: isVisible

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
                    enabled: root.allowAnimations
                    NumberAnimation {
                        duration: 280
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.5
                    }
                }

                Rectangle {
                    id: inactivePill
                    anchors.fill: parent
                    radius: height / 2
                    opacity: (workspaceDot.isFocused || workspaceDot.isActive) ? 0.0 : 1.0

                    Behavior on opacity {
                        enabled: root.allowAnimations
                        NumberAnimation {
                            duration: 150
                        }
                    }

                    color: dotHover.hovered ? (Theme.secondary_container ?? "#E8DEF8") : (Theme.surface_container_high ?? "#ECE6F0")

                    Behavior on color {
                        enabled: root.allowAnimations
                        ColorAnimation {
                            duration: root.animDurationShort
                        }
                    }
                }

                Rectangle {
                    id: stateLayer
                    anchors.fill: parent
                    radius: height / 2

                    color: (workspaceDot.isFocused || workspaceDot.isActive) ? (Theme.on_primary ?? "#FFFFFF") : (Theme.on_surface ?? "#1C1B1F")
                    opacity: dotTap.pressed ? 0.10 : (dotHover.hovered ? 0.08 : 0.0)

                    Behavior on opacity {
                        enabled: root.allowAnimations
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutQuad
                        }
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

                            readonly property string iconSource: root.resolveIconSource(appClass, appTitle)
                            readonly property string fallbackLetter: {
                                var name = appClass !== "" ? appClass : appTitle;
                                return name.length > 0 ? name.charAt(0).toUpperCase() : "?";
                            }

                            // Rounded icon mask.
                            Rectangle {
                                id: roundMask
                                anchors.centerIn: parent
                                width: 18
                                height: 18
                                radius: 9
                                color: "black"
                                visible: false
                                layer.enabled: true
                            }

                            // Icon separator.
                            Rectangle {
                                anchors.centerIn: parent
                                width: 19
                                height: 19
                                radius: 9.5
                                color: "transparent"
                                border.width: 1.5
                                border.color: (workspaceDot.isFocused || workspaceDot.isActive) ? (Theme.primary ?? "#6750A4") : (Theme.surface_container_high ?? "#ECE6F0")

                                Behavior on border.color {
                                    enabled: root.allowAnimations
                                    ColorAnimation {
                                        duration: root.animDurationShort
                                    }
                                }
                            }

                            Rectangle {
                                id: fallbackBadge
                                anchors.fill: parent
                                radius: height / 2
                                color: (workspaceDot.isFocused || workspaceDot.isActive) ? (Theme.on_primary ?? "#FFFFFF") : (Theme.on_surface_variant ?? "#49454F")
                                opacity: (iconImg.status === Image.Ready && iconImg.source != "") ? 0.0 : 0.3
                                visible: opacity > 0

                                Behavior on opacity {
                                    enabled: root.allowAnimations
                                    NumberAnimation {
                                        duration: 100
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: iconSlot.fallbackLetter
                                    color: (workspaceDot.isFocused || workspaceDot.isActive) ? (Theme.primary ?? "#6750A4") : (Theme.surface_container ?? "#FFFFFF")
                                    font {
                                        family: "Google Sans"
                                        pixelSize: 10
                                        weight: Font.Bold
                                    }
                                }
                            }

                            IconImage {
                                id: iconImg
                                anchors.fill: parent
                                source: iconSlot.iconSource
                                smooth: true
                                visible: false // Visibility delegated to MultiEffect
                            }

                            MultiEffect {
                                anchors.fill: iconImg
                                source: iconImg

                                maskEnabled: true
                                maskSource: roundMask
                                maskThresholdMin: 0.5
                                maskSpreadAtMin: 1.0

                                saturation: -0.3
                                colorizationColor: (workspaceDot.isFocused || workspaceDot.isActive) ? (Theme.on_primary ?? "#FFFFFF") : (Theme.on_surface_variant ?? "#49454F")
                                colorization: 0.3

                                opacity: (iconImg.status === Image.Ready && iconImg.source != "") ? 1.0 : 0.0

                                Behavior on opacity {
                                    enabled: root.allowAnimations
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
                        color: "transparent"
                        border.color: (workspaceDot.isFocused || workspaceDot.isActive) ? (Theme.on_primary ?? "#FFFFFF") : (Theme.on_surface_variant ?? "#49454F")
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "+" + (workspaceDot.windowCount - 3)
                            color: (workspaceDot.isFocused || workspaceDot.isActive) ? (Theme.on_primary ?? "#FFFFFF") : (Theme.on_surface_variant ?? "#49454F")
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

                    width: workspaceDot.isFocused ? 8 : 6
                    height: width
                    radius: width / 2

                    color: (workspaceDot.isFocused || workspaceDot.isActive) ? (Theme.on_primary ?? "#FFFFFF") : (Theme.on_surface_variant ?? "#49454F")
                    opacity: workspaceDot.isFocused ? 1.0 : (dotHover.hovered ? 1.0 : 0.6)

                    Behavior on width {
                        enabled: root.allowAnimations
                        NumberAnimation {
                            duration: 280
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.5
                        }
                    }

                    Behavior on color {
                        enabled: root.allowAnimations
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
