# Kalends

A calendar for this desktop: a quickshell/QML app that matches the `ii` shell,
and a terminal client that can do everything the UI can.

The name is record vocabulary (a kalends is what the record turns on).
Screened CLEAR on the US trademark register 2026-09-26; the EU and national
registers have NOT been checked, so treat it as a working name until they are.

## Why another calendar

KOrganizer is heavy and looks nothing like the shell. `khal` is terminal-only.
Nothing local-first gives you the same data from a panel, a window and a
terminal, which is the whole point here:

- the `ii` sidebar's Calendar tab should read the same events as the app
- `kalends agenda` in a terminal should be the same truth
- no account, no server, no network required to open your own calendar

## Shape

    kalends.qml      the app (quickshell)
    modules/         QML views — month, week, day, agenda, year
    kalendsd/        Rust: the store, the CLI, and the reminder daemon
    packaging/       desktop entry, icon

One Rust binary is both the CLI and the daemon (`kalends daemon`), and the QML
calls it and reads JSON — the same way the shell already shells out to scripts.

## Store

Local iCalendar. One `.ics` per calendar under
`${XDG_DATA_HOME:-~/.local/share}/kalends/calendars/`, so the data is plain
text, greppable, syncable with anything, and survives this project.

## Planned use cases

Events        timed, all-day, multi-day, recurring (RRULE), location, notes, URL
Calendars     several, each with a colour, individually shown or hidden
Views         month, week, day, agenda, year; jump to date; search
Reminders     desktop notifications via the shell, with snooze
Terminal      add, list, agenda, today, next, edit, rm, move, import, export,
              and `cal` — a month grid in the terminal
Import        .ics files and directories; export any range
Integration   the shell's Calendar tab and the dock read the same store
Later         CalDAV sync, timezones per event, attachments, tasks (VTODO)

## Status

Scaffold. See TASKS.md.
