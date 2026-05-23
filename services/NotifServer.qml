pragma Singleton

import QtQuick
import Quickshell.Services.Notifications

/**
 * Singleton service providing a centralized interface for D-Bus notification signals.
 */
NotificationServer {
    id: notificationServer

    // Capabilities advertised to the system notification daemon
    bodySupported: true
    actionsSupported: true
    imageSupported: true
    persistenceSupported: true

    /**
     * Primary handler for incoming notification requests.
     * Maps external system events to the internal shell state.
     */
    onNotification: notification => {
        // Enables automatic management within the trackedNotifications ObjectModel
        notification.tracked = true;
    }
}
