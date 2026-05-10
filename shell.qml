import Quickshell
import QtQuick
import "bar"
import "notifications"
import "utilities"
import qs.services

/** Main shell entry point; manages surface orchestration. */
ShellRoot {
    id: root

    // Primary desktop bars
    LeftBar {
        id: leftBar
    }
    BottomBar {
        id: bottomBar
    }
    RightBar {
        id: rightBar
    }

    // Screen masking for rounded workspace effect
    BezelsMask {
        id: desktopBezels
    }

    // System status bar
    TopBar {
        id: topBar
    }

    // Floating notification overlay
    NotifPopup {
        id: notificationOverlay
    }

    // Clipboard
    Clipboard {
        id: clipboardWindow
    }
}
