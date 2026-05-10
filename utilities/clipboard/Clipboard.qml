import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import "../../theme"

PanelWindow {
    id: clipboardWindow

    // Configuration
    property string scriptPath: "$HOME/.config/quickshell/scripts/cliphist-visual.sh"

    implicitWidth: 600
    implicitHeight: 750
    color: "transparent"
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "clipboard_overlay"
    exclusiveZone: -1

    anchors {
        bottom: true
    }

    margins {
        bottom: 100
    }

    property var allItems: []
    property var filteredItems: []

    HyprlandFocusGrab {
        id: focusGrab
        windows: [clipboardWindow]
        onCleared: closeMenu()
    }

    function closeMenu() {
        clipboardWindow.visible = false;
        focusGrab.active = false;
    }

    function updateSearch() {
        if (searchField.text.trim() === "") {
            clipboardWindow.filteredItems = clipboardWindow.allItems;
            listView.currentIndex = 0;
            return;
        }
        let query = searchField.text.toLowerCase();
        clipboardWindow.filteredItems = clipboardWindow.allItems.filter(item => {
            let str = item.display.toLowerCase();
            let i = 0, j = 0;
            while (i < str.length && j < query.length) {
                if (str[i] === query[j])
                    j++;
                i++;
            }
            return j === query.length;
        });
        listView.currentIndex = 0;
    }

    Process {
        id: fetchHistory
        command: ["bash", "-c", clipboardWindow.scriptPath]
        stdout: StdioCollector {
            onStreamFinished: {
                clipboardWindow.allItems = this.text.split('\n').filter(line => line.trim() !== "").map(line => {
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
                updateSearch();
            }
        }
    }

    Process {
        id: copyToClipboard
        property string selectedItem: ""
        command: ["bash", "-c", 'printf "%s" "$1" | cliphist decode | wl-copy', "_", selectedItem]
        onRunningChanged: {
            if (!running && copyToClipboard.selectedItem !== "") {
                closeMenu();
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
                clipboardWindow.allItems = [];
                updateSearch();
            }
        }
    }

    IpcHandler {
        target: "clipMenu"
        function toggle() {
            if (clipboardWindow.visible) {
                closeMenu();
            } else {
                fetchHistory.running = true;
                searchField.text = "";
                clipboardWindow.visible = true;
                focusGrab.active = true;
                mainUi.forceActiveFocus();
            }
        }
    }

    Item {
        id: delegateContainer
        anchors.fill: parent
        anchors.margins: 30

        DropShadow {
            anchors.fill: mainUi
            source: mainUi
            radius: 24
            samples: 32
            color: "#80000000"
            verticalOffset: 8
        }

        Rectangle {
            id: mainUi
            anchors.fill: parent
            color: Theme.surface_container
            radius: 28
            border.width: 1
            border.color: Theme.outline_variant
            clip: true
            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_H) {
                    closeMenu();
                } else if (event.key === Qt.Key_X) {
                    if (listView.currentItem) {
                        listView.currentItem.remove();
                    }
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                    listView.incrementCurrentIndex();
                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                    listView.decrementCurrentIndex();
                } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return || event.key === Qt.Key_L) {
                    if (listView.currentItem)
                        listView.currentItem.select();
                } else if (event.key === Qt.Key_Slash) {
                    searchField.forceActiveFocus();
                    event.accepted = true;
                }
                event.accepted = true;
            }

            // Header
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
                    Behavior on scale {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutBack
                        }
                    }
                    color: clearMouseArea.containsMouse ? Theme.critical : "transparent"
                    border.width: 1
                    border.color: clearMouseArea.containsMouse ? Theme.critical : Theme.outline
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
                        onClicked: clearHistory.running = true
                    }
                }
            }

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
                        radius: 28

                        border.width: searchField.activeFocus ? 2 : 0
                        border.color: Theme.outline_variant

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
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 22
                            color: searchField.activeFocus ? Theme.primary : Theme.on_surface_variant
                        }
                    }

                    onTextChanged: updateSearch()

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Down) {
                            listView.incrementCurrentIndex();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            listView.decrementCurrentIndex();
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

            Item {
                id: listContainer
                anchors.top: searchArea.bottom
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: LinearGradient {
                        width: listContainer.width
                        height: listContainer.height
                        gradient: Gradient {
                            GradientStop {
                                position: 0.0
                                color: "black"
                            }
                            GradientStop {
                                position: 0.85
                                color: "black"
                            }
                            GradientStop {
                                position: 1.0
                                color: "transparent"
                            }
                        }
                    }
                }

                ListView {
                    id: listView
                    anchors.fill: parent
                    topMargin: 12
                    bottomMargin: 24

                    model: clipboardWindow.filteredItems
                    spacing: 8
                    clip: false
                    highlightMoveDuration: 80
                    highlightFollowsCurrentItem: true

                    delegate: ClipboardDelegate {}
                }
            }

            Text {
                id: emptyMessage
                anchors.centerIn: listContainer
                text: clipboardWindow.allItems.length === 0 ? "Clipboard is empty :(" : "No results found :/"
                visible: clipboardWindow.filteredItems.length === 0
                color: Theme.on_surface_variant
                font.family: "Google Sans Medium"
                font.pixelSize: 18
            }
        }
    }
}
