# DigiLife — Flutter app

A private, on-device daily-utility app: reminders, planner, expenses, health,
notes & lists, memberships, bills and a document vault.

Built to the specification in `LifeOS_PRD.docx` (in the parent folder). Every
screen from the approved mockups is implemented, and each file is annotated
with the PRD section it satisfies (e.g. `// PRD 4.2 AC1 — ...`).

---

## Running the app (first time)

You need Flutter installed once: <https://docs.flutter.dev/get-started/install>

Then, from a terminal **inside this `lifeos` folder**:

```bash
flutter pub get       # download the two dependencies
flutter run -d chrome # fastest way to see it — opens in your browser
```

Other ways to run it:

| Command | What it does |
|---|---|
| `flutter run -d chrome` | Runs in Chrome. No emulator needed — best for a first look. |
| `flutter run` | Runs on a connected phone or a running emulator. |
| `flutter emulators --launch <id>` | Starts an Android emulator (`flutter emulators` lists them). |
| `flutter test` | Runs the 35 business-logic tests. |
| `flutter analyze` | Static analysis — should report no issues. |
| `flutter build apk` | Builds an installable Android APK. |

While the app is running, press **`r`** in the terminal for hot reload
(changes appear in under a second) or **`R`** for a full restart.

---

## What you can actually do in the app

It ships with realistic sample data, so every screen is populated on first
launch. Things worth trying:

- **Home** — tap a stat card's module tile; add water with `+250 ml` and watch
  Home and Reminders stay in sync; tap a streak card to open its heatmap.
- **Reminders** — swipe a row **right** to mark done, **left** for snooze/delete;
  **long-press** for the full menu (duplicate, skip today, delete). Create a
  reminder and pick **Force confirm** to see the platform warning.
- **Planner** — switch Plan / Day / Week; the Day view draws a live "Now" line.
- **Expenses** — switch months with the arrows at the bottom; open Budgets to
  see the over-budget banner; Analytics has the 6-month trend and CSV export.
- **Health** — open a report to see markers scored against normal ranges;
  log today's mood in the Wellness log; export a doctor report from Vitals.
- **More tab** — Lists, Notes, Memberships, Bills, Document vault (try opening
  a locked document), My progress, Settings, and global search.
- **Clock** (More tab) — one screen holding two sections. Set an alarm with
  repeat days and an alert tier; or use the stopwatch with laps. Start the
  stopwatch, switch to the Alarm section and back — it keeps running.
- **Settings** — switch Theme to **Dark** to see the full dark palette.

---

## Project structure

```
lib/
  main.dart                 app entry, registers all stores
  app.dart                  MaterialApp + theming
  core/
    theme/                  colour palette (from the mockups) + light/dark themes
    utils/
      date_x.dart           date formatting, rupee formatting
      streak_calculator.dart ONE streak implementation shared by every screen
    widgets/
      common.dart           cards, chips, banners, empty states, sheets
      module_header.dart    the coloured module headers + tab strips
      alert_type_selector.dart  THE shared 3-tier alert component
  data/
    models/                 plain data classes (+ the business rules on them)
    stores/                 ChangeNotifier stores, one per domain, seeded
  features/
    home/ reminders/ planner/ expenses/ health/ clock/
    lists_notes/ memberships/ bills/ documents/ settings/ search/ shell/
test/
  business_logic_test.dart  35 tests covering the PRD acceptance criteria
  clock_test.dart           28 tests for alarm scheduling and stopwatch maths
```

### Architecture notes

- **State**: `provider` + `ChangeNotifier`. Each module has one store; screens
  read from the owning store rather than keeping their own copy, so Home can
  never disagree with the module it mirrors (PRD 1.1).
- **Money** is stored in paise as integers to avoid floating-point rounding
  errors, and only converted to rupees for display.
- **Streaks** are computed in exactly one place (`StreakCalculator`) and reused
  by Home, Planner and My Progress, so the numbers cannot drift apart (PRD G.5).
- **Data is in-memory** and re-seeded on each launch. The stores are already
  isolated behind a repository-style API, so swapping in `sqflite`/`drift` for
  real persistence means changing the stores only — no screen changes.

---

## How the PRD's open gaps were resolved

The requirements document flagged nine items needing a decision. Each is now
implemented, and marked in the code with the gap number:

| Gap | Decision taken |
|---|---|
| 1 · Lists & Notes merge | Kept as two modules (different data shapes) but cross-linked with a one-tap header button, plus one global search across both. |
| 2 · Per-document lock | Implemented — an optional per-document biometric/PIN lock on top of the app-wide lock. |
| 3 · Any file type | Implemented — file picker accepts PDF, images, Word, Excel, text and archives. |
| 4 · Bottom navigation | Four fixed tabs (Home, Reminders, Planner, Expenses) plus a **More** hub for the other six modules, each with a live badge. |
| 5 · Planner Week view | Designed and built. |
| 6 · Event/Appt/Task fields | Fully specified for all four planner types. |
| 7 · Transfer/Recurring fields | Transfer takes a destination account; Recurring takes a cycle. |
| 8 · Undecided behaviours | "Skip today" preserves the streak; split expenses attribute only your share; re-logging wellness updates with confirmation; marker range bounds are inclusive; note category is single-select. |
| 9 · Dark mode | Full dark palette implemented and switchable in Settings. |

Also added from the PRD's recommended list: **global search** across all
modules, and a **weekly insights digest** toggle.

---

## Known limitations

- Data does not persist between launches yet (see architecture note above).
- Notifications, biometric auth, OCR receipt/report scanning and file
  attachment are wired through the UI with clear behaviour, but call
  placeholder implementations — they need platform plugins
  (`flutter_local_notifications`, `local_auth`, `google_mlkit_text_recognition`,
  `file_picker`) to talk to the real OS.
- Force Confirm cannot be made truly un-dismissable on iOS; the app discloses
  this at the point the user selects it, as required by PRD 2.3.
# lifeos2
