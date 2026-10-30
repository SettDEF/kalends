//! kalnds — a calendar for the ii desktop.
//!
//! One binary: the CLI you type, and the JSON the QML app reads. They share
//! this code so the terminal and the window can never disagree about what an
//! event is.

use chrono::{Datelike, Duration, NaiveDate, Timelike};
use icalcore::store::{Layout, Store};
use icalcore::cli::{flag, has, parse_date, parse_duration, parse_when};
use icalcore::{ics, recur, store};
use ics::Event;

/// Kalends' own corner of the disk. Dotos names a different one; the library
/// itself knows only the vdir layout.
const KALENDS: Layout = Layout {
    env_var: "KALENDS_HOME",
    app_dir: "kalends",
    sub_dir: "calendars",
};

/// Flags that consume the next argument, so that value is never mistaken
/// for a flag of our own.
const VALUE_FLAGS: &[&str] = &[
    "--at", "--for", "--cal", "--loc", "--note", "--title",
    "--from", "--to", "--days",
];

const USAGE: &str = "\
kalends — calendar

  kalends today                      what's on today
  kalends agenda [--days N]          the next N days (default 7)
  kalends next                       the next event, one line
  kalends cal [YYYY-MM]              a month grid
  kalends list [--from D] [--to D]   a range
  kalends cals                       calendars and their event counts
  kalends add TITLE [options]        add an event
  kalends rm ID                      delete by id prefix
  kalends edit ID [options]           change an event
  kalends import FILE [--cal N]      merge an .ics file in
  kalends export [--cal N] [range]   write .ics to stdout
  kalends status                     store health, counts, next up, last sync
  kalends remind [--lead N]          notify about events starting soon
  kalends sync [--init]              sync with the configured remote
  kalends where                      where the store lives

add options
  --at WHEN        start: 'today', 'tomorrow', 'HH:MM',
                   'YYYY-MM-DD', 'YYYY-MM-DD HH:MM'   (default: now)
  --for DURATION   '90m', '2h', '1h30m'               (default: 1h)
  --all-day        an all-day event
  --cal NAME       calendar to put it in              (default: personal)
  --loc TEXT       location
  --note TEXT      description

edit options
  the add options above, plus
  --title TEXT     rename
  --no-all-day     back to a timed event
  --clear-loc      drop the location
  --clear-note     drop the description
  (--at keeps the duration; --cal moves it between calendars)

sync
  --init           write a vdirsyncer config pointed at this store
  --discover       re-scan remote calendars (needed after the first auth)
  exit 0 synced | 1 the sync tool failed | 3 nothing configured yet

remind
  --lead N         minutes of warning (default 10)
  --dry-run        print what would be sent, send nothing
  Meant for a systemd timer; see packaging/kalends-remind.timer

import options
  --cal NAME       calendar to merge into             (default: personal)
  --force          import even if the UID already exists

  --json           machine-readable output
";

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    if args.is_empty() || args[0] == "-h" || args[0] == "--help" {
        print!("{USAGE}");
        return;
    }
    // --json is stripped positionally, not by matching every occurrence: a
    // blanket filter also removed it when it was a flag's VALUE, so
    // `add "x" --loc "--json"` silently lost the location and switched to
    // JSON output at the same time.
    let mut json = false;
    let mut rest: Vec<String> = Vec::with_capacity(args.len());
    let mut i = 0;
    while i < args.len() {
        let a = &args[i];
        if a == "--json" {
            json = true;
            i += 1;
            continue;
        }
        rest.push(a.clone());
        // A flag's value is taken verbatim, so it can be "--json" or anything else.
        if a.starts_with("--") && VALUE_FLAGS.contains(&a.as_str()) {
            if let Some(v) = args.get(i + 1) {
                rest.push(v.clone());
                i += 2;
                continue;
            }
        }
        i += 1;
    }
    let cmd = rest[0].as_str();
    let store = Store::open(KALENDS);

    let code = match cmd {
        "today"  => cmd_range(&store, ics::today(), ics::today(), json),
        "agenda" => {
            let days: i64 = flag(&rest, "--days").and_then(|v| v.parse().ok()).unwrap_or(7);
            cmd_range(&store, ics::today(), ics::today() + Duration::days(days - 1), json)
        }
        "list" => {
            let from = flag(&rest, "--from").and_then(|v| parse_date(&v)).unwrap_or_else(ics::today);
            let to = flag(&rest, "--to").and_then(|v| parse_date(&v)).unwrap_or(from + Duration::days(30));
            cmd_range(&store, from, to, json)
        }
        "next"  => cmd_next(&store, json),
        "cal"   => cmd_cal(&store, rest.get(1).cloned()),
        "cals"  => cmd_cals(&store, json),
        "add"   => cmd_add(&store, &rest, json),
        "rm"    => cmd_rm(&store, &rest),
        "edit"  => cmd_edit(&store, &rest, json),
        "import" => cmd_import(&store, &rest, json),
        "export" => cmd_export(&store, &rest),
        "status" => cmd_status(&store, json),
        "remind" => cmd_remind(&store, &rest, json),
        "sync"   => cmd_sync(&rest, json),
        "where" => { println!("{}", store::path_display(&store.root)); 0 }
        other => { eprintln!("kalends: unknown command '{other}'\n\n{USAGE}"); 2 }
    };

    // Writes do not maintain the bounds index, and vdirsyncer writes straight
    // into the vdir without going through this binary at all. Re-indexing
    // here is what makes .index.json change exactly when the store's contents
    // changed — which is what the shell watches to notice a sync.
    if code == 0 && matches!(cmd, "add" | "rm" | "edit" | "import" | "sync") {
        store.reindex();
    }
    std::process::exit(code);
}


