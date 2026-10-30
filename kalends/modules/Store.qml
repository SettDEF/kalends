pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../ui" as Ui

/// Events from kalendsd. The CLI is the only thing that knows the .ics format,
/// so the UI goes through the same door the terminal does.
Singleton {
    id: root
    property bool available: true
    property string lastError: ""
    property var events: []
    property var byDay: ({})
    property string binary: ""
    property var pending: null
    property string rangeFrom: ""
    property string rangeTo: ""

    function iso(d) {
        if (!d) return "";
        if (typeof d === "string") return d;
        const p = n => String(n).padStart(2, "0");
        return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
    }
    /// Calendars found in the store, with their event counts.
    property var calendars: []

    /// Filtering happens at lookup, not at load: hiding a calendar is then a
    /// repaint rather than a reload and a subprocess.
    function visible(list) {
        const hidden = Settings.hiddenCalendars;
        if (!hidden || hidden.length === 0) return list;
        return list.filter(e => hidden.indexOf(e.calendar) < 0);
    }
    /// A colour per calendar, so a busy grid reads by calendar. Stepped round
    /// the hue wheel from the theme accent, so the set retints with the
    /// wallpaper instead of clashing with it. The default calendar gets the
    /// accent itself. A "colors": { name: "#hex" } entry in config.json wins.
    function colorOf(name) {
        const own = (Settings.get("colors", ({})) ?? ({}))[name];
        if (own) return own;
        const names = root.calendars.map(c => c.name).filter(n => n !== Settings.defaultCalendar);
        names.unshift(Settings.defaultCalendar);
        const i = Math.max(0, names.indexOf(name));
        const p = Ui.Appearance.primary;
        const h = p.hslHue < 0 ? 0.8 : p.hslHue;
        return Qt.hsla((h + i * 0.29) % 1, Math.max(0.5, p.hslSaturation), Math.min(0.78, Math.max(0.62, p.hslLightness)), 1);
    }
    function tint(c, a) { const q = Qt.color(c); return Qt.rgba(q.r, q.g, q.b, a); }
    function eventsOn(day) { return root.visible(root.byDay[day] ?? []); }
    function countOn(day) { return root.eventsOn(day).length; }

    function loadRange(from, to, force) {
        if (!root.available) return;
        const f = root.iso(from), t = root.iso(to);
        if (!force && f === root.rangeFrom && t === root.rangeTo) return;
        root.rangeFrom = f; root.rangeTo = t;
        if (root.binary.length === 0) { root.pending = ({ from: f, to: t }); return; }
        proc.command = [root.binary, "list", "--from", f, "--to", t, "--json"];
        proc.running = false;
        proc.running = true;
        calsProc.command = [root.binary, "cals", "--json"];
        calsProc.running = false;
        calsProc.running = true;
    }
    function reload() { root.loadRange(root.rangeFrom, root.rangeTo, true); }

    function index(list) {
        const map = ({});
        for (const ev of list) {
            if (!ev?.start) continue;
            const start = new Date(ev.start);
            if (isNaN(start.getTime())) continue;
            // An all-day DTEND is exclusive per RFC 5545.
            let last = new Date(ev.end ?? ev.start);
            if (ev.all_day) last.setDate(last.getDate() - 1);
            if (last < start) last = new Date(start.getTime());
            let cur = new Date(start.getFullYear(), start.getMonth(), start.getDate());
            const stop = new Date(last.getFullYear(), last.getMonth(), last.getDate());
            let guard = 0;
            while (cur <= stop && guard++ < 400) {   // a bad DTEND must not hang the UI
                const k = root.iso(cur);
                (map[k] = map[k] ?? []).push(ev);
                cur.setDate(cur.getDate() + 1);
            }
        }
        for (const k in map)
            map[k].sort((a, b) => (a.all_day === b.all_day)
                ? String(a.start).localeCompare(String(b.start))
                : (a.all_day ? -1 : 1));
        return map;
    }

    /// PATH from a desktop launcher often lacks ~/.local/bin, so resolve once.

    // ── Writes ──────────────────────────────────────────────────────────
    // Every write goes through the same CLI the terminal uses, so the two
    // can never disagree about what an event is. The command reports the
    // event it made, which is what gets shown — never a guess at what the
    // store did.

    /// Emitted after a write lands and the range has been reloaded.
    signal changed(string what)
    /// Set when a write fails, so the UI can say what went wrong.
    property string writeError: ""

    function run(args, done) {
        if (!root.available || root.binary.length === 0) {
            root.writeError = "kalends is not installed";
            return;
        }
        writer.done = done ?? null;
        writer.command = [root.binary].concat(args).concat(["--json"]);
        writer.running = false;
        writer.running = true;
    }

    /// "Title @14:00" or "Title" — a one-line capture, not a form.
    /// Returns false when there is nothing to add.
    function quickAdd(text, isoDate, calendar) {
        const raw = String(text ?? "").trim();
        if (raw.length === 0) return false;

        // A trailing @HH:MM sets the time; anything else is all-day, because
        // guessing a time for "Dentist" is how calendars book the wrong hour.
        const m = raw.match(/^(.*?)\s*@\s*(\d{1,2})[:.](\d{2})\s*$/);
        const title = (m ? m[1] : raw).trim();
        if (title.length === 0) return false;

        const args = ["add", title, "--cal", calendar || "personal"];
        if (m) {
            const hh = String(Math.min(23, parseInt(m[2], 10))).padStart(2, "0");
            const mm = String(Math.min(59, parseInt(m[3], 10))).padStart(2, "0");
            args.push("--at", `${isoDate} ${hh}:${mm}`);
        } else {
            args.push("--at", isoDate, "--all-day");
        }
        root.run(args, () => root.changed("added"));
        return true;
    }


    /// Applies only what actually changed. Sending every field on every save
    /// would rewrite an event the user did not touch, and `edit` refuses a
    /// call that changes nothing — so an unchanged save must not be sent.
    /// `before` is the event as loaded; `after` carries the edited fields.
    function editEvent(before, after) {
        if (!before?.uid) return false;
        const args = ["edit", String(before.uid)];

        const title = String(after.summary ?? "").trim();
        if (title.length > 0 && title !== before.summary) args.push("--title", title);

        if (after.calendar && after.calendar !== before.calendar)
            args.push("--cal", String(after.calendar));

        // All-day is a shape change, so it goes before the time.
        const wasAllDay = before.all_day === true;
        const nowAllDay = after.all_day === true;
        if (nowAllDay && !wasAllDay) args.push("--all-day");
        if (!nowAllDay && wasAllDay) args.push("--no-all-day");

        if (!nowAllDay && after.time && after.time !== root.clockOf(before.start))
            args.push("--at", `${root.dayOf(before.start)} ${after.time}`);

        if (after.minutes && after.minutes !== root.minutesOf(before))
            args.push("--for", `${after.minutes}m`);

        const loc = String(after.location ?? "");
        if (loc !== String(before.location ?? "")) {
            if (loc.length === 0) args.push("--clear-loc"); else args.push("--loc", loc);
        }

        if (args.length === 2) return false;   // nothing changed
        root.run(args, () => root.changed("edited"));
        return true;
    }

    function dayOf(iso)  { return String(iso ?? "").slice(0, 10); }
    function clockOf(iso) { return String(iso ?? "").slice(11, 16); }
    function minutesOf(ev) {
        const a = new Date(ev.start), b = new Date(ev.end);
        if (isNaN(a.getTime()) || isNaN(b.getTime())) return 0;
        return Math.max(1, Math.round((b - a) / 60000));
    }
    function removeEvent(uid) {
        if (!uid) return;
        root.run(["rm", String(uid)], () => root.changed("removed"));
    }


    // ── Noticing changes made elsewhere ─────────────────────────────────
    // The store is shared: the CLI, vdirsyncer or a text editor can change it
    // while this window is open. Without this the window silently shows a
    // stale day — which breaks the one promise the whole design rests on,
    // that the terminal and the window never disagree.
    //
    // A stat of the index file, not a directory walk: every write goes
    // through the CLI, which rewrites that file, so its mtime is the cheapest
    // honest signal that something changed.
    property string storeStamp: ""

    Process {
        id: stampProc
        running: false
        command: ["sh", "-c",
            "stat -c %Y \"$HOME/.local/share/kalends/.index.json\" 2>/dev/null || echo 0"]
        stdout: StdioCollector {
            id: stampOut
            onStreamFinished: {
                const s = String(stampOut.text ?? "").trim();
                if (root.storeStamp !== "" && s !== root.storeStamp) root.reload();
                root.storeStamp = s;
            }
        }
    }

    Timer {
        // Slow on purpose. A calendar changing under you is rare, and the
        // check is one stat — but a tight poll on a shared store is how a
        // desktop app starts costing battery for nothing.
        interval: 4000
        running: root.available
        repeat: true
        triggeredOnStart: true
        onTriggered: { stampProc.running = false; stampProc.running = true; }
    }
    Process {
        id: writer
        property var done: null
        running: false
        stdout: StdioCollector { id: wOut }
        stderr: StdioCollector { id: wErr }
        onExited: code => {
            if (code === 0) {
                root.writeError = "";
                // The store changed underneath the cached range, so reload it
                // rather than patching the local copy and hoping they match.
                root.reload();
                if (writer.done) writer.done();
            } else {
                root.writeError = String(wErr.text ?? "").trim() || "write failed";
            }
            writer.done = null;
        }
    }
    Process {
        id: resolver
        running: true
        command: ["sh", "-c", "command -v kalends || command -v \"$HOME/.local/bin/kalends\" || true"]
        stdout: StdioCollector {
            id: found
            onStreamFinished: {
                root.binary = String(found.text ?? "").trim();
                if (root.binary.length === 0) {
                    root.available = false;
                    root.lastError = "kalends is not installed";
                    return;
                }
                if (root.pending) {
                    const p = root.pending; root.pending = null;
                    root.loadRange(p.from, p.to, true);
                }
            }
        }
    }

    /// `cals` is cheap and changes rarely, so it rides along with each range
    /// load rather than getting its own schedule.
    Process {
        id: calsProc
        running: false
        stdout: StdioCollector {
            id: calsOut
            onStreamFinished: {
                try { root.calendars = JSON.parse(String(calsOut.text ?? "").trim()) ?? []; }
                catch (e) { root.calendars = []; }
            }
        }
    }

    Process {
        id: proc
        running: false
        stdout: StdioCollector {
            id: out
            onStreamFinished: {
                const t = String(out.text ?? "").trim();
                if (t.length === 0) { root.events = []; root.byDay = ({}); return; }
                try {
                    const list = JSON.parse(t) ?? [];
                    root.events = list;
                    root.byDay = root.index(list);
                    root.lastError = "";
                } catch (e) {
                    root.lastError = "unreadable output";
                    root.events = []; root.byDay = ({});
                }
            }
        }
    }
}
