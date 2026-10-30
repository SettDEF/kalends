# Kalends — tasks

Open work lives here, not in chat.

## Done
- [x] Project scaffold, name screened
- [x] Store: read/write VEVENT in a vdir, one file per event, atomic writes
- [x] CLI: `today` `agenda` `next` `cal` `list` `cals` `add` `rm` `where`
- [x] CLI: `edit` `import` `export` `status`
- [x] JSON output mode (`--json`)
- [x] Wired into the shell: `services/Kalends.qml` feeds the sidebar's
      Calendar tab; day cells show event dots. Verified against real events.

## Now
- [x] Click a day to select it; a popup lists that day's events, or says
      nothing is scheduled. The inline agenda strip was tried and reverted —
      it changed the grid's height.
- [x] Refresh when the store changes. `services/Kalends.qml` watches
      `.index.json` with a FileView. Two bugs had to be fixed to make that
      file a usable signal: reads were rewriting it every time (the shell then
      looped, killing its own query mid-output), and writes were not, so a
      sync went unnoticed. Now every mutating command re-indexes and reads
      leave it alone.

## M2 — sync — DONE 2026-09-26
- [x] vdirsyncer config template (Google + generic CalDAV)
- [x] `kalends sync` wrapper, exit codes that mean something
- [x] systemd user timer, 5 min, Persistent=true
- [x] Google OAuth working end to end. Traps hit, in order: the consent
      screen's test-user list is empty by default and the project OWNER is not
      on it; the CalDAV API is separate from the Calendar API and must be
      enabled too; `collections = ["from a", "from b"]` cannot work against
      Google, which will not create calendars, so collections are mapped by
      name; read-only calendars (the holidays feeds) need their own pair with
      `read_only = true` or one write attempt fails the whole sync.
- [x] Notifies once when sync breaks, so a silent failure is not mistaken
      for a quiet week. The app is deliberately left in Testing, so Google
      expires the refresh token every 7 days: expect the notification and
      run `kalends sync --discover`. Publishing (Branding page first) ends
      this; deferred by choice.
- [ ] debounced push after any write (CLI and UI)
- [ ] pull-on-open if last sync > 60s
- [ ] conflicts kept as .conflict files, never discarded

## Next
- [ ] Recurrence (RRULE): DAILY/WEEKLY/MONTHLY/YEARLY + COUNT/UNTIL/BYDAY
- [x] Week view (timeline, overlaps side by side, now line) and a full-window
      month view with event names; sidebar with a mini month, the day, and
      the calendars in their colours (2026-10-16)
- [ ] Day view; drag to move / resize in the week view
- [ ] Create/edit/delete from the UI
- [ ] Reminder daemon + notifications through the shell
- [ ] Search, jump to date

## Later
- [ ] CalDAV sync
- [ ] VTODO (tasks) — the shell already has a To Do tab to feed
- [ ] Per-event timezones

## Notes
- The binary is installed at `~/.local/bin/kalends`. quickshell inherits the
  compositor's PATH, which does NOT include it, so the service resolves the
  absolute path once at startup rather than calling a bare `kalends`.
- `KALENDS_HOME` overrides the store root — use it for testing so real data
  is never touched.