// ── commands ────────────────────────────────────────────────────────────────

/// Every occurrence in [from, to], recurring events expanded.
///
/// Expansion happens in the core rather than any front-end, so `list`, the
/// window and the shell's sidebar can never disagree about which days an
/// event lands on.
pub fn events_in(store: &Store, from: NaiveDate, to: NaiveDate) -> Vec<Event> {
    // The range goes to the store, so files whose dates miss it are never
    // opened — that is what keeps this from getting slower forever.
    let mut out: Vec<Event> = store.load_range(Some((from, to))).iter()
        .flat_map(|e| recur::expand(e, from, to))
        .collect();
    // Occurrences arrive grouped per source event, not in date order.
    out.sort_by(|a, b| a.start.cmp(&b.start).then_with(|| a.summary.cmp(&b.summary)));
    out
}

fn cmd_range(store: &Store, from: NaiveDate, to: NaiveDate, json: bool) -> i32 {
    let evs = events_in(store, from, to);
    if json { println!("{}", serde_json::to_string(&evs).unwrap_or_else(|_| "[]".into())); return 0; }
    if evs.is_empty() { println!("Nothing scheduled."); return 0; }
    let mut day = NaiveDate::MIN;
    for e in &evs {
        let d = e.start.date().max(from);
        if d != day {
            day = d;
            println!("\n{}", d.format("%a %e %B"));
        }
        let mark = if e.rrule.is_empty() { "" } else { " ↻" };
        println!("  {:<8} {:<28} {}{}", time_label(e), truncate(&e.summary, 28), dim(&e.calendar), dim(mark));
    }

    0
}

fn cmd_next(store: &Store, json: bool) -> i32 {
    let now = ics::now_local();
    let today = ics::today();

    // Widen in steps rather than loading the whole store. A bar widget polls
    // this, and almost every answer is within days — scanning years of files
    // to find tomorrow's dentist appointment is what made this the slowest
    // command in the set.
    let mut next = None;
    for days in [7i64, 60, 400] {
        let evs = store.load_range(Some((today, today + Duration::days(days))));
        next = evs.into_iter().filter(|e| e.start >= now).min_by_key(|e| e.start);
        if next.is_some() { break; }
    }
    // Nothing within about a year: fall back to everything, so an event far
    // in the future is still found rather than reported as none.
    if next.is_none() {
        next = store.load().into_iter().filter(|e| e.start >= now).min_by_key(|e| e.start);
    }

    match next {
        Some(e) if json => { println!("{}", serde_json::to_string(&e).unwrap_or_default()); 0 }
        Some(e) => { println!("{}  {}", time_label(&e), e.summary); 0 }
        None if json => { println!("null"); 0 }
        None => { println!("—"); 0 }
    }
}

