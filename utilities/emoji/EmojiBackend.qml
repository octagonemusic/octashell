import QtQuick
import Quickshell
import Quickshell.Io
import "EmojiLogic.js" as Logic

Item {
    id: backend

    // Configuration
    property string emojiListPath: "~/.cache/quickshell/emojis.json"
    property string recentsCachePath: "~/.local/state/quickshell/recent_emojis.json"

    // Data State
    property var allItems: []
    property var filteredItems: []
    property var recentItems: []
    property var pendingRecents: []
    property string selectionBuffer: ""

    // UI-Facing State
    property var categories: ["All", "Recents"]
    property string currentCategory: "Recents"
    property bool isSearchingState: false
    property string currentEmojiName: ""
    property string searchText: ""

    // Signals to notify UI of state disruptions
    signal openMenuRequested
    signal closeMenuRequested

    onCurrentCategoryChanged: triggerSearch()
    onSearchTextChanged: triggerSearch()

    function triggerSearch() {
        backend.isSearchingState = true;
        performSearch();
    }

    function performSearch() {
        let queryStr = backend.searchText.trim();
        let isSearching = queryStr !== "";
        let baseItems = (isSearching || backend.currentCategory === "All") ? backend.allItems : backend.recentItems;

        if (!isSearching) {
            backend.filteredItems = baseItems;
        } else {
            backend.filteredItems = Logic.filterEmojis(baseItems, queryStr);
        }
        backend.isSearchingState = false;
    }

    function saveRecentsToDisk() {
        let rawChars = backend.recentItems.map(item => item.emoji);
        saveRecentsProcess.jsonString = JSON.stringify(rawChars);
        saveRecentsProcess.running = true;
    }

    function processSelection(emojiChar, isShift) {
        if (backend.pendingRecents.length > 100) {
            backend.pendingRecents.shift();
        }

        backend.pendingRecents.push(emojiChar);

        if (isShift) {
            selectionBuffer += emojiChar;
        } else {
            closeMenuRequested();
            copyToClipboard.selectedEmoji = selectionBuffer + emojiChar;
            copyToClipboard.running = true;
            selectionBuffer = "";
        }
    }

    function commitRecents() {
        if (backend.pendingRecents.length === 0)
            return;

        let updatedList = backend.recentItems;
        for (let i = 0; i < backend.pendingRecents.length; i++) {
            updatedList = Logic.updateRecents(backend.pendingRecents[i], backend.allItems, updatedList);
        }

        backend.recentItems = updatedList;
        backend.saveRecentsToDisk();
        backend.pendingRecents = []; // Clear the buffer

        if (backend.currentCategory === "Recents" && backend.searchText.trim() === "") {
            backend.filteredItems = backend.recentItems;
        }
    }

    function clearRecents() {
        backend.recentItems = [];
        backend.saveRecentsToDisk();
        if (backend.searchText.trim() === "") {
            backend.filteredItems = [];
        }
    }

    function cycleCategory() {
        let idx = backend.categories.indexOf(backend.currentCategory);
        backend.currentCategory = backend.categories[(idx + 1) % backend.categories.length];
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
        command: ["bash", "-c", "cat " + backend.emojiListPath + " 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let textBody = this.text.trim();
                    if (!textBody)
                        return;
                    backend.allItems = Logic.parseEmojiJson(textBody);
                    loadRecentsProcess.running = true;
                } catch (e) {
                    console.error("Failed to parse emoji list:", e);
                }
            }
        }
    }

    Process {
        id: loadRecentsProcess
        command: ["bash", "-c", 'cat ' + backend.recentsCachePath + ' 2>/dev/null || echo "[]"']
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let savedChars = JSON.parse(this.text.trim() || "[]");
                    if (Array.isArray(savedChars)) {
                        backend.recentItems = savedChars.map(char => backend.allItems.find(item => item.emoji === char)).filter(Boolean);
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
        command: ["bash", "-c", 'mkdir -p "$(dirname ' + backend.recentsCachePath + ')" && printf "%s" "$1" > ' + backend.recentsCachePath, "_", jsonString]
    }

    Process {
        id: copyToClipboard
        property string selectedEmoji: ""
        command: ["bash", "-c", 'printf "%s" "$1" | wl-copy', "_", selectedEmoji]
        onRunningChanged: {
            if (!running && selectedEmoji !== "") {
                selectedEmoji = "";
            }
        }
    }

    IpcHandler {
        target: "emojiMenu"
        function toggle() {
            backend.openMenuRequested();
        }
    }
}
