import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "../../theme"

PanelWindow {
    id: emojiWindow

    property string emojiListPath: "~/.cache/quickshell/emojis.json"
    property string recentsCachePath: "~/.local/state/quickshell/recent_emojis.json"

    implicitWidth: 550
    implicitHeight: 640
    color: "transparent"
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "emoji_overlay"
    exclusiveZone: -1

    anchors {
        bottom: true
    }

    margins {
        bottom: 150
    }

    property var allItems: []
    property var filteredItems: []
    property var recentItems: []
    property string currentEmojiName: gridView.currentItem ? gridView.currentItem.emojiName : ""

    property string selectionBuffer: ""

    property var categories: ["Recents", "All"]
    property string currentCategory: "Recents"

    property bool isSearchingState: false

    onCurrentCategoryChanged: {
        isSearchingState = true;
        searchDeferTimer.restart();
    }

    HyprlandFocusGrab {
        id: focusGrab
        windows: [emojiWindow]
        onCleared: closeMenu()
    }

    function getEditDistance(a, b) {
        let aLen = a.length;
        let bLen = b.length;
        if (a === b)
            return 0;
        if (aLen === 0)
            return bLen;
        if (bLen === 0)
            return aLen;

        let v0 = new Array(bLen + 1);
        let v1 = new Array(bLen + 1);

        for (let i = 0; i <= bLen; i++)
            v0[i] = i;

        for (let i = 0; i < aLen; i++) {
            v1[0] = i + 1;
            let aChar = a[i];
            for (let j = 0; j < bLen; j++) {
                let cost = (aChar === b[j]) ? 0 : 1;
                v1[j + 1] = Math.min(v1[j] + 1, v0[j + 1] + 1, v0[j] + cost);
            }
            for (let j = 0; j <= bLen; j++)
                v0[j] = v1[j];
        }
        return v0[bLen];
    }

    function saveRecentsToDisk() {
        let rawChars = emojiWindow.recentItems.map(item => item.emoji);
        saveRecentsProcess.jsonString = JSON.stringify(rawChars);
        saveRecentsProcess.running = true;
    }

    function processSelection(emojiChar, isShift) {
        let itemObj = emojiWindow.allItems.find(item => item.emoji === emojiChar);
        if (itemObj) {
            let newRecents = emojiWindow.recentItems.filter(item => item.emoji !== emojiChar);
            newRecents.unshift(itemObj);

            if (newRecents.length > 100)
                newRecents.pop();
            emojiWindow.recentItems = newRecents;

            saveRecentsToDisk();

            if (emojiWindow.currentCategory === "Recents" && searchField.text.trim() === "") {
                emojiWindow.filteredItems = emojiWindow.recentItems;
            }
        }

        if (isShift) {
            selectionBuffer += emojiChar;
        } else {
            let finalSelection = selectionBuffer + emojiChar;
            copyToClipboard.selectedEmoji = finalSelection;
            copyToClipboard.running = true;
            selectionBuffer = "";
        }
    }

    function closeMenu() {
        emojiWindow.visible = false;
        focusGrab.active = false;
        selectionBuffer = "";
    }

    Timer {
        id: searchDeferTimer
        interval: 25
        repeat: false
        onTriggered: {
            updateSearch();
            emojiWindow.isSearchingState = false;
        }
    }

    function updateSearch() {
        let queryStr = searchField.text.trim();
        let isSearching = queryStr !== "";
        let baseItems = [];

        if (isSearching) {
            baseItems = emojiWindow.allItems;
        } else {
            if (emojiWindow.currentCategory === "Recents") {
                baseItems = emojiWindow.recentItems;
            } else if (emojiWindow.currentCategory === "All") {
                baseItems = emojiWindow.allItems;
            }
        }

        if (!isSearching) {
            emojiWindow.filteredItems = baseItems;
            gridView.currentIndex = 0;
            gridView.positionViewAtBeginning();
            return;
        }

        let query = queryStr.toLowerCase();
        let queryLen = query.length;
        let filtered = [];

        for (let i = 0; i < baseItems.length; i++) {
            let item = baseItems[i];
            let maxScore = 0;
            let searchStr = item.searchString;

            if (item.display.toLowerCase() === query) {
                maxScore = 110;
            } else if (searchStr.startsWith(query)) {
                maxScore = 95;
            }

            if (maxScore < 100) {
                let tokens = item.tokens;
                for (let t = 0; t < tokens.length; t++) {
                    let token = tokens[t];
                    if (token === query) {
                        maxScore = Math.max(maxScore, 100);
                        if (maxScore === 100)
                            break;
                    } else if (token.startsWith(query)) {
                        maxScore = Math.max(maxScore, 90);
                    } else if (token.includes(query)) {
                        maxScore = Math.max(maxScore, 70);
                    } else if (queryLen >= 3) {
                        let allowedTypos = queryLen >= 6 ? 2 : 1;
                        if (Math.abs(token.length - queryLen) <= allowedTypos) {
                            let dist = getEditDistance(token, query);
                            if (dist <= allowedTypos) {
                                maxScore = Math.max(maxScore, 45 - (dist * 10));
                            }
                        }
                    }
                }
            }

            if (maxScore < 50) {
                let qIdx = 0;
                let strIdx = 0;
                while (qIdx < queryLen && strIdx < searchStr.length) {
                    if (query[qIdx] === searchStr[strIdx])
                        qIdx++;
                    strIdx++;
                }
                if (qIdx === queryLen) {
                    maxScore = Math.max(maxScore, 50);
                }
            }

            if (maxScore > 0) {
                item.score = maxScore;
                filtered.push(item);
            }
        }

        filtered.sort((a, b) => {
            if (b.score !== a.score)
                return b.score - a.score;
            return a.display.length - b.display.length;
        });

        emojiWindow.filteredItems = filtered.slice(0, 150);
        gridView.currentIndex = 0;
        gridView.positionViewAtBeginning();
    }

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
                    if (textBody === "")
                        return;

                    let parsedJson = JSON.parse(textBody);
                    let dynamicAllItems = [];

                    Object.keys(parsedJson).forEach(key => {
                        let tags = parsedJson[key] || [];
                        let rawDesc = tags.length > 0 ? tags[0] : "emoji";
                        let displayDesc = rawDesc.replace(/_/g, " ");

                        let allWords = displayDesc.split(" ").concat(tags);
                        let uniqueTokens = [];
                        for (let i = 0; i < allWords.length; i++) {
                            let w = allWords[i].toLowerCase();
                            if (uniqueTokens.indexOf(w) === -1)
                                uniqueTokens.push(w);
                        }

                        dynamicAllItems.push({
                            emoji: key,
                            display: displayDesc,
                            category: "All",
                            searchString: (displayDesc + " " + tags.join(" ")).toLowerCase(),
                            tokens: uniqueTokens,
                            score: 0
                        });
                    });

                    emojiWindow.allItems = dynamicAllItems;
                    loadRecentsProcess.running = true;
                } catch (e) {
                    console.error("JSON Error parsing main list:", e);
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
                    let textBody = this.text.trim();
                    let savedChars = textBody ? JSON.parse(textBody) : [];

                    if (Array.isArray(savedChars)) {
                        let dynamicRecents = [];
                        for (let i = 0; i < savedChars.length; i++) {
                            let match = emojiWindow.allItems.find(item => item.emoji === savedChars[i]);
                            if (match) {
                                dynamicRecents.push(match);
                            }
                        }
                        emojiWindow.recentItems = dynamicRecents;
                    }
                } catch (e) {
                    console.error("JSON Error parsing persistent recents:", e);
                }

                emojiWindow.isSearchingState = true;
                searchDeferTimer.restart();
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
            } else {
                if (emojiWindow.allItems.length === 0) {
                    if (!updateEmojisProcess.running) {
                        fetchEmojis.running = true;
                    }
                } else {
                    emojiWindow.isSearchingState = true;
                    searchDeferTimer.restart();
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
    }

    Item {
        id: delegateContainer
        anchors.fill: parent
        anchors.margins: 30

        // 1. THE SHADOW DECOUPLER FIX
        // We create a dummy invisible rectangle to cast the shadow
        // so the main UI text doesn't get converted into an FBO texture!
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

        // 2. The main UI now renders cleanly with native text!
        Rectangle {
            id: mainUi
            anchors.fill: parent
            color: Theme.surface_container
            radius: 28
            clip: true
            focus: true

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    closeMenu();
                } else if (event.key === Qt.Key_Tab) {
                    let idx = emojiWindow.categories.indexOf(emojiWindow.currentCategory);
                    let nextIdx = (idx + 1) % emojiWindow.categories.length;
                    emojiWindow.currentCategory = emojiWindow.categories[nextIdx];
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                    gridView.moveCurrentIndexDown();
                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                    gridView.moveCurrentIndexUp();
                } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                    gridView.moveCurrentIndexLeft();
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                    gridView.moveCurrentIndexRight();
                } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                    if (gridView.currentItem) {
                        let isShift = event.modifiers & Qt.ShiftModifier;
                        emojiWindow.processSelection(gridView.currentItem.emojiChar, isShift);
                    }
                } else if (event.key === Qt.Key_Slash) {
                    searchField.forceActiveFocus();
                }
                event.accepted = true;
            }

            // --- Header ---
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
                    anchors.right: parent.right
                    anchors.rightMargin: 24
                    anchors.verticalCenter: headerTitle.verticalCenter
                    width: 36
                    height: 36
                    radius: 18
                    color: clearMouseArea.containsMouse ? Theme.surface_container_highest : "transparent"

                    visible: emojiWindow.currentCategory === "Recents" && emojiWindow.recentItems.length > 0

                    Text {
                        anchors.centerIn: parent
                        text: "delete"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 26
                        font.bold: true
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
                            if (searchField.text.trim() === "") {
                                emojiWindow.filteredItems = [];
                            }
                        }
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                }
            }

            // --- Search Field ---
            TextField {
                id: searchField
                anchors.top: headerArea.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 16
                anchors.topMargin: 4
                height: 56

                leftPadding: 52
                rightPadding: searchField.text !== "" ? 48 : 16

                font.family: "Google Sans"
                font.pixelSize: 17
                color: Theme.on_surface
                selectionColor: Theme.primary_container
                selectedTextColor: Theme.on_primary_container

                placeholderText: "Search"
                placeholderTextColor: Theme.on_surface_variant

                background: Rectangle {
                    id: searchBg
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
                        anchors.left: parent.left
                        anchors.leftMargin: 20
                        anchors.verticalCenter: parent.verticalCenter
                        text: "search"
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 24
                        color: searchField.activeFocus ? Theme.primary : Theme.on_surface_variant
                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }
                    }
                }

                onTextChanged: {
                    emojiWindow.isSearchingState = true;
                    searchDeferTimer.restart();
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Down) {
                        gridView.moveCurrentIndexDown();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up) {
                        gridView.moveCurrentIndexUp();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Left) {
                        gridView.moveCurrentIndexLeft();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Right) {
                        gridView.moveCurrentIndexRight();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Tab) {
                        let idx = emojiWindow.categories.indexOf(emojiWindow.currentCategory);
                        let nextIdx = (idx + 1) % emojiWindow.categories.length;
                        emojiWindow.currentCategory = emojiWindow.categories[nextIdx];
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                        if (gridView.currentItem) {
                            let isShift = event.modifiers & Qt.ShiftModifier;
                            emojiWindow.processSelection(gridView.currentItem.emojiChar, isShift);
                        }
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Escape) {
                        mainUi.forceActiveFocus();
                        event.accepted = true;
                    }
                }
            }

            // --- Category Tabs ---
            Item {
                id: categoryTabsContainer
                anchors.top: searchField.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                height: 48
                anchors.topMargin: 8

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: wheel => {
                        let delta = wheel.angleDelta.x !== 0 ? wheel.angleDelta.x : wheel.angleDelta.y;
                        let currentTarget = smoothScrollAnim.running ? smoothScrollAnim.to : categoryList.contentX;
                        let maxScroll = Math.max(0, categoryList.contentWidth - categoryList.width);
                        let newX = Math.max(0, Math.min(currentTarget - delta, maxScroll));

                        smoothScrollAnim.to = newX;
                        smoothScrollAnim.start();
                    }
                }

                ListView {
                    id: categoryList
                    anchors.fill: parent
                    orientation: ListView.Horizontal
                    spacing: 8
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    model: emojiWindow.categories

                    // We removed the FBO mask here to preserve text rendering!

                    onMovementStarted: smoothScrollAnim.stop()

                    NumberAnimation {
                        id: smoothScrollAnim
                        target: categoryList
                        property: "contentX"
                        duration: 350
                        easing.type: Easing.OutQuart
                    }

                    delegate: Rectangle {
                        height: 36
                        width: tabText.width + 32
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 18

                        property bool isSelected: modelData === emojiWindow.currentCategory

                        color: isSelected ? Theme.primary : Theme.surface_container_high
                        border.width: isSelected ? 0 : 1
                        border.color: Theme.outline_variant

                        Text {
                            id: tabText
                            anchors.centerIn: parent
                            text: modelData
                            color: isSelected ? Theme.on_primary : Theme.on_surface_variant
                            font.family: "Google Sans"
                            font.pixelSize: 14
                            font.weight: isSelected ? Font.DemiBold : Font.Medium
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (searchField.text !== "") {
                                    searchField.text = "";
                                }
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

                // 3. THE SCROLL-FADE FIX
                // A hardware-free overlay gradient that simulates a mask!
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 32
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
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

            // --- Grid Container ---
            Item {
                id: listContainer
                anchors.top: categoryTabsContainer.bottom
                anchors.bottom: footer.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 8

                GridView {
                    id: gridView
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter

                    width: Math.floor((parent.width - 44) / cellWidth) * cellWidth
                    topMargin: 12
                    bottomMargin: 24

                    cellWidth: 60
                    cellHeight: 60

                    model: emojiWindow.filteredItems
                    clip: true // Changed from false to true since we removed the mask
                    highlightMoveDuration: 120
                    highlightFollowsCurrentItem: true

                    // We removed the FBO mask here to preserve text rendering!

                    opacity: emojiWindow.isSearchingState ? 0.4 : 1.0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutQuad
                        }
                    }

                    delegate: EmojiDelegate {}
                }

                // 3. THE SCROLL-FADE FIX (Grid version)
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
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

            // --- Footer ---
            Item {
                id: footer
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 64

                Rectangle {
                    anchors.fill: parent
                    color: Theme.surface_container_low
                    radius: 28

                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 25
                        color: Theme.surface_container_low
                    }
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
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
                            font.family: "Noto Color Emoji"
                            font.pixelSize: 18
                            anchors.verticalCenter: parent.verticalCenter
                            antialiasing: true
                        }

                        Text {
                            text: emojiWindow.selectionBuffer !== "" ? ("+ " + (emojiWindow.currentEmojiName || "")) : (emojiWindow.currentEmojiName || "Select an emoji")
                            color: Theme.on_surface_variant
                            font.family: "Google Sans Medium"
                            font.pixelSize: 15
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "[Tab] Switch • [Enter] Select • [Shift] Multi • [Esc] Close"
                        color: Theme.on_surface_variant
                        opacity: 0.6
                        font.family: "Google Sans"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                    }
                }
            }

            Text {
                id: emptyMessage
                anchors.centerIn: listContainer
                text: emojiWindow.currentCategory === "Recents" && emojiWindow.recentItems.length === 0 ? "No recent emojis" : "No emojis found 🥲"
                visible: emojiWindow.filteredItems.length === 0 && !emojiWindow.isSearchingState
                color: Theme.on_surface_variant
                font.family: "Google Sans Medium"
                font.pixelSize: 18
            }

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                radius: 28
                border.width: 1
                border.color: Theme.outline_variant
                z: 99
            }
        }
    }
}
