import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import "../theme"

PanelWindow {
    id: clipboardWindow

    implicitWidth: 600
    implicitHeight: 750
    color: "transparent"
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "clipboard_overlay"
    exclusiveZone: -1

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
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                clipboardWindow.allItems = this.text.split('\n').filter(line => line.trim() !== "").map(line => {
                    let tabIndex = line.indexOf('\t');
                    if (tabIndex === -1)
                        return {
                            raw: line,
                            display: line
                        };
                    return {
                        raw: line,
                        display: line.substring(tabIndex + 1)
                    };
                });
                updateSearch();
            }
        }
    }

    Process {
        id: copyToClipboard
        property string selectedItem: ""
        command: ["sh", "-c", `echo "${selectedItem}" | cliphist decode | wl-copy`]
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
        command: ["sh", "-c", `echo "${targetRaw}" | cliphist delete`]
        onRunningChanged: {
            if (!running && targetRaw !== "") {
                targetRaw = "";
                fetchHistory.running = true;
            }
        }
    }

    Process {
        id: clearHistory
        command: ["cliphist", "wipe"]
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
            radius: 20
            border.width: 1
            border.color: Theme.outline_variant
            clip: true
            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape || event.key === Qt.Key_X || event.key === Qt.Key_H)
                    closeMenu();
                else if (event.key === Qt.Key_Down || event.key === Qt.Key_J)
                    listView.incrementCurrentIndex();
                else if (event.key === Qt.Key_Up || event.key === Qt.Key_K)
                    listView.decrementCurrentIndex();
                else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return || event.key === Qt.Key_L) {
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
                        pixelSize: 22
                        bold: true
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
                            pixelSize: 14
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

            // Search
            Item {
                id: searchArea
                width: parent.width
                height: 64
                anchors.top: headerArea.bottom
                TextField {
                    id: searchField
                    anchors.fill: parent
                    anchors.margins: 12
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    leftPadding: 20
                    rightPadding: 20
                    font.family: "Google Sans"
                    font.pixelSize: 16
                    color: Theme.on_surface
                    placeholderText: "Search..."
                    placeholderTextColor: Theme.outline
                    background: Rectangle {
                        color: searchField.activeFocus ? Theme.surface_variant : Theme.surface_container_low
                        radius: 20
                        border.width: 1
                        border.color: searchField.activeFocus ? Theme.primary : "transparent"
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
                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.surface_variant
                    anchors.bottom: parent.bottom
                }
            }

            // List
            ListView {
                id: listView
                anchors.top: searchArea.bottom
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                topMargin: 12
                bottomMargin: 12

                model: clipboardWindow.filteredItems
                spacing: 8
                clip: true
                highlightMoveDuration: 80
                highlightFollowsCurrentItem: true

                delegate: Item {
                    id: delegateRoot
                    width: listView.width
                    height: 88

                    property bool isSelected: ListView.isCurrentItem
                    property bool isHovered: itemMouseArea.containsMouse

                    // Fix: Moved functions up to the delegate root so listView.currentItem.select() works
                    function select() {
                        copyToClipboard.selectedItem = modelData.raw;
                        copyToClipboard.running = true;
                    }

                    function remove() {
                        deleteEntry.targetRaw = modelData.raw;
                        deleteEntry.running = true;
                    }

                    Rectangle {
                        id: itemBox
                        anchors.centerIn: parent
                        width: parent.width - 32
                        height: parent.height
                        radius: 16

                        scale: itemMouseArea.pressed ? 0.97 : (delegateRoot.isSelected || delegateRoot.isHovered ? 1.015 : 1.0)
                        Behavior on scale {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutBack
                            }
                        }

                        color: delegateRoot.isSelected ? Theme.secondary_container : (delegateRoot.isHovered ? Qt.lighter(Theme.surface_container_low, 1.08) : Theme.surface_container_low)
                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }

                        Rectangle {
                            id: activeIndicator
                            width: 4
                            height: delegateRoot.isSelected ? parent.height * 0.45 : 0
                            opacity: delegateRoot.isSelected ? 1.0 : 0.0
                            anchors.left: parent.left
                            anchors.leftMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            radius: 2
                            color: Theme.primary
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.right: deleteSeparator.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 24
                            anchors.rightMargin: 16
                            text: modelData.display
                            textFormat: Text.PlainText
                            color: delegateRoot.isSelected ? Theme.on_secondary_container : Theme.on_surface
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            font {
                                family: "Google Sans Medium"
                                pixelSize: 16
                            }
                        }

                        // --- Separator ---
                        Rectangle {
                            id: deleteSeparator
                            width: 1
                            height: 40
                            anchors.right: deleteIconBtn.left
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            color: delegateRoot.isSelected ? Theme.on_secondary_container : Theme.outline_variant
                            opacity: delegateRoot.isSelected ? 0.5 : 0.3

                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }
                        }

                        // --- Delete Button ---
                        Rectangle {
                            id: deleteIconBtn
                            z: 1
                            width: 44
                            height: 44
                            radius: 22
                            anchors.right: parent.right
                            anchors.rightMargin: 16
                            anchors.verticalCenter: parent.verticalCenter

                            color: deleteMouseArea.containsMouse ? Theme.critical : "transparent"

                            scale: deleteMouseArea.pressed ? 0.85 : (deleteMouseArea.containsMouse ? 1.1 : 1.0)
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutBack
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "delete"
                                font.family: "Material Symbols Rounded"
                                font.pixelSize: 22
                                font.bold: true
                                color: deleteMouseArea.containsMouse ? Theme.on_critical : Theme.critical
                            }

                            MouseArea {
                                id: deleteMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                preventStealing: true
                                onClicked: mouse => {
                                    mouse.accepted = true;
                                    delegateRoot.remove(); // Fix: updated target
                                }
                            }
                        }

                        MouseArea {
                            id: itemMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: listView.currentIndex = index
                            onClicked: delegateRoot.select() // Fix: updated target
                        }
                    }
                }
            }

            Text {
                id: emptyMessage
                anchors.centerIn: listView
                text: clipboardWindow.allItems.length === 0 ? "Clipboard is empty :)" : "No results found :("
                visible: clipboardWindow.filteredItems.length === 0
                color: Theme.on_surface_variant
                font.family: "Google Sans Medium"
                font.pixelSize: 18
            }
        }
    }
}
