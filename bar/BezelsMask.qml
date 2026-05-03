pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import "../theme"

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: root
        required property var modelData

        screen: modelData
        color: "transparent"
        visible: true
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.layer: WlrLayer.Top

        mask: Region {
            item: container
            intersection: Intersection.Xor
        }

        anchors {
            top: true
            left: true
            bottom: true
            right: true
        }

        Item {
            id: container
            anchors.fill: parent

            Item {
                id: bezel

                anchors.fill: parent
                layer.enabled: true

                // Drop Shadow
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#B0000000"
                    shadowVerticalOffset: 0
                    shadowHorizontalOffset: 0

                    blurMax: 20
                    shadowBlur: 0.5
                }

                Rectangle {
                    anchors.fill: parent

                    color: Theme.surface
                    layer.enabled: true

                    // Rectangle Cutout
                    layer.effect: MultiEffect {
                        maskSource: maskShapeSource
                        maskEnabled: true
                        maskInverted: true
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1
                    }
                }

                // Mask Cutout Sape
                Item {
                    id: maskShapeSource

                    anchors.fill: parent
                    layer.enabled: true
                    visible: false

                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: Layout.sideBarWidth
                        anchors.rightMargin: Layout.sideBarWidth
                        anchors.topMargin: Layout.topBarHeight
                        anchors.bottomMargin: Layout.bottomBarHeight

                        radius: Layout.cornerRadius
                    }
                }
            }
        }
    }
}
