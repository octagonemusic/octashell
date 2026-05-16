import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "../../theme"
import "EmojiLogic.js" as Logic

PanelWindow {
    id: emojiWindow

    // Configuration
    property string emojiListPath: "~/.cache/quickshell/emojis.json"
    property string recentsCachePath: "~/.local/state/quickshell/recent_emojis.json"

    // Geometry
    implicitWidth: 550
    implicitHeight: 640
    color: "transparent"
    visible: false

    // Window Management
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "emoji_overlay"
    exclusiveZone: -1
    anchors.bottom: true
    margins.bottom: 150

    // Data State
    property var allItems: []
    property var filteredItems: []
    property var recentItems: []
    property string selectionBuffer: ""

    // UI State
    property var categories: ["All", "Recents"]
    property string currentCategory: "Recents"
    property bool isSearchingState: false
    property string currentEmojiName: gridView.currentItem ? gridView.currentItem.emojiName : ""

    onCurrentCategoryChanged: triggerSearch()

    HyprlandFocusGrab {
        id: focusGrab
        windows: [emojiWindow]
        onCleared: closeMenu()
    }

    Timer {
        id: searchDeferTimer
        interval: 180
        repeat: false
        onTriggered: performSearch()
    }

    // Core Methods
    function triggerSearch() {
        emojiWindow.isSearchingState = true;
        searchDeferTimer.restart();
    }

    function performSearch() {
        let queryStr = searchField.text.trim();
        let isSearching = queryStr !== "";
        let baseItems = (isSearching || emojiWindow.currentCategory === "All") ? emojiWindow.allItems : emojiWindow.recentItems;

        if (!isSearching) {
            emojiWindow.filteredItems = baseItems;
        } else {
            emojiWindow.filteredItems = Logic.filterEmojis(baseItems, queryStr);
        }

        gridView.currentIndex = 0;
        gridView.positionViewAtBeginning();
        emojiWindow.isSearchingState = false;
    }

    function saveRecentsToDisk() {
        let rawChars = emojiWindow.recentItems.map(item => item.emoji);
        saveRecentsProcess.jsonString = JSON.stringify(rawChars);
        saveRecentsProcess.running = true;
    }

    function processSelection(emojiChar, isShift) {
        emojiWindow.recentItems = Logic.updateRecents(emojiChar, emojiWindow.allItems, emojiWindow.recentItems);
        saveRecentsToDisk();

        if (emojiWindow.currentCategory === "Recents" && searchField.text.trim() === "") {
            emojiWindow.filteredItems = emojiWindow.recentItems;
        }

        if (isShift) {
            selectionBuffer += emojiChar;
        } else {
            copyToClipboard.selectedEmoji = selectionBuffer + emojiChar;
            copyToClipboard.running = true;
            selectionBuffer = "";
        }
    }

    function cycleCategory() {
        let idx = emojiWindow.categories.indexOf(emojiWindow.currentCategory);
        emojiWindow.currentCategory = emojiWindow.categories[(idx + 1) % emojiWindow.categories.length];
    }

    function closeMenu() {
        emojiWindow.visible = false;
        focusGrab.active = false;
        selectionBuffer = "";
    }

    // Processes
    Process {
        id: updateEmojisProcess
        command: ["bash", Quickshell.shellPath("scripts/download_emojis.sh")]
        Component.onCompleted: running = true
        onRunningChanged: if (!running)
            fetchEmojis.running = true
    }

    Process {
        id: fetchEmojis
        command: ["bash", "-c", "cat " + emojiWindow.emojiListPath + " 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let textBody = this.text.trim();
                    if (!textBody)
                        return;

                    emojiWindow.allItems = Logic.parseEmojiJson(textBody);
                    loadRecentsProcess.running = true;
                } catch (e) {
                    console.error("Failed to parse emoji list:", e);
                }
            }
        }
    }

    Process {
        id: loadRecentsProcess
        command: ["bash", "-c", 'cat ' + emojiWindow.recentsCachePath + ' 2>/dev/null || echo "[]"']
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let savedChars = JSON.parse(this.text.trim() || "[]");
                    if (Array.isArray(savedChars)) {
                        emojiWindow.recentItems = savedChars.map(char => emojiWindow.allItems.find(item => item.emoji === char)).filter(Boolean);
                    }
                } catch (e) {
                    console.error("Failed to parse recents:", e);
                }
                triggerSearch();
            }
        }
    }

    Process {
        id: saveRecentsProcess
        property string jsonString: "[]"
        command: ["bash", "-c", 'mkdir -p "$(dirname ' + emojiWindow.recentsCachePath + ')" && printf "%s" "$1" > ' + emojiWindow.recentsCachePath, "_", jsonString]
    }

    Process {
        id: copyToClipboard
        property string selectedEmoji: ""
        command: ["bash", "-c", 'printf "%s" "$1" | wl-copy', "_", selectedEmoji]
        onRunningChanged: {
            if (!running && selectedEmoji !== "") {
                closeMenu();
                selectedEmoji = "";
            }
        }
    }

    IpcHandler {
        target: "emojiMenu"
        function toggle() {
            if (emojiWindow.visible) {
                closeMenu();
                return;
            }

            if (emojiWindow.allItems.length === 0 && !updateEmojisProcess.running) {
                fetchEmojis.running = true;
            } else {
                triggerSearch();
            }

            searchField.text = "";
            selectionBuffer = "";
            emojiWindow.currentCategory = "Recents";
            smoothScrollAnim.stop();
            categoryList.contentX = 0;

            emojiWindow.visible = true;
            focusGrab.active = true;
            mainUi.forceActiveFocus();
        }
    }

    // UI Structure
    Item {
        id: delegateContainer
        anchors.fill: parent
        anchors.margins: 30

        // Shadow Decoupler
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
            id: mainUi
            anchors.fill: parent
            color: Theme.surface_container
            radius: 28
            clip: true
            focus: true

            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_Escape:
                    closeMenu();
                    event.accepted = true;
                    break;
                case Qt.Key_Tab:
                    cycleCategory();
                    event.accepted = true;
                    break;
                case Qt.Key_Down:
                case Qt.Key_J:
                    gridView.moveCurrentIndexDown();
                    event.accepted = true;
                    break;
                case Qt.Key_Up:
                case Qt.Key_K:
                    gridView.moveCurrentIndexUp();
                    event.accepted = true;
                    break;
                case Qt.Key_Left:
                case Qt.Key_H:
                    gridView.moveCurrentIndexLeft();
                    event.accepted = true;
                    break;
                case Qt.Key_Right:
                case Qt.Key_L:
                    gridView.moveCurrentIndexRight();
                    event.accepted = true;
                    break;
                case Qt.Key_Enter:
                case Qt.Key_Return:
                    if (gridView.currentItem) {
                        processSelection(gridView.currentItem.emojiChar, event.modifiers & Qt.ShiftModifier);
                    }
                    event.accepted = true;
                    break;
                case Qt.Key_Slash:
                    searchField.forceActiveFocus();
                    event.accepted = true;
                    break;
                }
            }

            // Header
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
                    visible: emojiWindow.currentCategory === "Recents" && emojiWindow.recentItems.length > 0

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
                        onClicked: {
                            emojiWindow.recentItems = [];
                            emojiWindow.saveRecentsToDisk();
                            if (searchField.text.trim() === "")
                                emojiWindow.filteredItems = [];
                        }
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
                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }
                    }
                }

                onTextChanged: triggerSearch()

                Keys.onPressed: event => {
                    switch (event.key) {
                    case Qt.Key_Down:
                        gridView.moveCurrentIndexDown();
                        event.accepted = true;
                        break;
                    case Qt.Key_Up:
                        gridView.moveCurrentIndexUp();
                        event.accepted = true;
                        break;
                    case Qt.Key_Left:
                        gridView.moveCurrentIndexLeft();
                        event.accepted = true;
                        break;
                    case Qt.Key_Right:
                        gridView.moveCurrentIndexRight();
                        event.accepted = true;
                        break;
                    case Qt.Key_Tab:
                        cycleCategory();
                        event.accepted = true;
                        break;
                    case Qt.Key_Enter:
                    case Qt.Key_Return:
                        if (gridView.currentItem) {
                            processSelection(gridView.currentItem.emojiChar, event.modifiers & Qt.ShiftModifier);
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
                    anchors.fill: parent
                    orientation: ListView.Horizontal
                    spacing: 12
                    boundsBehavior: Flickable.StopAtBounds
                    model: emojiWindow.categories
                    onMovementStarted: smoothScrollAnim.stop()

                    NumberAnimation {
                        id: smoothScrollAnim
                        target: categoryList
                        property: "contentX"
                        duration: 350
                        easing.type: Easing.OutQuart
                    }

                    delegate: Rectangle {
                        property bool isSelected: modelData === emojiWindow.currentCategory
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
                                emojiWindow.currentCategory = modelData;
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

            // Grid Container
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
                    model: emojiWindow.filteredItems
                    clip: true
                    highlightMoveDuration: 120
                    highlightFollowsCurrentItem: true
                    opacity: emojiWindow.isSearchingState ? 0.4 : 1.0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutQuad
                        }
                    }
                    delegate: EmojiDelegate {}
                }

                // Mask Simulation
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

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8

                        Text {
                            text: emojiWindow.selectionBuffer
                            visible: emojiWindow.selectionBuffer !== ""
                            anchors.verticalCenter: parent.verticalCenter
                            font {
                                family: "Noto Color Emoji"
                                pixelSize: 18
                            }
                            antialiasing: true
                        }

                        Text {
                            text: emojiWindow.selectionBuffer !== "" ? ("+ " + (emojiWindow.currentEmojiName || "")) : (emojiWindow.currentEmojiName || "Select an emoji")
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
                text: emojiWindow.currentCategory === "Recents" && emojiWindow.recentItems.length === 0 ? "No recent emojis" : "No emojis found 🥲"
                visible: emojiWindow.filteredItems.length === 0 && !emojiWindow.isSearchingState
                color: Theme.on_surface_variant
                font {
                    family: "Google Sans Medium"
                    pixelSize: 18
                }
            }

            // Outline
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
