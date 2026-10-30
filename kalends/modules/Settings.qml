pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/// The app's own settings, in its own file. Plain JSON, so the CLI or a text
/// editor can change them too — same rule as the event store.
Singleton {
    id: root
    readonly property string dir:
        (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/kalends"
    readonly property string path: root.dir + "/config.json"

    property var data: ({})
    function get(key, def) { return root.data[key] ?? def }
    function set(key, value) {
        const next = Object.assign({}, root.data);
        next[key] = value;
        root.data = next;
        saveProc.command = ["sh", "-c",
            `mkdir -p '${root.dir}' && cat > '${root.path}'`];
        saveProc.running = false;
        saveProc.running = true;
    }

    // ── The settings themselves ─────────────────────────────────────────
    readonly property bool mondayFirst:  get("mondayFirst", true)
    readonly property bool weekNumbers:  get("weekNumbers", false)
    readonly property bool twentyFour:   get("twentyFour", true)
    readonly property bool showDots:     get("showDots", true)
    readonly property bool openOnToday:  get("openOnToday", true)
    readonly property string defaultCalendar: get("defaultCalendar", "personal")
    readonly property string fontOverride: get("fontOverride", "")
    /// Calendar names the month grid and agenda leave out. Names, not paths,
    /// so a calendar that moves on disk stays hidden.
    readonly property var hiddenCalendars: get("hiddenCalendars", [])

    function toggleCalendar(name) {
        const now = (root.hiddenCalendars ?? []).slice();
        const i = now.indexOf(name);
        if (i >= 0) now.splice(i, 1); else now.push(name);
        root.set("hiddenCalendars", now);
    }

    Process {
        id: saveProc
        running: false
        stdinEnabled: true
        onStarted: {
            saveProc.write(JSON.stringify(root.data, null, 2) + "\n");
            saveProc.stdinEnabled = false;
        }
    }

    FileView {
        id: file
        path: root.path
        watchChanges: true
        onFileChanged: file.reload()
        onLoaded: {
            try { root.data = JSON.parse(file.text()) ?? ({}); }
            catch (e) { root.data = ({}); }
        }
    }
    Component.onCompleted: file.reload()
}
