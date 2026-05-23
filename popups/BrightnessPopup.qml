import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Effects
import "../theme"

Variants {
    id: root
    model: Quickshell.screens

    delegate: PanelWindow {
        id: brightnessOsdPopup

        required property var modelData
        screen: modelData

        implicitWidth: 380
        implicitHeight: 136

        color: "transparent"
        visible: showOsd

        anchors {
            bottom: true
        }

        margins {
            bottom: 70
        }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "brightness_osd"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        property real brightnessLevel: 0.0

        Process {
            command: ["sh", "-c", "udevadm monitor --subsystem-match=backlight --udev"]
            running: true
            stdout: SplitParser {
                onRead: updateBrightness.running = true
            }
        }

        Process {
            id: updateBrightness
            command: ["sh", "-c", "brightnessctl -m"]
            running: true
            stdout: StdioCollector {
                onStreamFinished: {
                    let val = parseInt(this.text.split(",")[3].replace("%", ""));
                    if (!isNaN(val)) {
                        brightnessOsdPopup.brightnessLevel = val / 100.0;
                    }
                }
            }
        }

        onBrightnessLevelChanged: {
            triggerOsd();
        }

        property bool isInitialized: false
        property bool showOsd: false

        Timer {
            id: initTimer
            interval: 1000
            running: true

            onTriggered: {
                brightnessOsdPopup.isInitialized = true;
            }
        }

        Timer {
            id: hideTimer
            interval: 2000

            onTriggered: {
                brightnessOsdPopup.showOsd = false;
            }
        }

        function triggerOsd() {
            if (!isInitialized)
                return;

            showOsd = true;
            hideTimer.restart();
        }

        Item {
            anchors.fill: parent

            Rectangle {
                id: pill

                width: 250
                height: 78
                anchors.centerIn: parent

                radius: height / 2

                color: Theme.surface_container

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowBlur: 1.0
                    shadowColor: "#40000000"
                    shadowVerticalOffset: 6
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 22
                    anchors.rightMargin: 24
                    spacing: 16

                    Text {
                        id: brightnessIcon
                        anchors.verticalCenter: parent.verticalCenter

                        color: Theme.on_surface

                        font {
                            family: "Material Symbols Rounded"
                            pixelSize: 28
                        }

                        text: {
                            if (brightnessOsdPopup.brightnessLevel >= 0.7)
                                return "brightness_high";
                            if (brightnessOsdPopup.brightnessLevel >= 0.3)
                                return "brightness_medium";

                            return "brightness_low";
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - brightnessIcon.width - parent.spacing - 6
                        spacing: 8

                        Item {
                            width: parent.width
                            height: brightnessLabel.implicitHeight

                            Text {
                                text: "Brightness"
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.on_surface

                                font {
                                    family: "Google Sans Medium"
                                    pixelSize: 16
                                }
                            }

                            Text {
                                id: brightnessLabel
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.on_surface

                                font {
                                    family: "Google Sans Medium"
                                    pixelSize: 16
                                }

                                text: Math.round(brightnessOsdPopup.brightnessLevel * 100)
                            }
                        }

                        Item {
                            width: parent.width
                            height: 6

                            readonly property real visualBrightness: Math.min(Math.max(brightnessOsdPopup.brightnessLevel, 0.0), 1.0)
                            readonly property int gap: 4

                            Rectangle {
                                id: activeTrack
                                x: 0
                                y: 0
                                height: parent.height

                                width: (parent.width - 4) * parent.visualBrightness
                                radius: height / 2

                                color: Theme.primary

                                Behavior on width {
                                    SpringAnimation {
                                        spring: 11.0
                                        damping: 0.3
                                        mass: 1.0
                                    }
                                }
                            }

                            Item {
                                id: inactiveTrackContainer
                                x: activeTrack.width + parent.gap
                                y: 0
                                height: parent.height

                                width: Math.max(0, parent.width - activeTrack.width - parent.gap)

                                clip: true

                                Rectangle {
                                    anchors.right: parent.right
                                    height: parent.height

                                    width: Math.max(parent.width, height)
                                    radius: height / 2
                                    color: Theme.surface_variant

                                    Rectangle {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.rightMargin: 1.5
                                        width: 5
                                        height: 5
                                        radius: 2.5
                                        color: Theme.primary
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
