pragma Singleton
import QtQuick
import Quickshell
import "." as App
import "month.js" as Month

/**
 * The calendar's state, shared by every page: which day is selected, which
 * month is shown, and moving around. The pages only draw.
 */
Singleton {
    id: root

    property int year: new Date().getFullYear()
    property int month: new Date().getMonth() + 1          // 1-based
    property string selected: App.Store.iso(new Date())
    readonly property var grid: Month.monthGrid(root.year, root.month, App.Settings.mondayFirst)
    readonly property string todayIso: App.Store.iso(new Date())

    /// pick a day: the month follows it
    function select(iso) {
        root.selected = iso;
        const d = Month.parse(iso);
        root.year = d.getFullYear();
        root.month = d.getMonth() + 1;
    }
    /// back / forward: a month on the Month page, a week on the Week page
    function shift(n) {
        if (App.Nav.page === "week") { root.select(Month.addDays(root.selected, 7 * n)); return; }
        let m = root.month + n, y = root.year;
        while (m < 1) { m += 12; y--; }
        while (m > 12) { m -= 12; y++; }
        root.month = m; root.year = y;
        const day = Math.min(Month.parse(root.selected).getDate(), new Date(y, m, 0).getDate());
        root.selected = `${y}-${String(m).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
    }
    function today() { root.select(App.Store.iso(new Date())); }

    function monthTitle() { return Qt.formatDateTime(new Date(root.year, root.month - 1, 1), "MMMM yyyy"); }
    function weekTitle() {
        const w = Month.weekOf(root.selected, App.Settings.mondayFirst);
        const a = Month.parse(w[0]), b = Month.parse(w[6]);
        return a.getMonth() === b.getMonth()
            ? Qt.formatDateTime(a, "d") + " – " + Qt.formatDateTime(b, "d MMMM yyyy")
            : Qt.formatDateTime(a, "d MMM") + " – " + Qt.formatDateTime(b, "d MMM yyyy");
    }
    /// the selected day against today, in words
    readonly property string relative: {
        const n = Math.round((Month.parse(root.selected) - Month.parse(root.todayIso)) / 86400000);
        return n === 0 ? qsTr("today") : n === 1 ? qsTr("tomorrow") : n === -1 ? qsTr("yesterday")
             : n > 0 ? qsTr("in %1 days").arg(n) : qsTr("%1 days ago").arg(-n);
    }
    /// how full the shown month is, and what comes next
    readonly property string summary: {
        const ym = root.year + "-" + String(root.month).padStart(2, "0");
        const days = Object.keys(App.Store.byDay).sort();
        const seen = {};
        for (const d of days) if (d.startsWith(ym)) for (const e of App.Store.eventsOn(d)) seen[e.uid ?? (e.summary + e.start)] = true;
        const n = Object.keys(seen).length;
        const now = new Date();
        let next = null;
        for (const d of days) {
            if (d < root.todayIso) continue;
            const up = App.Store.eventsOn(d).filter(e => e.all_day ? d > root.todayIso || String(e.start).slice(0, 10) === d : new Date(e.start) >= now);
            if (up.length) { next = { e: up[0], d }; break; }
        }
        const parts = [n === 1 ? qsTr("1 event this month") : qsTr("%1 events this month").arg(n)];
        if (next) {
            const k = Math.round((Month.parse(next.d) - Month.parse(root.todayIso)) / 86400000);
            parts.push(qsTr("next: %1, %2").arg(next.e.summary ?? "").arg(k <= 0 ? qsTr("today") : k === 1 ? qsTr("tomorrow") : qsTr("in %1 days").arg(k)));
        }
        if (!App.Store.available) parts.push(qsTr("the kalends CLI is not installed"));
        return parts.join("  ·  ");
    }

    /// load the six weeks around whatever is shown
    function loadVisible() {
        const first = root.grid?.[0]?.[0]?.date;
        const last = root.grid?.[5]?.[6]?.date;
        if (first && last) App.Store.loadRange(first, last);
    }
    onGridChanged: Qt.callLater(root.loadVisible)
    Component.onCompleted: root.loadVisible()
}
