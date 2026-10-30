# Kalends — plan

A calendar for the `ii` desktop. Local-first, with a terminal client that is
as capable as the UI.

## 1. Why this and not KOrganizer / khal

- **KOrganizer** looks nothing like the shell and drags in half of Akonadi.
- **khal** is terminal-only; the panel can't use it.
- **The shell already has a Calendar tab** with no real backing store.

The gap is one store read by three faces: the sidebar tab, a real window, and
a terminal. That's the whole thesis. If it doesn't serve all three, it isn't
worth building.

## 2. Architecture

    kalends (Rust)  ──  one binary, three modes
      • CLI          kalends agenda / add / cal …
      • JSON         kalends --json …          ← the QML reads this
      • daemon       kalends daemon            ← reminders only

    kalends.qml     quickshell app, calls the binary and parses JSON
    modules/        month, week, day, agenda, year views

One binary, not a daemon plus a library, because the CLI and the UI must never
disagree about what an event is. The QML shells out the same way the shell
already does for `icon-color.sh` and `places.sh`.

**Store: vdir.** A directory per calendar, one `.ics` per event — the layout
`vdirsyncer` and `khal` already use — under
`${XDG_DATA_HOME:-~/.local/share}/kalends/calendars/`. A single `.ics` per
calendar is also read, for hand-made files and imports.

vdir is chosen for one reason: it is what the sync tools speak. Unmodelled
properties are preserved verbatim so a round-trip never destroys data written
by another client.

## 2b. Sync — designed for, built later

**Deferred on purpose.** The app is useful offline on day one, and sync needs
a Google Cloud project and a browser sign-in that only the user can do. What
is NOT deferred is the decision that makes it possible: the store is vdir, so
turning sync on later is a vdirsyncer config file, not a rewrite.

The design below stands; it is simply scheduled after the app works.

Kalends has **no network code at all**. Sync is vdirsyncer's job:

    phone ──▶ Google/Nextcloud/iCloud ──▶ vdirsyncer ──▶ local vdir ──▶ kalends

Building Google support in would mean OAuth2 (Basic Auth for CalDAV died in
2020), a client secret that cannot be secret in a desktop app, and refresh
tokens that expire **every 7 days** while the consent screen sits in Testing.
It would also bind the app to one provider. Through vdirsyncer the same code
works with any CalDAV server, and the phone keeps talking to whatever it
already talks to.

The cost is honest: vdirsyncer + Google needs a Google Cloud project set up
once, and the consent screen published to avoid the 7-day expiry.

### Staying synced, not just being syncable

"Runs vdirsyncer" is not sync. These four together are:

1. **On a timer.** A systemd *user* timer every 5 minutes —
   `kalends-sync.timer`, shipped by this project, not hand-rolled by you.
   Persistent=true so a laptop that was asleep catches up on wake.
2. **Push straight after a local write.** Any `add`/`edit`/`rm`, from the CLI
   or the UI, schedules a sync ~5s later (debounced, so a burst of edits is
   one sync). Your change is on the phone before you look at the phone.
3. **Pull when you look.** Opening the window or the sidebar tab triggers a
   sync if the last one is older than a minute. You never read stale data
   because you happened to open it between ticks.
4. **Failure is visible.** Last-sync time and the last error are part of the
   UI and of `kalends status`. A sync that has been broken for three days must
   be impossible not to notice — silent failure is how calendars lose people
   appointments.

**What "perfect" cannot mean.** Google can push changes to a public webhook;
a laptop has none. So the floor is the timer interval — a phone edit shows up
within ~5 minutes, a local edit goes out in ~5 seconds. Realtime inbound would
need a server we are not going to run.

**Conflicts.** vdirsyncer detects them per-event (another reason for vdir) and
`conflict_resolution` decides. Default here: remote wins for events the phone
also touched, and the losing copy is kept as a `.conflict` file rather than
discarded, so nothing is ever destroyed silently.

**Prerequisite, and it is not optional:** the Google consent screen must be
**published**, not left in Testing. In Testing the refresh token dies every 7
days and sync stops — which is the exact opposite of what you asked for.

## 3. Milestones

Each is independently useful; none is a prerequisite for using the last.

