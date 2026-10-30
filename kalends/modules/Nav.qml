pragma Singleton
import QtQuick
import Quickshell
import "." as App

/**
 * Where the window is, and the page registry — the same pattern as Dotos,
 * Vane and Vitals: the sidebar, the shortcuts and the page host all read
 * `pages`.
 */
Singleton {
    id: root

    property string page: App.Settings.get("view", "month") === "week" ? "week" : "month"
    onPageChanged: if (page === "month" || page === "week") App.Settings.set("view", page)
    property string sheet: ""          // "", "shortcuts", "about"
    property string toast: ""
    /// ask a page to do something (add on the selected day, focus jump…)
    signal action(string name)
    function run(name) { root.action(name); }
    function go(key) { root.page = key; }
    function say(text) { root.toast = text; toastTimer.restart(); }
    property Timer toastTimer: Timer { interval: 2200; onTriggered: root.toast = "" }

    // group: "" top · foot (pinned bottom)
    readonly property var pages: [
        { key: "month",    label: qsTr("Month"),    icon: "calendar_view_month", group: "", url: "MonthPage.qml" },
        { key: "week",     label: qsTr("Week"),     icon: "calendar_view_week",  group: "", url: "WeekPage.qml" },
        { key: "agenda",   label: qsTr("Agenda"),   icon: "view_agenda",         group: "", url: "AgendaPage.qml" },
        { key: "settings", label: qsTr("Settings"), icon: "settings",            group: "foot", url: "SettingsPage.qml" }
    ]
    function entry(key) { return root.pages.find(p => p.key === key) ?? root.pages[0]; }
}