fn cmd_cals(store: &Store, json: bool) -> i32 {
    let all = store.load();
    let cals = store.calendars();
    if json {
        let rows: Vec<_> = cals.iter().map(|c| serde_json::json!({
            "name": c.name,
            "path": store::path_display(&c.path),
            "events": all.iter().filter(|e| e.calendar == c.name).count(),
        })).collect();
        println!("{}", serde_json::to_string(&rows).unwrap_or_else(|_| "[]".into()));
        return 0;
    }
    if cals.is_empty() { println!("No calendars yet — 'kalends add' makes one."); return 0; }
    for c in cals {
        let n = all.iter().filter(|e| e.calendar == c.name).count();
        let unit = if n == 1 { "event " } else { "events" };
        println!("  {:<16} {:>4} {}   {}", c.name, n, unit, store::path_display(&c.path));
    }
    0
}

fn cmd_add(store: &Store, args: &[String], json: bool) -> i32 {
    let Some(title) = args.get(1).filter(|t| !t.starts_with("--")) else {
        eprintln!("kalends add: needs a title"); return 2;
    };
    let all_day = has(args, "--all-day");
    let start = match flag(args, "--at") {
        Some(v) => match parse_when(&v) {
            Some(dt) => dt,
            None => { eprintln!("kalends add: cannot read --at '{v}'"); return 2; }
        },
        None => ics::now_local().with_second(0).unwrap_or_else(ics::now_local),
    };
    let dur = match flag(args, "--for") {
        Some(v) => match parse_duration(&v) {
            Some(d) => d,
            None => { eprintln!("kalends add: cannot read --for '{v}'"); return 2; }
        },
        None => if all_day { Duration::days(1) } else { Duration::hours(1) },
    };
    let ev = Event {
        uid: store::new_uid("kalends"),
        calendar: flag(args, "--cal").unwrap_or_else(|| "personal".into()),
        summary: title.clone(),
        start: if all_day { start.date().and_hms_opt(0,0,0).unwrap() } else { start },
        end: if all_day { start.date().and_hms_opt(0,0,0).unwrap() + dur } else { start + dur },
        all_day,
        location: flag(args, "--loc").unwrap_or_default(),
        description: flag(args, "--note").unwrap_or_default(),
        rrule: String::new(),
        extra: Vec::new(),
    };
    match store.save(&ev) {
        Ok(p) => {
            if json { println!("{}", serde_json::to_string(&ev).unwrap_or_default()); }
            else { println!("Added {}  {}  [{}]", time_label(&ev), ev.summary, &ev.uid[..8.min(ev.uid.len())]);
                   eprintln!("  {}", store::path_display(&p)); }
            0
        }
        Err(e) => { eprintln!("kalends add: {e}"); 1 }
    }
}

fn cmd_rm(store: &Store, args: &[String]) -> i32 {
    let Some(prefix) = args.get(1) else { eprintln!("kalends rm: needs an id"); return 2 };
    let all = store.load();
    match store.find_by_prefix(&all, prefix) {
        Ok(ev) => match store.delete(ev) {
            Ok(()) => { println!("Removed {}", ev.summary); 0 }
            Err(e) => { eprintln!("kalends rm: {e}"); 1 }
        },
        Err(msg) => { eprintln!("kalends rm: {msg}"); 1 }
    }
}

fn cmd_cal(store: &Store, month: Option<String>) -> i32 {
    let today = ics::today();
    let (y, m) = match month.as_deref() {
        Some(s) => {
            let Some((ys, ms)) = s.split_once('-') else { eprintln!("kalends cal: want YYYY-MM"); return 2 };
            match (ys.parse::<i32>(), ms.parse::<u32>()) {
                (Ok(y), Ok(m)) if (1..=12).contains(&m) => (y, m),
                _ => { eprintln!("kalends cal: want YYYY-MM"); return 2 }
            }
        }
        None => (today.year(), today.month()),
    };
    let Some(first) = NaiveDate::from_ymd_opt(y, m, 1) else { eprintln!("kalends cal: bad month"); return 2 };
    let next = if m == 12 { NaiveDate::from_ymd_opt(y + 1, 1, 1) } else { NaiveDate::from_ymd_opt(y, m + 1, 1) };
    let days = (next.unwrap_or(first) - first).num_days();
    let evs = events_in(store, first, first + Duration::days(days - 1));

    println!("     {}", first.format("%B %Y"));
    println!("Mo Tu We Th Fr Sa Su");
    // Monday-first, matching the locale this desktop uses.
    let lead = first.weekday().num_days_from_monday();
    let mut line = "   ".repeat(lead as usize);
    for d in 0..days {
        let date = first + Duration::days(d);
        let busy = evs.iter().any(|e| e.on_day(date));
        let mark = if date == today { '*' } else if busy { '.' } else { ' ' };
        line.push_str(&format!("{:>2}{}", date.day(), mark));
        if date.weekday().num_days_from_monday() == 6 { println!("{}", line.trim_end()); line.clear(); }
    }
    if !line.trim().is_empty() { println!("{}", line.trim_end()); }
    println!("\n  * today   . has events");
    0
}

