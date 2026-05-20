import QtQuick
import Quickshell

QtObject {
    id: backend

    // Configuration Paths
    readonly property string configDir: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string wallDir: homeDir + "/Pictures/walls"
    readonly property string thumbDir: (Quickshell.env("XDG_CACHE_HOME") || (homeDir + "/.cache")) + "/quickshell/thumbs"
    readonly property string setThemeScript: homeDir + "/.local/bin/set-theme"
    readonly property string thumbScript: configDir + "/quickshell/scripts/generate-thumbs.sh"

    // UI Configuration
    property real thumbAspectRatio: 1.6
    property int listRenderBuffer: 200
    property int listCacheBuffer: 800
    property int waylandStabilizationDelay: 40

    // Internal State
    property bool isListReady: false
    property bool layoutPending: false

    function safeDecodeURI(uri) {
        try {
            return decodeURIComponent(uri);
        } catch (e) {
            return uri;
        }
    }

    function normalizePath(uri) {
        let decoded = safeDecodeURI(uri.toString());
        return decoded.replace(/^file:\/{2,3}/, "/").replace(/\/+/g, '/');
    }

    function syncThumbnails() {
        Quickshell.execDetached({
            command: ["bash", thumbScript, wallDir, thumbDir]
        });
    }

    function setWallpaper(fileUrl) {
        let path = normalizePath(fileUrl);
        Quickshell.execDetached({
            command: ["bash", setThemeScript, path]
        });
    }
}
