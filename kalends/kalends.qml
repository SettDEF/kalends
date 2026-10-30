//@ pragma UseQApplication
//@ pragma AppId kalends
// Kalends — the calendar app. Run with: qs -p /path/to/kalends.qml
//
// Built like Dotos, Vane and Vitals: a sidebar over the page registry
// (modules/Nav.qml: Month · Week · Agenda · Settings), one page at a time
// under its toolbar, a status bar, the ⋮ menu, the shortcuts sheet (?).
// The calendar's state (selected day, shown month) is modules/Cal.qml; the
// data comes from the same `kalends` CLI the terminal uses (modules/Store.qml).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "modules" as App
import "ui" as Ui

ShellRoot {
    id: appRoot
    readonly property var con: App.Console

    Connections {
        target: App.Nav
        function onAction(name) { appRoot.run(name); }
    }
    property bool _inRun: false
    function run(action) {
        if (appRoot._inRun) return;
        if (App.Nav.pages.some(p => p.key === action)) { App.Nav.go(action); stage.forceActiveFocus(); return; }
        switch (action) {
            case "new":
                // the day panel takes it: on Month or Week, with the panel shown
                if (App.Nav.page !== "month" && App.Nav.page !== "week") App.Nav.go(App.Settings.get("view", "month"));
                if (!App.Settings.get("dayPanel", true)) App.Settings.set("dayPanel", true);
                Qt.callLater(() => { appRoot._inRun = true; App.Nav.action("new"); appRoot._inRun = false; });
                return;
            case "today": App.Cal.today(); break;
            case "back": App.Cal.shift(-1); break;
            case "forward": App.Cal.shift(1); break;
            case "day-panel": App.Settings.set("dayPanel", !App.Settings.get("dayPanel", true)); break;
            case "reload": App.Store.reload(); App.Nav.say(qsTr("Reloaded")); break;
            case "shortcuts": case "about": App.Nav.sheet = action; break;
            case "sidebar": App.Settings.set("sidebarCollapsed", !App.Settings.get("sidebarCollapsed", false)); break;
            case "data-folder": Quickshell.execDetached(["xdg-open", Quickshell.env("HOME") + "/.local/share/kalends/calendars"]); break;
            case "menu": moreMenu.toggle(); return;
            case "escape":
                if (moreMenu.open) moreMenu.open = false;
                else if (App.Nav.sheet !== "") App.Nav.sheet = "";
                else if (App.Nav.page === "settings" || App.Nav.page === "agenda") App.Nav.go(App.Settings.get("view", "month"));
                else Qt.quit();
                break;
            case "quit": Qt.quit(); return;
        }
        stage.forceActiveFocus();
    }

    function key(k, mods, label, group, action, keys) {
        return { label, group, action, keys, match: (e, m) => e.key === k && m === (mods ?? 0) };
    }
    readonly property var shortcuts: [
        key(Qt.Key_M, 0, qsTr("Month"), qsTr("Go to"), "month", ["M"]),
        key(Qt.Key_W, 0, qsTr("Week"), qsTr("Go to"), "week", ["W"]),
        key(Qt.Key_A, 0, qsTr("Agenda"), qsTr("Go to"), "agenda", ["A"]),
        key(Qt.Key_Comma, Qt.ControlModifier, qsTr("Settings"), qsTr("Go to"), "settings", ["Ctrl", ","]),
        key(Qt.Key_N, 0, qsTr("New event on the selected day"), qsTr("Events"), "new", ["N"]),
        key(Qt.Key_N, Qt.ControlModifier, qsTr("New event on the selected day"), qsTr("Events"), "new", ["Ctrl", "N"]),
        key(Qt.Key_T, 0, qsTr("Today"), qsTr("Move"), "today", ["T"]),
        key(Qt.Key_Left, 0, qsTr("A month (a week) back"), qsTr("Move"), "back", ["←"]),
        key(Qt.Key_Right, 0, qsTr("A month (a week) forward"), qsTr("Move"), "forward", ["→"]),
        key(Qt.Key_D, 0, qsTr("The selected day beside the calendar"), qsTr("Window"), "day-panel", ["D"]),
        key(Qt.Key_R, Qt.ControlModifier, qsTr("Reload the calendars"), qsTr("Window"), "reload", ["Ctrl", "R"]),
        key(Qt.Key_B, Qt.ControlModifier, qsTr("Collapse / expand the sidebar"), qsTr("Window"), "sidebar", ["Ctrl", "B"]),
        key(Qt.Key_Question, Qt.ShiftModifier, qsTr("Keyboard shortcuts"), qsTr("Window"), "shortcuts", ["?"]),
        key(Qt.Key_F1, 0, qsTr("Keyboard shortcuts"), qsTr("Window"), "shortcuts", ["F1"]),
        key(Qt.Key_Escape, 0, qsTr("Close · back · quit"), qsTr("Window"), "escape", ["Esc"]),
        key(Qt.Key_Q, Qt.ControlModifier, qsTr("Quit"), qsTr("Window"), "quit", ["Ctrl", "Q"])
    ]
    readonly property var menuItems: [
        { icon: "add", label: qsTr("New event"), hint: "N", action: "new" },
        { icon: "today", label: qsTr("Today"), hint: "T", action: "today" },
        { icon: "refresh", label: qsTr("Reload the calendars"), hint: "Ctrl R", action: "reload" },
        { separator: true },
        { icon: App.Settings.get("dayPanel", true) ? "right_panel_close" : "right_panel_open", label: App.Settings.get("dayPanel", true) ? qsTr("Hide the day panel") : qsTr("Show the day panel"), hint: "D", action: "day-panel" },
        { icon: "folder", label: qsTr("Open the calendar folder"), hint: "", action: "data-folder" },
        { separator: true },
        { icon: "settings", label: qsTr("Settings"), hint: "Ctrl ,", action: "settings" },
        { icon: App.Settings.get("sidebarCollapsed", false) ? "left_panel_open" : "left_panel_close", label: App.Settings.get("sidebarCollapsed", false) ? qsTr("Expand sidebar") : qsTr("Collapse sidebar"), hint: "Ctrl B", action: "sidebar" },
        { icon: "keyboard", label: qsTr("Keyboard shortcuts"), hint: "?", action: "shortcuts" },
        { icon: "info", label: qsTr("About Kalends"), hint: "", action: "about" }
    ]

    // the real window buttons, drawn by the compositor over our top-right corner (ii-decor)
    Process {
        id: decor
        command: ["sh", "-c", "sleep 0.4; hyprctl iidecor integrate pid:$PPID overlay >/dev/null 2>&1 || true"]
    }
    Timer { interval: 200; running: win.visible; onTriggered: decor.running = true }

    // `qs ipc --pid N call kalends shot /tmp/x.png <view>` — a self-capture for
    // checking the look without a screen. <view>: a page key, "menu", "sheet:shortcuts".
    Timer {
        id: shotTimer
        property string path: ""
        interval: 900
        onTriggered: stage.grabToImage(r => r.saveToFile(shotTimer.path))
    }
    IpcHandler {
        target: "kalends"
        function shot(path: string, view: string): void {
            App.Nav.sheet = "";
            moreMenu.open = false;
            if (view.startsWith("sheet:")) App.Nav.sheet = view.slice(6);
            else if (view === "menu") moreMenu.open = true;
            else if (view.length > 0) App.Nav.go(view);
            shotTimer.path = path;
            shotTimer.restart();
        }
        function select(iso: string): void { App.Cal.select(iso); }
        function go(view: string): void { App.Nav.go(view); }
    }

    FloatingWindow {
        // touchpad momentum for every list in the window (ui/Momentum.qml)
        Ui.MomentumInjector { root: parent }
        id: win
        title: "Kalends"
        minimumSize: Qt.size(820, 560)
        implicitWidth: App.Settings.get("windowWidth", 1360)
        implicitHeight: App.Settings.get("windowHeight", 840)
        onWidthChanged: sizeSave.restart()
        onHeightChanged: sizeSave.restart()
        Timer {
            id: sizeSave
            interval: 800
            onTriggered: {
                if (win.width >= 820 && win.height >= 560) {
                    App.Settings.set("windowWidth", Math.round(win.width));
                    App.Settings.set("windowHeight", Math.round(win.height));
                }
            }
        }
        color: appRoot.con.bg
        visible: true
        onVisibleChanged: if (!visible) Qt.quit()

        Rectangle {
            id: stage
            anchors.fill: parent
            color: appRoot.con.bg
            focus: true
            Keys.onPressed: event => {
                const mods = event.modifiers & (Qt.ControlModifier | Qt.ShiftModifier | Qt.AltModifier);
                const hit = appRoot.shortcuts.find(s => s.match(event, mods));
                if (hit) { appRoot.run(hit.action); event.accepted = true; }
            }

            RowLayout {
                anchors.fill: parent
                spacing: 0

                App.Sidebar { Layout.fillHeight: true }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    Loader {
                        id: pageLoader
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        readonly property var entry: App.Nav.entry(App.Nav.page)
                        source: Qt.resolvedUrl("modules/" + entry.url)
                    }

                    // status bar
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 26
                        color: appRoot.con.panel
                        Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: appRoot.con.rule }
                        RowLayout {
                            anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                            spacing: 14
                            Rectangle {
                                implicitWidth: 7; implicitHeight: 7; radius: 3.5
                                color: !App.Store.available || App.Store.lastError || App.Store.writeError ? appRoot.con.crit : appRoot.con.ok
                            }
                            Text {
                                text: App.Store.writeError || App.Store.lastError
                                    || qsTr("%1 calendars · %2 shown").arg(App.Store.calendars.length)
                                        .arg(App.Store.calendars.filter(c => (App.Settings.hiddenCalendars ?? []).indexOf(c.name) < 0).length)
                                font.family: appRoot.con.mono; font.pixelSize: 12
                                color: App.Store.writeError || App.Store.lastError ? appRoot.con.crit : appRoot.con.dim
                                elide: Text.ElideRight
                                Layout.maximumWidth: 520
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "?"
                                font.family: appRoot.con.mono; font.pixelSize: 12; font.weight: Font.Bold; color: appRoot.con.faint
                                TapHandler { onTapped: appRoot.run("shortcuts") }
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                            }
                        }
                    }
                }
            }

            App.MoreMenu {
                id: moreMenu
                items: appRoot.menuItems
                onPicked: action => appRoot.run(action)
            }
            App.ShortcutsSheet {
                open: App.Nav.sheet === "shortcuts"
                shortcuts: appRoot.shortcuts
                onClosed: { App.Nav.sheet = ""; stage.forceActiveFocus(); }
            }
            App.Sheet {
                open: App.Nav.sheet === "about"
                title: qsTr("About Kalends")
                icon: "calendar_month"
                maxWidth: 520
                onClosed: { App.Nav.sheet = ""; stage.forceActiveFocus(); }
                Text {
                    Layout.fillWidth: true
                    text: qsTr("Your calendars: plain .ics files in ~/.local/share/kalends/calendars, synced with your phone through vdirsyncer.\n\nNothing lives only in this window: it is a view onto the kalends CLI, which the terminal and Dotos use too.")
                    font.family: appRoot.con.sans
                    font.pixelSize: 15
                    color: appRoot.con.dim
                    wrapMode: Text.Wrap
                    lineHeight: 1.2
                }
            }

            Rectangle {
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 44 }
                z: 200
                visible: opacity > 0
                opacity: App.Nav.toast.length > 0 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 140 } }
                implicitWidth: toastText.implicitWidth + 28
                implicitHeight: 34
                radius: 17
                color: appRoot.con.text
                Text {
                    id: toastText
                    anchors.centerIn: parent
                    text: App.Nav.toast
                    font.family: appRoot.con.sans
                    font.pixelSize: 15
                    color: appRoot.con.bg
                }
            }
        }
    }
}