// ── formatting ──────────────────────────────────────────────────────────────

fn time_label(e: &Event) -> String {
    if e.all_day { "all day".to_string() }
    else { format!("{}", e.start.format("%H:%M")) }
}
fn truncate(s: &str, n: usize) -> String {
    if s.chars().count() <= n { return s.to_string(); }
    let mut out: String = s.chars().take(n.saturating_sub(1)).collect();
    out.push('…');
    out
}
/// Escape codes only when a terminal is actually attached — piping `agenda`
/// into anything otherwise gets literal \x1b[2m in the text.
fn dim(s: &str) -> String {
    use std::io::IsTerminal;
    if std::io::stdout().is_terminal() { format!("\x1b[2m{s}\x1b[0m") } else { s.to_string() }
}

// ── edit ────────────────────────────────────────────────────────────────────

fn cmd_edit(store: &Store, args: &[String], json: bool) -> i32 {
    let Some(prefix) = args.get(1).filter(|p| !p.starts_with("--")) else {
        eprintln!("kalends edit: needs an id"); return 2;
    };
    let all = store.load();
    let old = match store.find_by_prefix(&all, prefix) {
        Ok(e) => e.clone(),
        Err(msg) => { eprintln!("kalends edit: {msg}"); return 1 }
    };

    // extra and rrule are carried over untouched: extra holds every property
    // this program does not model, and dropping it would rewrite the file lossily.
    let mut ev = old.clone();
    let mut touched = false;

    if let Some(v) = flag(args, "--title") { ev.summary = v; touched = true; }
    if let Some(v) = flag(args, "--cal") { ev.calendar = v; touched = true; }
    if let Some(v) = flag(args, "--loc") { ev.location = v; touched = true; }
    if let Some(v) = flag(args, "--note") { ev.description = v; touched = true; }
    if has(args, "--clear-loc") { ev.location.clear(); touched = true; }
    if has(args, "--clear-note") { ev.description.clear(); touched = true; }

    // Shape first, then position, then span: --for used to be applied before
    // --all-day rewrote start, which left a converted event 24h long.
    let became_all_day = has(args, "--all-day") && !ev.all_day;
    let became_timed = has(args, "--no-all-day") && ev.all_day;
    if became_all_day { ev.all_day = true; touched = true; }
    if became_timed { ev.all_day = false; touched = true; }

    let old_span = ev.end - ev.start;
    if let Some(v) = flag(args, "--at") {
        match parse_when(&v) {
            Some(dt) => { ev.start = dt; ev.end = dt + old_span; touched = true; }
            None => { eprintln!("kalends edit: cannot read --at '{v}'"); return 2 }
        }
    }
    if ev.all_day { ev.start = ev.start.date().and_hms_opt(0, 0, 0).unwrap(); }

    match flag(args, "--for") {
        Some(v) => match parse_duration(&v) {
            Some(d) => { ev.end = ev.start + d; touched = true; }
            None => { eprintln!("kalends edit: cannot read --for '{v}'"); return 2 }
        },
        // No explicit span, so pick one the new shape can hold.
        None if became_all_day => {
            let days = (ev.end - ev.start).num_days().max(1);
            ev.end = ev.start + Duration::days(days);
        }
        None if became_timed => ev.end = ev.start + Duration::hours(1),
        None => {}
    }

    if !touched { eprintln!("kalends edit: nothing to change"); return 2 }
    if ev.end < ev.start { eprintln!("kalends edit: end is before start"); return 2 }

    // A calendar change is a move: the old file must go, or the event exists twice.
    if ev.calendar != old.calendar {
        if let Err(e) = store.delete(&old) { eprintln!("kalends edit: {e}"); return 1 }
    }
    match store.save(&ev) {
        Ok(p) => {
            if json { println!("{}", serde_json::to_string(&ev).unwrap_or_default()); }
            else {
                println!("Edited {}  {}  [{}]", time_label(&ev), ev.summary,
                         &ev.uid[..8.min(ev.uid.len())]);
                eprintln!("  {}", store::path_display(&p));
            }
            0
        }
        Err(e) => { eprintln!("kalends edit: {e}"); 1 }
    }
}

