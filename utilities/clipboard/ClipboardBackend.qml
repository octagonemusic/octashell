import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: backend

    // Configuration
    property string scriptPath: Quickshell.shellPath("scripts/cliphist-visual.sh")

    // State Fields
    property var allItems: []
    property var filteredItems: []
    property string searchText: ""

    // UI Orchestration Signals
    signal openMenuRequested
    signal closeMenuRequested

    onSearchTextChanged: updateSearch()

    function updateSearch() {
        if (backend.searchText.trim() === "") {
            backend.filteredItems = backend.allItems;
            return;
        }
        let query = backend.searchText.toLowerCase();
        backend.filteredItems = backend.allItems.filter(item => {
            let str = item.display.toLowerCase();
            let i = 0, j = 0;
            while (i < str.length && j < query.length) {
                if (str[i] === query[j])
                    j++;
                i++;
            }
            return j === query.length;
        });
    }

    function selectItem(rawString) {
        copyToClipboard.selectedItem = rawString;
        copyToClipboard.running = true;
    }

    function removeItem(rawString, itemId) {
        deleteEntry.targetRaw = rawString;
        deleteEntry.targetId = itemId;
        deleteEntry.running = true;
    }

    function clearAllHistory() {
        clearHistory.running = true;
    }

    function triggerRefresh() {
        fetchHistory.running = true;
    }

    // Processes
    Process {
        id: fetchHistory
        command: ["bash", "-c", backend.scriptPath]
        stdout: StdioCollector {
            onStreamFinished: {
                backend.allItems = this.text.split('\n').filter(line => line.trim() !== "").map(line => {
                    let parts = line.split('\t');
                    let id = parts[0];
                    let display = parts[1] || "";
                    let imagePath = parts[2] || "";

                    return {
                        raw: id + '\t' + display,
                        display: display,
                        imagePath: imagePath
                    };
                });
                backend.updateSearch();
            }
        }
    }

    Process {
        id: copyToClipboard
        property string selectedItem: ""
        command: ["bash", "-c", 'printf "%s" "$1" | cliphist decode | wl-copy', "_", selectedItem]
        onRunningChanged: {
            if (!running && copyToClipboard.selectedItem !== "") {
                backend.closeMenuRequested();
                copyToClipboard.selectedItem = "";
            }
        }
    }

    Process {
        id: deleteEntry
        property string targetRaw: ""
        property string targetId: ""
        command: ["bash", "-c", 'printf "%s" "$1" | cliphist delete && rm -f /tmp/cliphist/"$2".*', "_", targetRaw, targetId]
        onRunningChanged: {
            if (!running && targetRaw !== "") {
                targetRaw = "";
                targetId = "";
                fetchHistory.running = true;
            }
        }
    }

    Process {
        id: clearHistory
        command: ["sh", "-c", "cliphist wipe && rm -rf /tmp/cliphist/*"]
        onRunningChanged: {
            if (!running) {
                backend.allItems = [];
                backend.updateSearch();
            }
        }
    }

    IpcHandler {
        target: "clipMenu"
        function toggle() {
            backend.openMenuRequested();
        }
    }
}
