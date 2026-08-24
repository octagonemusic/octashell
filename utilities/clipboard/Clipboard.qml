import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "../../theme"

PanelWindow {
    id: clipboardWindow

    implicitWidth: 600
    implicitHeight: 750
    color: "transparent"
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "clipboard_overlay"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusiveZone: -1

    anchors.bottom: true
    margins.bottom: 100

    ClipboardBackend {
        id: ctrl

        onOpenMenuRequested: {
            if (clipboardWindow.visible) {
                closeMenu();
            } else {
                ctrl.resetSelectionPending = true; // Force selection back to the first item
                ctrl.triggerRefresh();
                ctrl.searchText = "";
                ctrl.currentTab = 0; // Reset to All Clips on open
                clipboardWindow.visible = true;
            }
        }

        onCloseMenuRequested: {
            closeMenu();
        }
    }

    function closeMenu() {
        clipboardWindow.visible = false;
    }

    LazyLoader {
        id: contentLoader

        activeAsync: clipboardWindow.visible

        component: Component {
            Item {
                id: delegateContainer

                // Explicitly attach to the Window's visual root
                parent: clipboardWindow.contentItem
                anchors.fill: parent
                anchors.margins: 30

                HyprlandFocusGrab {
                    id: focusGrab
                    windows: [clipboardWindow]
                    onCleared: clipboardWindow.closeMenu()
                }

                // Wait until the UI is built to grab focus
                Component.onCompleted: {
                    focusGrab.active = true;
                    mainUi.forceActiveFocus();
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
                    color: Theme.surface
                    radius: 28
                    focus: true

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: mainUiMask
                    }

                    // Ramps nav speed up the longer j/k or an arrow key is held
                    property int navRepeatCount: 0

                    function navigate(direction, isAutoRepeat) {
                        navRepeatCount = isAutoRepeat ? navRepeatCount + 1 : 0;
                        let step = navRepeatCount > 12 ? 4 : (navRepeatCount > 6 ? 3 : (navRepeatCount > 2 ? 2 : 1));
                        listView.cancelFlick();
                        // Scrolling can shift a different row under a stationary cursor,
                        // whose hover would otherwise steal the selection back
                        listView.suppressHoverSelect = true;
                        hoverSuppressTimer.restart();
                        listView.currentIndex = Math.max(0, Math.min(listView.currentIndex + direction * step, listView.count - 1));
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape || event.key === Qt.Key_H) {
                            clipboardWindow.closeMenu();
                        } else if (event.key === Qt.Key_X) {
                            if (listView.currentItem) {
                                listView.currentItem.remove();
                            }
                        } else if (event.key === Qt.Key_P) {
                            if (listView.currentItem) {
                                listView.currentItem.togglePinState();
                            }
                        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                            mainUi.navigate(1, event.isAutoRepeat);
                        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                            mainUi.navigate(-1, event.isAutoRepeat);
                        } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return || event.key === Qt.Key_L) {
                            if (listView.currentItem)
                                listView.currentItem.select();
                        } else if (event.key === Qt.Key_Slash) {
                            searchField.forceActiveFocus();
                        } else if (event.key === Qt.Key_Tab) {
                            ctrl.currentTab = ctrl.currentTab === 0 ? 1 : 0;
                        }
                        event.accepted = true;
                    }

                    // Header Area
                    Item {
                        id: headerArea
                        width: parent.width
                        height: 72
                        anchors.top: parent.top

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 24
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Clipboard"
                            color: Theme.on_surface
                            font {
                                family: "Google Sans Medium"
                                pixelSize: 26
                            }
                        }

                        Rectangle {
                            id: clearButton
                            anchors.right: parent.right
                            anchors.rightMargin: 24
                            anchors.verticalCenter: parent.verticalCenter
                            width: clearText.implicitWidth + 32
                            height: 36
                            radius: 18
                            scale: clearMouseArea.pressed ? 0.92 : (clearMouseArea.containsMouse ? 1.05 : 1.0)
                            color: clearMouseArea.containsMouse ? Theme.critical : "transparent"
                            border.width: 1
                            border.color: clearMouseArea.containsMouse ? Theme.critical : Theme.outline

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutBack
                                }
                            }

                            Text {
                                id: clearText
                                anchors.centerIn: parent
                                text: "Clear"
                                color: clearMouseArea.containsMouse ? Theme.on_critical : Theme.on_surface_variant
                                font {
                                    family: "Google Sans Medium"
                                    pixelSize: 16
                                }
                            }

                            MouseArea {
                                id: clearMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ctrl.clearUnpinnedHistory()
                            }
                        }
                    }

                    // Search Bar
                    Item {
                        id: searchArea
                        width: parent.width
                        height: 80
                        anchors.top: headerArea.bottom

                        TextField {
                            id: searchField
                            anchors.fill: parent
                            anchors.margins: 12
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            leftPadding: 48
                            rightPadding: searchField.text !== "" ? 48 : 16
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
                                id: searchBg
                                color: searchField.activeFocus ? Theme.surface_container_highest : Theme.surface_container_high
                                radius: 28
                                border.width: searchField.activeFocus ? 2 : 1
                                border.color: searchField.activeFocus ? Theme.primary : Theme.outline_variant
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 200
                                    }
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "search"
                                    font {
                                        family: "Material Symbols Rounded"
                                        pixelSize: 22
                                    }
                                    color: searchField.activeFocus ? Theme.primary : Theme.on_surface_variant
                                }
                            }

                            onTextChanged: ctrl.searchText = text

                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Down) {
                                    mainUi.navigate(1, event.isAutoRepeat);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Up) {
                                    mainUi.navigate(-1, event.isAutoRepeat);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                                    if (listView.currentItem)
                                        listView.currentItem.select();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Escape) {
                                    mainUi.forceActiveFocus();
                                    event.accepted = true;
                                }
                            }
                        }
                    }

                    // Tab Controls
                    Item {
                        id: tabArea
                        width: parent.width
                        height: 50
                        anchors.top: searchArea.bottom

                        Row {
                            anchors.centerIn: parent
                            spacing: 12

                            Rectangle {
                                width: 130
                                height: 38
                                radius: 19
                                color: ctrl.currentTab === 0 ? Theme.primary : "transparent"
                                border.width: ctrl.currentTab === 0 ? 0 : 1
                                border.color: Theme.outline_variant

                                Text {
                                    anchors.centerIn: parent
                                    text: "All Clips"
                                    color: ctrl.currentTab === 0 ? Theme.on_primary : Theme.on_surface_variant
                                    font {
                                        family: "Google Sans Medium"
                                        pixelSize: 15
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ctrl.currentTab = 0
                                }
                            }

                            Rectangle {
                                width: 130
                                height: 38
                                radius: 19
                                color: ctrl.currentTab === 1 ? Theme.primary : "transparent"
                                border.width: ctrl.currentTab === 1 ? 0 : 1
                                border.color: Theme.outline_variant

                                Text {
                                    anchors.centerIn: parent
                                    text: "Pinned"
                                    color: ctrl.currentTab === 1 ? Theme.on_primary : Theme.on_surface_variant
                                    font {
                                        family: "Google Sans Medium"
                                        pixelSize: 15
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ctrl.currentTab = 1
                                }
                            }
                        }
                    }

                    // Clip List
                    Item {
                        id: listContainer
                        anchors.top: tabArea.bottom
                        anchors.bottom: footer.top
                        anchors.left: parent.left
                        anchors.right: parent.right

                        clip: true

                        ListView {
                            id: listView
                            anchors.fill: parent
                            topMargin: 8
                            bottomMargin: 48
                            spacing: 8
                            highlightMoveDuration: 40
                            highlightFollowsCurrentItem: true
                            delegate: ClipboardDelegate {}

                            flickDeceleration: 4000
                            maximumFlickVelocity: 5000

                            model: ScriptModel {
                                values: ctrl.filteredItems
                            }

                            // Raw of the item to select once the next refresh lands (set by a
                            // delegate before it removes/unpins itself). Empty means top.
                            property string pendingSelectKey: ""

                            // Hover re-fires onEntered when a row moves under a stationary
                            // cursor, not just on real mouse movement. Suppressed briefly
                            // after any refresh or nav so it can't steal selection back.
                            property bool suppressHoverSelect: false

                            Timer {
                                id: hoverSuppressTimer
                                interval: 150
                                onTriggered: listView.suppressHoverSelect = false
                            }

                            Connections {
                                target: ctrl
                                function onFilteredItemsChanged() {
                                    listView.suppressHoverSelect = true;
                                    hoverSuppressTimer.restart();

                                    // Consume unconditionally (even on an empty refresh) so it
                                    // can't stay stuck true and reset scroll on a later refresh
                                    let openedFresh = ctrl.resetSelectionPending;
                                    ctrl.resetSelectionPending = false;

                                    let pendingKey = listView.pendingSelectKey;
                                    listView.pendingSelectKey = "";

                                    if (listView.count === 0)
                                        return;

                                    let targetIndex = 0;
                                    let restoredNeighbor = false;
                                    if (!openedFresh && pendingKey !== "") {
                                        let found = ctrl.filteredItems.findIndex(it => it.raw === pendingKey);
                                        if (found > -1) {
                                            targetIndex = found;
                                            restoredNeighbor = true;
                                        }
                                    }

                                    // duration 0: apply instantly, no visible sweep
                                    let prevDuration = listView.highlightMoveDuration;
                                    listView.highlightMoveDuration = 0;
                                    listView.currentIndex = targetIndex;
                                    // Contain only scrolls if the target isn't already visible.
                                    // A delete/unpin removes one row locally, so this is usually a no-op.
                                    listView.positionViewAtIndex(targetIndex, restoredNeighbor ? ListView.Contain : ListView.Beginning);
                                    listView.highlightMoveDuration = prevDuration;
                                }
                            }
                        }

                        // Default Flickable wheel scrolling is too fine-grained; scroll manually
                        MouseArea {
                            anchors.fill: listView
                            acceptedButtons: Qt.NoButton
                            onWheel: wheel => {
                                let delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
                                let pixels = (delta / 120) * 150;
                                let maxY = Math.max(0, listView.contentHeight - listView.height);
                                listView.cancelFlick();
                                listView.contentY = Math.max(0, Math.min(listView.contentY - pixels, maxY));
                                wheel.accepted = true;
                            }
                        }

                        // Fade Gradient
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
                                    color: Theme.surface_container_low
                                }
                            }
                        }
                    }

                    Text {
                        id: emptyMessage
                        anchors.centerIn: listContainer
                        text: ctrl.currentTab === 1 ? "No pinned clips yet, start pinning already!" : (ctrl.allItems.length === 0 ? "Clipboard is empty :(" : "No results found :/")
                        visible: ctrl.filteredItems.length === 0
                        color: Theme.on_surface_variant
                        font {
                            family: "Google Sans Medium"
                            pixelSize: 18
                        }
                    }

                    // Footer
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

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Select a clip"
                                color: Theme.on_surface_variant
                                font {
                                    family: "Google Sans Medium"
                                    pixelSize: 15
                                }
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "[Tab] Switch • [Enter] Select • [P] Pin • [X] Delete • [/] Search • [Esc] Close"
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
                }

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