// ── import / export ─────────────────────────────────────────────────────────

fn cmd_export(store: &Store, args: &[String]) -> i32 {
    let mut evs = store.load();
    if let Some(c) = flag(args, "--cal") { evs.retain(|e| e.calendar == c); }
    let from = flag(args, "--from").and_then(|v| parse_date(&v));
    let to = flag(args, "--to").and_then(|v| parse_date(&v));
    if let Some(f) = from { evs.retain(|e| e.end.date() >= f); }
    if let Some(t) = to { evs.retain(|e| e.start.date() <= t); }
    evs.sort_by_key(|e| e.start);
    print!("{}", ics::serialize(&evs, "kalends"));
    eprintln!("{} event{}", evs.len(), if evs.len() == 1 { "" } else { "s" });
    0
}

fn cmd_import(store: &Store, args: &[String], json: bool) -> i32 {
    let Some(path) = args.get(1).filter(|p| !p.starts_with("--")) else {
        eprintln!("kalends import: needs a file"); return 2;
    };
    let text = match std::fs::read_to_string(path) {
        Ok(t) => t,
        Err(e) => { eprintln!("kalends import: {path}: {e}"); return 1 }
    };
    let cal = flag(args, "--cal").unwrap_or_else(|| "personal".into());
    let incoming = ics::parse(&text, &cal);
    if incoming.is_empty() { eprintln!("kalends import: no VEVENTs in {path}"); return 1 }

    let existing = store.load();
    let force = has(args, "--force");
    let (mut added, mut skipped, mut failed) = (0usize, 0usize, 0usize);

    for mut ev in incoming {
        ev.calendar = cal.clone();
        // A UID collision means the same event, so re-importing a file is a
        // no-op rather than a duplicate — that is what makes import re-runnable.
        if !force && existing.iter().any(|e| e.uid == ev.uid) { skipped += 1; continue }
        if ev.uid.trim().is_empty() { ev.uid = store::new_uid("kalends"); }

        match store.save(&ev) { Ok(_) => added += 1, Err(_) => failed += 1 }
    }
    if json {
        // Through serde, not format!: a calendar name containing a quote
        // produced output that jq refused to parse.
        println!("{}", serde_json::json!({
            "added": added, "skipped": skipped, "failed": failed, "calendar": cal
        }));
    } else {
        println!("Imported {added} into {cal}  ({skipped} already present, {failed} failed)");
    }
    if failed > 0 { 1 } else { 0 }
}

// ── status ──────────────────────────────────────────────────────────────────

fn cmd_status(store: &Store, json: bool) -> i32 {
    let evs = store.load();
    let cals = store.calendars();
    let today = ics::today();
    let upcoming = evs.iter().filter(|e| e.end.date() >= today).count();
    let next = evs.iter().filter(|e| e.end >= ics::now_local()).min_by_key(|e| e.start);

    if json {
        // Built by serde end to end. These two objects used to be assembled
        // with format!, so a calendar name containing a quote emitted JSON
        // that jq refused to parse.
        let per: Vec<serde_json::Value> = cals.iter().map(|c| serde_json::json!({
            "name": c.name,
            "events": evs.iter().filter(|e| e.calendar == c.name).count(),
        })).collect();
        println!("{}", serde_json::json!({
            "root": store::path_display(&store.root),
            "total": evs.len(),
            "upcoming": upcoming,
            "calendars": per,
            "next": next,
            "sync": read_sync_state(),
        }));
        return 0;
    }

    println!("store      {}", store::path_display(&store.root));
    println!("events     {} total, {} today or later", evs.len(), upcoming);
    for c in &cals {
        println!("  {:<10} {}", c.name, evs.iter().filter(|e| e.calendar == c.name).count());
    }
    match next {
        Some(e) => println!("next       {}  {}", time_label(e), e.summary),
        None => println!("next       nothing scheduled"),
    }

    // Sync, if it has ever run. A calendar that quietly stopped syncing looks
    // exactly like one with nothing new, which is the failure worth naming.
    let s = read_sync_state();
    match s.get("at").and_then(|v| v.as_str()) {
        // No run recorded is not the same as nothing set up: saying
        // "not configured" to someone who has just written the config sends
        // them to configure it again instead of to `kalends sync`.
        None if vdirsyncer_config_path().exists() =>
            println!("sync       configured, never run — `kalends sync --discover`, then `kalends sync`"),
        None => println!("sync       not configured — `kalends sync --init`"),
        Some(at) => {
            let ok = s.get("ok").and_then(|v| v.as_bool()).unwrap_or(false);
            println!("sync       {} at {}", if ok { "ok" } else { "FAILED" }, &at[..16.min(at.len())]);
            if !ok {
                if let Some(d) = s.get("detail").and_then(|v| v.as_str()) {
                    for line in d.lines().take(3) { println!("             {line}"); }
                }
            }
        }
    }
    0
}