**M1 — the store and the terminal** *(no UI at all)*
- read/write VEVENT: timed, all-day, multi-day  *(ics.rs written)*
- `add`, `list`, `today`, `agenda`, `rm`, `cal` (month grid in the terminal)
- `--json` on every read command
- done when: an event added in the terminal survives a re-read and an
  external editor, and `cal` prints a correct month

**M5 — sync that stays synced** *(deferred by choice, see below)*
- vdirsyncer config generated and owned by this project
- `kalends sync` wrapper; timer unit; debounced push after every write
- `kalends status` — last sync, last error, per-calendar counts
- done when: an event added on the phone appears in `kalends today` within
  5 minutes untouched by hand, one added in the terminal reaches the phone,
  and killing the network shows an error rather than pretending success

**M2 — the window**
- month view, agenda side panel, jump to date, calendar show/hide
- reads M1's JSON; no write path yet
- done when: it renders a real month of real events and matches `agenda`

**M3 — editing**
- create/edit/delete from the UI, inline in the month cell and a full dialog
- done when: the UI and the CLI can each modify what the other created

**M4 — recurrence**
- RRULE: DAILY/WEEKLY/MONTHLY/YEARLY, COUNT/UNTIL/BYDAY/INTERVAL; EXDATE
- expansion in the core, so the CLI and UI agree by construction
- done when: a weekly event shows on the right days for a year, and editing
  one occurrence doesn't damage the series

**M6 — reminders and shell integration**
- `kalends daemon` fires notifications through the shell's notification service
- the `ii` sidebar Calendar tab and a dock widget read the same store
- done when: closing the app does not stop a reminder arriving

## 4. Terminal surface

    kalends today                      what's on today
    kalends agenda [--days N]          next N days, grouped
    kalends next                       the next event, one line (for a bar)
    kalends cal [YYYY-MM]              month grid, days with events marked
    kalends list --from D --to D       range
    kalends add "Title" --at "2026-09-27 14:00" --for 1h [--all-day]
                       [--cal work] [--loc "…"] [--note "…"] [--repeat weekly]
    kalends rm <uid-prefix>            by unique prefix, like git
    kalends edit <uid-prefix> --at …   same flags as add
    kalends import FILE|DIR            merge .ics
    kalends export --from D --to D     .ics to stdout
    kalends cals                       list calendars, colours, hidden state

Every read command takes `--json`. Dates accept `today`, `tomorrow`,
`YYYY-MM-DD`, `HH:MM`, and `YYYY-MM-DD HH:MM`. No natural-language parsing —
it is a rabbit hole and it guesses wrong at the worst moment.

## 5. UI

Month is the default. Week and day share one time-grid component. Agenda is a
flat list and is also what the sidebar tab embeds.

Rules, from the shell's own conventions:
- colours only from `Appearance` roles — **no hardcoded colours**, so it
  retints with the wallpaper
- rounding, spacing and font sizes from the `Appearance` ramps
- one motion curve (`Appearance.animation.elementMoveFast`)
- every view works at sidebar width (~440px) and at window width

## 6. Risks

| Risk | Handling |
|---|---|
| Recurrence is where calendars rot | Expand in the core only; the UI never computes dates |
| Timezones | Store UTC, display local, per-event TZID deferred to post-M5 |
| Shelling out per view could be slow | Measure at M2; a socket is the fallback, not the default |
| Data loss on write | Write to a temp file and rename; preserve unknown properties |
| Another client edits the same file | Re-read before write; last-writer-wins is acceptable for local-first |
| vdirsyncer writes while we do | One file per event means collisions are per-event, not per-calendar — a real reason to prefer vdir |

## 7. Decisions needed

1. **Reminders**: through the shell's notification service, or `notify-send`?
   The former looks native, the latter works with the shell closed.
2. **Sidebar tab**: replace the existing Calendar tab's content, or leave it
   and add a separate agenda widget?
3. **Scope of M1**: is a terminal-only first milestone acceptable, or do you
   want the window sooner even if it is read-only?
4. **Google project**: sync needs a Google Cloud project + a browser sign-in,
   and the consent screen **published** so tokens do not die weekly. Both are
   yours to do; I can write the exact steps. Say when and I will prepare the
   vdirsyncer config so it is a copy-paste plus one sign-in.
