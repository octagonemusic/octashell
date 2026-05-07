import Quickshell
import QtQuick
import "bar"
import "notifications"
import qs.services

ShellRoot {
    // Bars
    LeftBar {}
    BottomBar {}
    RightBar {}
    BezelsMask {}
    TopBar {}

    // Notification Popup
    NotifPopup {}
}