// ── remind ──────────────────────────────────────────────────────────────────

/// Events already notified, so a timer firing every minute does not announce
/// the same meeting sixty times. Keyed on uid AND start, because a recurring
/// event's occurrences all share a uid.
fn fired_path() -> std::path::PathBuf {
    let base = std::env::var("XDG_STATE_HOME")
        .map(std::path::PathBuf::from)
        .unwrap_or_else(|_| std::path::PathBuf::from(
            std::env::var("HOME").unwrap_or_default()).join(".local/state"));
    base.join("kalends").join("fired.json")
}

fn load_fired() -> std::collections::HashMap<String, String> {
    std::fs::read_to_string(fired_path()).ok()
        .and_then(|t| serde_json::from_str(&t).ok())
        .unwrap_or_default()
}

fn save_fired(map: &std::collections::HashMap<String, String>) {
    let p = fired_path();
    let Some(dir) = p.parent() else { return };
    if std::fs::create_dir_all(dir).is_err() { return; }
    let Ok(text) = serde_json::to_string(map) else { return };
    let tmp = p.with_extension("tmp");
    if std::fs::write(&tmp, text).is_ok() { let _ = std::fs::rename(&tmp, &p); }
}

/// Fires a desktop notification for anything starting within the lead window.
///
/// Meant for a systemd user timer, not a resident process: it must keep
/// working when the window is closed, which is M6's whole "done when", and a
/// per-minute CLI run costs about as much as one keystroke.
fn cmd_remind(store: &Store, args: &[String], json: bool) -> i32 {
    let lead: i64 = flag(args, "--lead").and_then(|v| v.parse().ok()).unwrap_or(10);
    let dry = has(args, "--dry-run");
    let now = ics::now_local();
    let today = ics::today();

    // A two-day window covers a lead time that crosses midnight without
    // loading a year of events every minute.
    let evs = events_in(store, today, today + Duration::days(1));
    let mut fired = load_fired();
    let mut sent = 0usize;

    for e in evs.iter() {
        let mins = (e.start - now).num_minutes();
        // Already started, or still too far off.
        if mins < 0 || mins > lead { continue; }
        let key = format!("{}@{}", e.uid, e.start);
        if fired.contains_key(&key) { continue; }

        let when = if e.all_day { "today".to_string() }
                   else if mins <= 0 { "now".to_string() }
                   else { format!("in {mins} min") };
        let body = match (e.location.is_empty(), e.calendar.is_empty()) {
            (false, _) => format!("{when}  ·  {}", e.location),
            (true, false) => format!("{when}  ·  {}", e.calendar),
            _ => when.clone(),
        };

        if !dry {
            let _ = std::process::Command::new("notify-send")
                // appointment-soon, not calendar: the latter resolves to a
                // MIMETYPE icon — a document with a date printed on it, which
                // is both wrong and always says the same day.
                .args(["-a", "Kalends", "-i", "appointment-soon", "-u", "normal",
                       &e.summary, &body])
                .status();
        }
        fired.insert(key, e.start.to_string());
        sent += 1;
        if json { println!("{}", serde_json::json!({ "notified": e.summary, "in": mins })); }
        else if dry { println!("would notify: {}  ({when})", e.summary); }
    }

    // Forget anything older than a day, so the file does not grow forever.
    let cutoff = (now - Duration::days(1)).to_string();
    fired.retain(|_, started| started.as_str() > cutoff.as_str());
    save_fired(&fired);

    if json && sent == 0 { println!("{}", serde_json::json!({ "notified": 0 })); }
    0
}

