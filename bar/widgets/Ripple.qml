import QtQuick
import QtQuick.Effects

// M3-style state-layer ripple. Drop inside any rounded container and call
// trigger(x, y) with the press coordinates (from a MouseArea's onPressed).
Item {
    id: root
    anchors.fill: parent

    property color rippleColor: "#ffffff"
    property real cornerRadius: 0

    function trigger(px, py) {
        rippleCircle.x = px - rippleCircle.width / 2;
        rippleCircle.y = py - rippleCircle.height / 2;
        rippleCircle.opacity = 0.28;
        rippleCircle.scale = 0;
        rippleAnim.restart();
    }

    Rectangle {
        id: maskShape
        anchors.fill: parent
        radius: root.cornerRadius
        visible: false
    }

    Item {
        id: rippleLayer
        anchors.fill: parent
        layer.enabled: rippleAnim.running
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: maskShape
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }

        Rectangle {
            id: rippleCircle
            width: Math.max(root.width, root.height) * 1.8
            height: width
            radius: width / 2
            color: root.rippleColor
            opacity: 0
            scale: 0
            transformOrigin: Item.Center
        }
    }

    ParallelAnimation {
        id: rippleAnim
        NumberAnimation {
            target: rippleCircle
            property: "scale"
            to: 1
            duration: 450
            easing.type: Easing.OutQuad
        }
        SequentialAnimation {
            PauseAnimation {
                duration: 120
            }
            NumberAnimation {
                target: rippleCircle
                property: "opacity"
                to: 0
                duration: 280
            }
        }
    }
}
