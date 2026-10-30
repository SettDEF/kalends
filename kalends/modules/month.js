.pragma library

// Monday-first month grid: 6 rows x 7 days, each cell carrying its real date
// so the store can be queried per cell.
function monthGrid(year, month, mondayFirst) {   // month is 1-12
    const first = new Date(year, month - 1, 1);
    const lead = mondayFirst === false ? first.getDay() : (first.getDay() + 6) % 7;
    const start = new Date(year, month - 1, 1 - lead);
    const pad = n => (n < 10 ? "0" + n : "" + n);
    const today = new Date();
    const todayKey = today.getFullYear() + "-" + pad(today.getMonth() + 1) + "-" + pad(today.getDate());

    const rows = [];
    for (let r = 0; r < 6; r++) {
        const row = [];
        for (let c = 0; c < 7; c++) {
            const d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + r * 7 + c);
            const key = d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());
            row.push({
                day: d.getDate(),
                date: key,
                outside: (d.getMonth() + 1) !== month,
                today: key === todayKey
            });
        }
        rows.push(row);
    }
    return rows;
}

var weekDaysMonday = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"];
var weekDaysSunday = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"];
function weekDayNames(mondayFirst) {
    return mondayFirst === false ? weekDaysSunday : weekDaysMonday;
}

function pad2(n) { return (n < 10 ? "0" : "") + n; }
function isoOf(d) { return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate()); }
/// "YYYY-MM-DD" at midday, so a DST change can never move it to another day.
function parse(iso) { return new Date(iso + "T12:00:00"); }
function addDays(iso, n) {
    const d = parse(iso);
    return isoOf(new Date(d.getFullYear(), d.getMonth(), d.getDate() + n));
}

/// The seven dates of the week holding `iso`.
function weekOf(iso, mondayFirst) {
    const d = parse(iso);
    const lead = mondayFirst === false ? d.getDay() : (d.getDay() + 6) % 7;
    const out = [];
    for (let i = 0; i < 7; i++)
        out.push(isoOf(new Date(d.getFullYear(), d.getMonth(), d.getDate() - lead + i)));
    return out;
}

/// ISO 8601 week number (weeks start Monday; week 1 holds the first Thursday).
function isoWeek(iso) {
    const d = parse(iso);
    const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
    const day = t.getUTCDay() || 7;
    t.setUTCDate(t.getUTCDate() + 4 - day);
    const y0 = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
    return Math.ceil(((t - y0) / 86400000 + 1) / 7);
}

/// Timed events of one day placed for a timeline: minutes from midnight,
/// clipped to the day, and overlapping events side by side. Greedy columns
/// per cluster of overlaps, the same packing every calendar app uses.
function layoutDay(events, iso) {
    const day0 = parse(iso); day0.setHours(0, 0, 0, 0);
    const items = [];
    for (const ev of events) {
        if (ev.all_day) continue;
        const s = new Date(ev.start), e = new Date(ev.end ?? ev.start);
        if (isNaN(s.getTime())) continue;
        let top = (s - day0) / 60000, bottom = (e - day0) / 60000;
        if (!(bottom > top)) bottom = top + 30;
        top = Math.max(0, top); bottom = Math.min(1440, bottom);
        if (bottom <= 0 || top >= 1440) continue;
        items.push({ ev: ev, top: top, bottom: Math.max(bottom, top + 20), col: 0, cols: 1 });
    }
    items.sort((a, b) => a.top - b.top || b.bottom - a.bottom);
    let cluster = [], colEnds = [], clusterEnd = -1;
    const close = () => { for (const it of cluster) it.cols = colEnds.length; cluster = []; colEnds = []; };
    for (const it of items) {
        if (it.top >= clusterEnd) close();
        let c = colEnds.findIndex(end => end <= it.top);
        if (c < 0) { c = colEnds.length; colEnds.push(0); }
        colEnds[c] = it.bottom;
        it.col = c;
        cluster.push(it);
        clusterEnd = Math.max(clusterEnd, it.bottom);
    }
    close();
    return items;
}