// ── sync ────────────────────────────────────────────────────────────────────

/// Where the last sync's outcome is recorded, so `status` can answer "is my
/// calendar actually up to date" without running a sync to find out.
fn sync_state_path() -> std::path::PathBuf {
    let base = std::env::var("XDG_STATE_HOME")
        .map(std::path::PathBuf::from)
        .unwrap_or_else(|_| std::path::PathBuf::from(
            std::env::var("HOME").unwrap_or_default()).join(".local/state"));
    base.join("kalends").join("sync.json")
}

fn read_sync_state() -> serde_json::Value {
    std::fs::read_to_string(sync_state_path()).ok()
        .and_then(|t| serde_json::from_str(&t).ok())
        .unwrap_or_else(|| serde_json::json!({}))
}

fn write_sync_state(ok: bool, detail: &str) {
    // On the transition from working to broken, say so once. A sync that runs
    // every five minutes and fails quietly looks exactly like a calendar with
    // nothing new in it — which is how a week goes by before anyone notices.
    // Once, not every five minutes: a notification that repeats 288 times a
    // day is one nobody reads.
    let was_ok = read_sync_state().get("ok").and_then(|v| v.as_bool()).unwrap_or(true);
    if !ok && was_ok {
        let hint = if detail.contains("invalid_grant") || detail.contains("Token has been expired") {
            "Authorisation expired. Run: kalends sync --discover"
        } else {
            "Run `kalends status` for the reason."
        };
        let _ = std::process::Command::new("notify-send")
            .args(["-a", "Kalends", "-i", "appointment-soon", "-u", "normal",
                   "Calendar sync stopped", hint])
            .status();
    }

    let p = sync_state_path();
    let Some(dir) = p.parent() else { return };
    if std::fs::create_dir_all(dir).is_err() { return; }
    let state = serde_json::json!({
        "at": ics::now_local().to_string(),
        "ok": ok,
        "detail": detail,
    });
    let Ok(text) = serde_json::to_string(&state) else { return };
    let tmp = p.with_extension("tmp");
    if std::fs::write(&tmp, text).is_ok() { let _ = std::fs::rename(&tmp, &p); }
}

/// Runs the configured sync tool and records what happened.
///
/// Exit codes mean something, because a timer that always exits 0 is a timer
/// that hides its own failures:
///   0  synced, or nothing to do
///   1  the sync tool failed — details in `kalends status`
///   3  no sync configured yet
fn cmd_sync(args: &[String], json: bool) -> i32 {
    // --init first: complaining that sync is unconfigured to someone who is
    // right now configuring it is noise.
    if has(args, "--init") { return cmd_sync_init(); }
    let cfg = vdirsyncer_config_path();
    if !cfg.exists() {
        eprintln!("kalends: no sync configured. Run `kalends sync --init` and see\n  {}",
                  store::path_display(&cfg));
        return 3;
    }

    let which = if has(args, "--discover") { "discover" } else { "sync" };
    let out = std::process::Command::new("vdirsyncer")
        .args(["-c", &cfg.to_string_lossy(), which])
        .output();

    match out {
        Ok(o) if o.status.success() => {
            write_sync_state(true, "");
            if json { println!("{}", serde_json::json!({ "ok": true })); }
            else { print!("{}", String::from_utf8_lossy(&o.stderr)); }
            0
        }
        Ok(o) => {
            // vdirsyncer reports progress AND errors on stderr, and the tail
            // is often an HTTP access-log line rather than the failure — this
            // hid "enable the CalDAV API" behind a 200 OK for four rounds.
            let err = String::from_utf8_lossy(&o.stderr);
            let mut tail = error_lines(&err);
            if tail.is_empty() {
                tail = err.lines().rev().take(6).collect::<Vec<_>>()
                    .into_iter().rev().collect::<Vec<_>>().join("\n");
            }
            // vdirsyncer keeps the server's own explanation for -vdebug, so
            // the one run that failed is worth repeating to read it.
            if let Some(reason) = google_reason(&cfg, which) {
                tail = format!("{tail}\n{reason}");
            }
            write_sync_state(false, &tail);
            if json { println!("{}", serde_json::json!({ "ok": false, "error": tail })); }
            else {
                eprintln!("{tail}");
                // The commonest first-run failure, and the message Google
                // gives is about the wrong thing: it reads as a permission
                // problem when it is a consent-screen setting.
                if err.contains("access_denied") || err.contains("403") {
                    eprintln!("\nGoogle refused the sign-in. In the Cloud console, under\n\
                               APIs & Services > OAuth consent screen (Audience), either\n\
                               add this address under Test users, or publish the app.\n\
                               Publishing is the one to pick: a Testing app expires its\n\
                               refresh token every 7 days and sync dies weekly.");
                }
            }
            1
        }
        Err(e) => {
            let msg = format!("cannot run vdirsyncer: {e}");
            write_sync_state(false, &msg);
            eprintln!("kalends: {msg}");
            1
        }
    }
}


