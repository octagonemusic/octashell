//@ pragma IconTheme Papirus

import Quickshell
import QtQuick
import "bar"
import qs.utilities.clipboard
import qs.utilities.emoji
import qs.utilities.launcher
import qs.utilities.wallpaper
import qs.popups
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

    // Emoji Picker
    EmojiPicker {
        id: emojiPickerWindow
    }

    // Application Launcher
    Launcher {
        id: launcherWindow
    }

    // Wallpaper Selector
    WallpaperSelector {
        id: wallpaperSelectorWindow
    }

    VolumePopup {
        id: volumePopupWindow
    }

    BrightnessPopup {
        id: brightnessPopupWindow
    }
}
