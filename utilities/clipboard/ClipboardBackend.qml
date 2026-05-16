import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: backend

    // Configuration
    property string scriptPath: Quickshell.shellPath("scripts/cliphist-visual.sh")
    property string pinnedCachePath: "~/.local/state/quickshell/pinned_clips.json"

    // State Fields
    property var allItems: []
    property var filteredItems: []
    property var pinnedRaws: []
    property string searchText: ""
    property int currentTab: 0

    // UI Orchestration Signals
    signal openMenuRequested
    signal closeMenuRequested

    Component.onCompleted: loadPinnedProcess.running = true

    onSearchTextChanged: updateSearch()
    onCurrentTabChanged: updateSearch()

    function updateSearch() {
        let baseList = backend.currentTab === 0 ? backend.allItems : backend.allItems.filter(item => backend.pinnedRaws.includes(item.raw));

        if (backend.searchText.trim() === "") {
            backend.filteredItems = baseList.map(item => ({
                        raw: item.raw,
                        display: item.display,
                        imagePath: item.imagePath,
                        isPinned: backend.pinnedRaws.includes(item.raw)
                    }));
            return;
        }

        let query = backend.searchText.toLowerCase();
        backend.filteredItems = baseList.filter(item => {
            let str = item.display.toLowerCase();
            let i = 0, j = 0;
            while (i < str.length && j < query.length) {
                if (str[i] === query[j])
                    j++;
                i++;
            }
            return j === query.length;
        }).map(item => ({
                    raw: item.raw,
                    display: item.display,
                    imagePath: item.imagePath,
                    isPinned: backend.pinnedRaws.includes(item.raw)
                }));
    }

    function togglePin(rawString) {
        let index = backend.pinnedRaws.indexOf(rawString);
        if (index > -1) {
            backend.pinnedRaws.splice(index, 1);
        } else {
            backend.pinnedRaws.push(rawString);
        }
        backend.pinnedRaws = [...backend.pinnedRaws];

        savePinnedProcess.jsonString = JSON.stringify(backend.pinnedRaws);
        savePinnedProcess.running = true;
        updateSearch();
    }

    function selectItem(rawString) {
        copyToClipboard.selectedItem = rawString;
        copyToClipboard.running = true;
    }

    function removeItem(rawString, itemId) {
        let pinIndex = backend.pinnedRaws.indexOf(rawString);
        if (pinIndex > -1) {
            backend.pinnedRaws.splice(pinIndex, 1);
            backend.pinnedRaws = [...backend.pinnedRaws];
            savePinnedProcess.jsonString = JSON.stringify(backend.pinnedRaws);
            savePinnedProcess.running = true;
        }
        deleteEntry.targetRaw = rawString;
        deleteEntry.targetId = itemId;
        deleteEntry.running = true;
    }

    function clearUnpinnedHistory() {
        let unpinned = backend.allItems.filter(item => !backend.pinnedRaws.includes(item.raw)).map(item => item.raw);
        if (unpinned.length === 0)
            return;

        clearHistoryProcess.unpinnedList = unpinned.join('\n');
        clearHistoryProcess.running = true;
    }

    function triggerRefresh() {
        fetchHistory.running = true;
    }

    Process {
        id: savePinnedProcess
        property string jsonString: "[]"
        command: ["bash", "-c", 'mkdir -p "$(dirname ' + backend.pinnedCachePath + ')" && printf "%s" "$1" > ' + backend.pinnedCachePath, "_", jsonString]
    }

    Process {
        id: loadPinnedProcess
        command: ["bash", "-c", 'cat ' + backend.pinnedCachePath + ' 2>/dev/null || echo "[]"']
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    backend.pinnedRaws = JSON.parse(this.text.trim() || "[]");
                } catch (e) {
                    backend.pinnedRaws = [];
                }
                backend.triggerRefresh();
            }
        }
    }

    Process {
        id: fetchHistory
        command: ["bash", "-c", backend.scriptPath]
        stdout: StdioCollector {
            onStreamFinished: {
                backend.allItems = this.text.split('\n').filter(line => line.trim() !== "").map(line => {
                    let parts = line.split('\t');
                    return {
                        raw: parts[0] + '\t' + (parts[1] || ""),
                        display: parts[1] || "",
                        imagePath: parts[2] || ""
                    };
                });

                let originalLength = backend.pinnedRaws.length;

                backend.pinnedRaws = backend.pinnedRaws.filter(pinnedRaw => {
                    return backend.allItems.some(item => item.raw === pinnedRaw);
                });

                if (backend.pinnedRaws.length !== originalLength) {
                    savePinnedProcess.jsonString = JSON.stringify(backend.pinnedRaws);
                    savePinnedProcess.running = true;
                }

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
        id: clearHistoryProcess
        property string unpinnedList: ""
        command: ["bash", "-c", 'echo "$1" | while IFS= read -r line; do if [ -n "$line" ]; then printf "%s\n" "$line" | cliphist delete; id=$(printf "%s" "$line" | cut -d\'\t\' -f1); rm -f "/tmp/cliphist/${id}.*"; fi; done', "_", unpinnedList]
        onRunningChanged: {
            if (!running && unpinnedList !== "") {
                unpinnedList = "";
                fetchHistory.running = true;
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