/// The lines of vdirsyncer's output that are actually about the failure.
fn error_lines(err: &str) -> String {
    let keep: Vec<&str> = err.lines()
        .filter(|l| {
            let l = l.trim_start();
            l.starts_with("error:") || l.starts_with("critical:") || l.starts_with("warning:")
        })
        .filter(|l| !l.contains("use `-vdebug`"))
        .collect();
    keep.join("\n")
}

/// Google puts the useful half of an error — "enable this API", "wrong
/// scope" — in an XML body vdirsyncer only prints under -vdebug. Rerunning
/// once, after a failure, is cheaper than the person not knowing why.
fn google_reason(cfg: &std::path::Path, which: &str) -> Option<String> {
    let o = std::process::Command::new("vdirsyncer")
        .args(["-vdebug", "-c", &cfg.to_string_lossy(), which])
        .output().ok()?;
    let text = String::from_utf8_lossy(&o.stderr);
    let start = text.find("<internalReason>")? + "<internalReason>".len();
    let end = text[start..].find("</internalReason>")? + start;
    let reason = text[start..end].trim();
    if reason.is_empty() { return None; }
    Some(format!("\nGoogle says:\n  {reason}"))
}

fn vdirsyncer_config_path() -> std::path::PathBuf {
    let base = std::env::var("XDG_CONFIG_HOME")
        .map(std::path::PathBuf::from)
        .unwrap_or_else(|_| std::path::PathBuf::from(
            std::env::var("HOME").unwrap_or_default()).join(".config"));
    base.join("kalends").join("vdirsyncer.conf")
}

/// Writes a vdirsyncer config pointed at this store.
///
/// The config is generated rather than hand-written so it can never drift from
/// where the store actually is, which is the failure that turns "sync" into
/// "silently syncing an empty directory".
fn cmd_sync_init() -> i32 {
    let store = Store::open(KALENDS);
    let cfg = vdirsyncer_config_path();
    if cfg.exists() {
        eprintln!("kalends: {} already exists, leaving it alone",
                  store::path_display(&cfg));
        return 0;
    }
    let Some(dir) = cfg.parent() else { return 1 };
    if std::fs::create_dir_all(dir).is_err() { return 1 }

    let status = dir.join("vdirsyncer-status");
    let body = format!(r#"# Generated by `kalends sync --init`. Edit freely; it is not regenerated.
#
# Fill in client_id and client_secret from your Google Cloud OAuth client
# (Desktop app). The consent screen must be PUBLISHED, or Google expires the
# refresh token every 7 days and sync dies weekly.

[general]
status_path = "{status}"

[pair kalends]
a = "local"
b = "google"
collections = ["from a", "from b"]
# Google is authoritative for metadata; events themselves resolve newer-wins.
metadata = ["displayname", "color"]
conflict_resolution = "b wins"

[storage local]
type = "filesystem"
path = "{store}"
fileext = ".ics"

[storage google]
type = "google_calendar"
token_file = "{token}"
client_id = ""
client_secret = ""
"#,
        status = store::path_display(&status),
        store = store::path_display(&store.root),
        token = store::path_display(&dir.join("google-token.json")),
    );

    if std::fs::write(&cfg, body).is_err() {
        eprintln!("kalends: cannot write {}", store::path_display(&cfg));
        return 1;
    }
    println!("Wrote {}", store::path_display(&cfg));
    println!();
    println!("Next:");
    println!("  1. put your OAuth client_id and client_secret in that file");
    println!("  2. kalends sync --discover     (opens a browser, once)");
    println!("  3. kalends sync");
    0
}
