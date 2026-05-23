import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Effects
import "../theme"

Variants {
    id: root
    model: Quickshell.screens

    delegate: PanelWindow {
        id: volumeOsdPopup

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
        WlrLayershell.namespace: "volume_osd"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        readonly property var activeSink: Pipewire.defaultAudioSink
        readonly property bool isMuted: activeSink?.audio?.muted ?? true
        readonly property real volumeLevel: activeSink?.audio?.volume ?? 0.0

        PwObjectTracker {
            objects: volumeOsdPopup.activeSink ? [volumeOsdPopup.activeSink] : []
        }

        onVolumeLevelChanged: {
            triggerOsd();
        }

        onIsMutedChanged: {
            triggerOsd();
        }

        property bool isInitialized: false
        property bool showOsd: false

        Timer {
            id: initTimer
            interval: 1000
            running: true

            onTriggered: {
                volumeOsdPopup.isInitialized = true;
            }
        }

        Timer {
            id: hideTimer
            interval: 2000

            onTriggered: {
                volumeOsdPopup.showOsd = false;
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
                        id: volumeIcon
                        anchors.verticalCenter: parent.verticalCenter

                        color: volumeOsdPopup.isMuted ? Theme.critical : Theme.on_surface

                        font {
                            family: "Material Symbols Rounded"
                            pixelSize: 28
                        }

                        text: {
                            if (!volumeOsdPopup.activeSink?.audio)
                                return "volume_off";
                            if (volumeOsdPopup.isMuted)
                                return "volume_off";
                            if (volumeOsdPopup.volumeLevel >= 0.6)
                                return "volume_up";
                            if (volumeOsdPopup.volumeLevel >= 0.3)
                                return "volume_down";

                            return "volume_mute";
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - volumeIcon.width - parent.spacing - 6
                        spacing: 8

                        Item {
                            width: parent.width
                            height: volumeLabel.implicitHeight

                            Text {
                                text: "Volume"
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.on_surface

                                font {
                                    family: "Google Sans Medium"
                                    pixelSize: 16
                                }
                            }

                            Text {
                                id: volumeLabel
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.on_surface

                                font {
                                    family: "Google Sans Medium"
                                    pixelSize: 16
                                }

                                text: volumeOsdPopup.activeSink?.audio ? Math.round(volumeOsdPopup.volumeLevel * 100) : "--"
                            }
                        }

                        Item {
                            width: parent.width
                            height: 6

                            readonly property real visualVolume: Math.min(volumeOsdPopup.volumeLevel, 1.0)
                            readonly property int gap: 4

                            Rectangle {
                                id: activeTrack
                                x: 0
                                y: 0
                                height: parent.height

                                width: (parent.width - 4) * parent.visualVolume
                                radius: height / 2

                                color: volumeOsdPopup.isMuted ? Theme.outline : Theme.primary

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
                                        color: volumeOsdPopup.isMuted ? Theme.outline : Theme.primary
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
