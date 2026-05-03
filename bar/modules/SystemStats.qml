import QtQuick
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import qs.theme

Rectangle {
    id: root

    // --- PILL SHAPE & SIZE ---
    implicitWidth: row.width + 30
    implicitHeight: row.height + 18
    color: Theme.surface_container
    radius: height / 2

    // ==========================================
    // THE FIX: The Activator Pattern
    // 1. Grab the sink and save it to the root
    property var audioNode: Pipewire.defaultAudioSink

    // 2. Pass it into the tracker to "wake up" the live updates
    PwObjectTracker {
        objects: root.audioNode ? [root.audioNode] : []
    }
    // ==========================================

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 16

        // ==========================
        // 1. VOLUME MODULE
        // ==========================
        Row {
            id: volControls
            spacing: 8

            // Icon
            Text {
                text: {
                    // Read directly from our "woken up" root.audioNode
                    if (!root.audioNode || !root.audioNode.audio)
                        return "";
                    if (root.audioNode.audio.muted)
                        return "";

                    const vol = root.audioNode.audio.volume;
                    if (vol >= 0.6)
                        return "";
                    if (vol >= 0.3)
                        return "";
                    return "";
                }

                color: (root.audioNode && root.audioNode.audio && root.audioNode.audio.muted) ? Theme.critical : Theme.primary

                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16
                anchors.verticalCenter: parent.verticalCenter

                // Click to Mute
                TapHandler {
                    onTapped: {
                        if (root.audioNode && root.audioNode.audio) {
                            root.audioNode.audio.muted = !root.audioNode.audio.muted;
                        }
                    }
                }
            }

            // Percentage
            Text {
                text: (root.audioNode && root.audioNode.audio) ? Math.round(root.audioNode.audio.volume * 100) + "%" : "--%"
                color: Theme.on_surface
                font.family: "Google Sans Medium"
                font.pixelSize: 16
                anchors.verticalCenter: parent.verticalCenter
            }

            // Scroll to Change Volume
            WheelHandler {
                onWheel: event => {
                    if (!root.audioNode || !root.audioNode.audio)
                        return;

                    const step = 0.05;
                    let newVol = root.audioNode.audio.volume;

                    if (event.angleDelta.y > 0)
                        newVol += step;
                    else
                        newVol -= step;

                    // Clamp 0.0 - 1.0
                    if (newVol > 1.0)
                        newVol = 1.0;
                    if (newVol < 0.0)
                        newVol = 0.0;

                    root.audioNode.audio.volume = newVol;
                }
            }
        }

        // ==========================
        // 2. SEPARATOR
        // ==========================
        Rectangle {
            visible: UPower.displayDevice && UPower.displayDevice.isPresent
            width: 1
            height: 16
            color: Theme.outline_variant
            anchors.verticalCenter: parent.verticalCenter
        }

        // ==========================
        // 3. BATTERY MODULE
        // ==========================
        Row {
            id: batControls

            visible: UPower.displayDevice && UPower.displayDevice.isPresent
            spacing: 8

            property var bat: UPower.displayDevice

            // Icon
            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 16

                // Color Logic
                color: {
                    if (!batControls.bat)
                        return Theme.on_surface;

                    const p = batControls.bat.percentage * 100;

                    if (UPower.onBattery === false && p < 100)
                        return Theme.critical;

                    if (p <= 20)
                        return Theme.critical;

                    return Theme.primary;
                }

                // Icon Symbol Logic
                text: {
                    if (!batControls.bat)
                        return "";

                    const p = batControls.bat.percentage * 100;
                    const charging = (UPower.onBattery === false);

                    if (charging && p < 100)
                        return ""; // Bolt
                    if (p >= 90)
                        return "󰂂";
                    if (p >= 70)
                        return "󰂀";
                    if (p >= 50)
                        return "󰁾";
                    if (p >= 30)
                        return "󰁼";
                    if (p >= 10)
                        return "󰁺";
                    return "󰂃";
                }
            }

            // Percentage Text
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: batControls.bat ? Math.round(batControls.bat.percentage * 100) + "%  " : " "
                color: Theme.on_surface
                font.family: "Google Sans Medium"
                font.pixelSize: 16
            }
        }


        // Rectangle {
        //             visible: UPower.displayDevice && UPower.displayDevice.isPresent
        //             width: 1
        //             height: 16
        //             color: Theme.outline_variant
        //             anchors.verticalCenter: parent.verticalCenter
        //         }

        // Text {
        //     anchors.verticalCenter: parent.verticalCenter
        //     text: "power_settings_circle"
        //     color: Theme.on_surface
        //     font.family: "Material Symbols Rounded"
        //     font.pixelSize: 30

        //     font.variableAxes: {
        //         "FILL": 1
        //     }

        //     // 1. Tell Qt NOT to snap the vectors to the pixel grid
        //     font.hintingPreference: Font.PreferNoHinting

        //     // 2. Try the Qt distance-field renderer instead of Native
        //     renderType: Text.CurveRendering // or try Text.QtRendering if this fails
        // }
    }
}
