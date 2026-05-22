import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "../../theme"

PanelWindow {
    id: emojiWindow

    // Geometry
    implicitWidth: 550
    implicitHeight: 640
    color: "transparent"
    visible: false

    // Window Management Layout
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "emoji_overlay"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusiveZone: -1
    anchors.bottom: true
    margins.bottom: 150

    // Instantiate the Separated Backend Controller
    EmojiBackend {
        id: ctrl

        onOpenMenuRequested: {
            if (emojiWindow.visible) {
                closeMenu();
                return;
            }
            if (ctrl.allItems.length === 0) {
                // Controller handles initialization fallback internally
                triggerSearch();
            } else {
                triggerSearch();
            }

            ctrl.searchText = "";
            ctrl.selectionBuffer = "";
            ctrl.currentCategory = "Recents";

            emojiWindow.visible = true;
        }

        onCloseMenuRequested: {
            closeMenu();
        }
    }

    function closeMenu() {
        emojiWindow.visible = false;
        ctrl.commitRecents();
    }

    // Proxy function to safely handle EmojiDelegate's onClicked signals
    function processSelection(emojiChar, isShift) {
        ctrl.processSelection(emojiChar, isShift);
    }

    LazyLoader {
        id: contentLoader

        activeAsync: emojiWindow.visible

        component: Component {
            Item {
                id: delegateContainer

                // Explicitly attach to the Window's visual root
                parent: emojiWindow.contentItem
                anchors.fill: parent
                anchors.margins: 30

                function updateEmojiLabel() {
                    ctrl.currentEmojiName = gridView.currentItem ? gridView.currentItem.emojiName : "";
                }

                HyprlandFocusGrab {
                    id: focusGrab
                    windows: [emojiWindow]
                    onCleared: emojiWindow.closeMenu()
                }

                // Wait until the UI is built to grab focus
                Component.onCompleted: {
                    focusGrab.active = true;
                    mainUi.forceActiveFocus();
                    updateEmojiLabel();
                }

                Rectangle {
                    id: shadowCaster
                    anchors.fill: mainUi
                    radius: 28
                    color: "black"
                    visible: false
                }

                MultiEffect {
                    anchors.fill: shadowCaster
                    source: shadowCaster
                    shadowEnabled: true
                    shadowBlur: 1.0
                    shadowColor: "#60000000"
                    shadowVerticalOffset: 12
                }

                Rectangle {
                    id: mainUiMask
                    anchors.fill: mainUi
                    radius: 28
                    color: "black"
                    visible: false
                    layer.enabled: true
                }

                Rectangle {
                    id: mainUi
                    anchors.fill: parent
                    color: Theme.surface_container
                    radius: 28
                    clip: true
                    focus: true

                    Keys.onPressed: event => {
                        switch (event.key) {
                        case Qt.Key_Escape:
                            emojiWindow.closeMenu();
                            event.accepted = true;
                            break;
                        case Qt.Key_Tab:
                            ctrl.cycleCategory();
                            event.accepted = true;
                            break;
                        case Qt.Key_Down:
                        case Qt.Key_J:
                            gridView.moveCurrentIndexDown();
                            updateEmojiLabel();
                            event.accepted = true;
                            break;
                        case Qt.Key_Up:
                        case Qt.Key_K:
                            gridView.moveCurrentIndexUp();
                            updateEmojiLabel();
                            event.accepted = true;
                            break;
                        case Qt.Key_Left:
                        case Qt.Key_H:
                            gridView.moveCurrentIndexLeft();
                            updateEmojiLabel();
                            event.accepted = true;
                            break;
                        case Qt.Key_Right:
                        case Qt.Key_L:
                            gridView.moveCurrentIndexRight();
                            updateEmojiLabel();
                            event.accepted = true;
                            break;
                        case Qt.Key_Enter:
                        case Qt.Key_Return:
                            if (gridView.currentItem) {
                                ctrl.processSelection(gridView.currentItem.emojiChar, (event.modifiers & Qt.ShiftModifier) !== 0);
                            }
                            event.accepted = true;
                            break;
                        case Qt.Key_Slash:
                            searchField.forceActiveFocus();
                            event.accepted = true;
                            break;
                        }
                    }

                    // Header Area
                    Item {
                        id: headerArea
                        width: parent.width
                        height: 64
                        anchors.top: parent.top

                        Text {
                            id: headerTitle
                            anchors {
                                top: parent.top
                                left: parent.left
                                margins: 24
                                topMargin: 20
                            }
                            text: "Emojis"
                            color: Theme.on_surface
                            font {
                                family: "Google Sans"
                                pixelSize: 26
                                weight: Font.Medium
                            }
                        }

                        Rectangle {
                            id: clearRecentsBtn
                            anchors {
                                right: parent.right
                                rightMargin: 24
                                verticalCenter: headerTitle.verticalCenter
                            }
                            width: 36
                            height: 36
                            radius: 18
                            color: clearMouseArea.containsMouse ? Theme.surface_container_highest : "transparent"
                            visible: ctrl.currentCategory === "Recents" && ctrl.recentItems.length > 0

                            Text {
                                anchors.centerIn: parent
                                text: "delete"
                                font {
                                    family: "Material Symbols Rounded"
                                    pixelSize: 26
                                    bold: true
                                }
                                color: Theme.critical
                            }

                            MouseArea {
                                id: clearMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ctrl.clearRecents()
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }
                        }
                    }

                    // Search Box
                    TextField {
                        id: searchField
                        anchors {
                            top: headerArea.bottom
                            left: parent.left
                            right: parent.right
                            margins: 16
                            topMargin: 4
                        }
                        height: 56
                        leftPadding: 52
                        rightPadding: text !== "" ? 48 : 16
                        font {
                            family: "Google Sans"
                            pixelSize: 17
                        }
                        color: Theme.on_surface
                        selectionColor: Theme.primary_container
                        selectedTextColor: Theme.on_primary_container
                        placeholderText: "Search"
                        placeholderTextColor: Theme.on_surface_variant

                        background: Rectangle {
                            color: searchField.activeFocus ? Theme.surface_container_highest : Theme.surface_container_high
                            radius: height / 2
                            border.width: searchField.activeFocus ? 2 : 1
                            border.color: searchField.activeFocus ? Theme.primary : Theme.outline_variant
                            Behavior on border.color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }

                            Text {
                                anchors {
                                    left: parent.left
                                    leftMargin: 20
                                    verticalCenter: parent.verticalCenter
                                }
                                text: "search"
                                font {
                                    family: "Material Symbols Rounded"
                                    pixelSize: 24
                                }
                                color: searchField.activeFocus ? Theme.primary : Theme.on_surface_variant
                            }
                        }

                        // Pipe visual typing up into controller layer
                        onTextChanged: ctrl.searchText = text

                        Keys.onPressed: event => {
                            switch (event.key) {
                            case Qt.Key_Down:
                                gridView.moveCurrentIndexDown();
                                updateEmojiLabel();
                                event.accepted = true;
                                break;
                            case Qt.Key_Up:
                                gridView.moveCurrentIndexUp();
                                updateEmojiLabel();
                                event.accepted = true;
                                break;
                            case Qt.Key_Left:
                                gridView.moveCurrentIndexLeft();
                                updateEmojiLabel();
                                event.accepted = true;
                                break;
                            case Qt.Key_Right:
                                gridView.moveCurrentIndexRight();
                                updateEmojiLabel();
                                event.accepted = true;
                                break;
                            case Qt.Key_Tab:
                                ctrl.cycleCategory();
                                event.accepted = true;
                                break;
                            case Qt.Key_Enter:
                            case Qt.Key_Return:
                                if (gridView.currentItem) {
                                    ctrl.processSelection(gridView.currentItem.emojiChar, event.modifiers & Qt.ShiftModifier);
                                }
                                event.accepted = true;
                                break;
                            case Qt.Key_Escape:
                                mainUi.forceActiveFocus();
                                event.accepted = true;
                                break;
                            }
                        }
                    }

                    // Categories
                    Item {
                        id: categoryTabsContainer
                        anchors {
                            top: searchField.bottom
                            left: parent.left
                            right: parent.right
                            leftMargin: 16
                            rightMargin: 16
                            topMargin: 8
                        }
                        height: 48

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            onWheel: wheel => {
                                let delta = wheel.angleDelta.x !== 0 ? wheel.angleDelta.x : wheel.angleDelta.y;
                                let target = smoothScrollAnim.running ? smoothScrollAnim.to : categoryList.contentX;
                                let max = Math.max(0, categoryList.contentWidth - categoryList.width);
                                smoothScrollAnim.to = Math.max(0, Math.min(target - delta, max));
                                smoothScrollAnim.start();
                            }
                        }

                        ListView {
                            id: categoryList
                            anchors {
                                top: parent.top
                                bottom: parent.bottom
                                horizontalCenter: parent.horizontalCenter
                            }
                            width: Math.min(contentWidth, parent.width)
                            orientation: ListView.Horizontal
                            spacing: 12
                            boundsBehavior: Flickable.StopAtBounds
                            model: ctrl.categories
                            onMovementStarted: smoothScrollAnim.stop()

                            NumberAnimation {
                                id: smoothScrollAnim
                                target: categoryList
                                property: "contentX"
                                duration: 350
                                easing.type: Easing.OutQuart
                            }

                            delegate: Rectangle {
                                property bool isSelected: modelData === ctrl.currentCategory
                                height: 36
                                width: tabText.width + 32
                                anchors.verticalCenter: parent.verticalCenter
                                radius: 18
                                color: isSelected ? Theme.primary : Theme.surface_container_high
                                border {
                                    width: isSelected ? 0 : 1
                                    color: Theme.outline_variant
                                }

                                Text {
                                    id: tabText
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: isSelected ? Theme.on_primary : Theme.on_surface_variant
                                    font {
                                        family: "Google Sans"
                                        pixelSize: 14
                                        weight: isSelected ? Font.DemiBold : Font.Medium
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (searchField.text !== "")
                                            searchField.text = "";
                                        ctrl.currentCategory = modelData;
                                    }
                                }
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 150
                                    }
                                }
                            }
                        }
                    }

                    // Grid Layout View
                    Item {
                        id: listContainer
                        anchors {
                            top: categoryTabsContainer.bottom
                            bottom: footer.top
                            left: parent.left
                            right: parent.right
                            topMargin: 8
                        }

                        GridView {
                            id: gridView
                            anchors {
                                top: parent.top
                                bottom: parent.bottom
                                horizontalCenter: parent.horizontalCenter
                            }
                            width: Math.floor((parent.width - 44) / cellWidth) * cellWidth
                            topMargin: 12
                            bottomMargin: 24
                            cellWidth: 60
                            cellHeight: 60
                            model: ctrl.filteredItems
                            clip: true
                            highlightMoveDuration: 120
                            highlightFollowsCurrentItem: true
                            opacity: ctrl.isSearchingState ? 0.4 : 1.0
                            onCurrentIndexChanged: updateEmojiLabel()

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 120
                                    easing.type: Easing.OutQuad
                                }
                            }
                            delegate: EmojiDelegate {}
                        }

                        Rectangle {
                            anchors {
                                bottom: parent.bottom
                                left: parent.left
                                right: parent.right
                            }
                            height: 48
                            gradient: Gradient {
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
                    }

                    // Footer Toolbar Panel
                    Item {
                        id: footer
                        anchors {
                            bottom: parent.bottom
                            left: parent.left
                            right: parent.right
                        }
                        height: 64

                        Rectangle {
                            anchors.fill: parent
                            color: Theme.surface_container_low
                            radius: 28
                            Rectangle {
                                anchors {
                                    top: parent.top
                                    left: parent.left
                                    right: parent.right
                                }
                                height: 25
                                color: Theme.surface_container_low
                            }
                        }

                        Rectangle {
                            anchors {
                                top: parent.top
                                left: parent.left
                                right: parent.right
                            }
                            height: 1
                            color: Theme.outline_variant
                            opacity: 0.5
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 4
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 8
                                Text {
                                    text: ctrl.selectionBuffer
                                    visible: ctrl.selectionBuffer !== ""
                                    anchors.verticalCenter: parent.verticalCenter
                                    font {
                                        family: "Noto Color Emoji"
                                        pixelSize: 18
                                    }
                                }
                                Text {
                                    text: ctrl.selectionBuffer !== "" ? ("+ " + (ctrl.currentEmojiName || "")) : (ctrl.currentEmojiName || "Select an emoji")
                                    color: Theme.on_surface_variant
                                    anchors.verticalCenter: parent.verticalCenter
                                    font {
                                        family: "Google Sans Medium"
                                        pixelSize: 15
                                    }
                                }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "[Tab] Switch • [Enter] Select • [Shift] Multi • [Esc] Close"
                                color: Theme.on_surface_variant
                                opacity: 0.6
                                font {
                                    family: "Google Sans"
                                    pixelSize: 11
                                    weight: Font.Medium
                                }
                            }
                        }
                    }

                    Text {
                        id: emptyMessage
                        anchors.centerIn: listContainer
                        text: ctrl.currentCategory === "Recents" && ctrl.recentItems.length === 0 ? "No recent emojis" : "No emojis found 🥲"
                        visible: ctrl.filteredItems.length === 0 && !ctrl.isSearchingState
                        color: Theme.on_surface_variant
                        font {
                            family: "Google Sans Medium"
                            pixelSize: 18
                        }
                    }

                    // Outer Profile Trim
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        radius: 28
                        border {
                            width: 1
                            color: Theme.outline_variant
                        }
                        z: 99
                    }
                }
            }
        }
    }
}
