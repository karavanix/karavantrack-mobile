# KaravanTrack Mobile — Richer Status Flow & UX Redesign

## Context

The current 3-tab design (Pending / Active / History) has three core UX failures:
1. Accepting a load makes it "disappear" from the Pending tab — it silently moves to the Active tab, confusing drivers
2. Action buttons are buried inside Load Details — requires an extra navigation tap for every action
3. The Active tab is pointless since a driver can only have ONE active load at a time

The new backend API (carriers.json) also introduces 4 new intermediate statuses that the current code doesn't support at all: `picking_up`, `picked_up`, `dropping_off`, `dropped_off`.

**Goal:** Single-screen home with a prominent active-load panel, inline action buttons, and a dedicated History screen. Full 7-step status pipeline with a visual stepper widget.

---

## New Status Pipeline

| Step | Backend string | Enum | Action to advance |
|------|---------------|------|-------------------|
| 0 | `assigned` | `assigned` | Accept Load |
| 1 | `accepted` | `accepted` | Begin Pickup |
| 2 | `picking_up` | `pickingUp` | Confirm Cargo Loaded |
| 3 | `picked_up` | `pickedUp` | Start Transit |
| 4 | `in_transit` | `inTransit` | Begin Dropoff |
| 5 | `dropping_off` | `droppingOff` | Confirm Delivery |
| 6 | `dropped_off` | `droppedOff` | (terminal — awaits backend confirmation) |

---

## New Screen Architecture

```
MainShell — bottom nav: [LOADS] [HISTORY] [SETTINGS]
  ├── DriverHomeScreen        ← redesigned, no tabs
  ├── LoadHistoryScreen       ← new screen
  ├── LoadDetailsScreen       ← redesigned, merged with ActiveLoadScreen
  └── SettingsScreen          ← unchanged
```

**DriverHomeScreen (no tabs):**
- Internet banner (if offline)
- **Active Load Card** (top, always visible if active load exists):
  - Title + reference ID + status chip
  - `StatusStepper` widget (6 nodes, current step highlighted with pulse animation)
  - GPS/network status pills row (reuse existing `StatusPill`)
  - Full-width contextual action button for next step
  - Tap card body → `LoadDetailsScreen`
- **"Pending Loads" section header + count**
  - `PendingLoadCard` list: pickup/dropoff + Accept button inline on each card
  - Accept button shows per-card loading spinner (not global)
  - Tap card body → `LoadDetailsScreen`
- Empty state when no loads at all

**LoadHistoryScreen (new):**
- AppBar: "History"
- `ListView` of completed/confirmed/cancelled load cards
- Card: title, dropoff address, completion date, status chip
- Tap → `LoadDetailsScreen` (read-only, no action button)

**LoadDetailsScreen (redesigned):**
- AppBar: back arrow + load title
- Header: title, reference ID, status chip
- `StatusStepper` (full mode — with step labels)
- Info card: pickup address, dropoff address, description, scheduled dates
- Contextual action button (renders only when `status.nextActionKey != null`)
  - Shows per-load loading spinner; no `Navigator.pop()` after action — stepper re-renders in-place via `ListenableBuilder`
- "Status History" collapsible (`ExpansionTile`): timeline of `from_status → to_status` entries from `history[]` in `LoadDetailResponse`
  - Requires separate `GET /loads/{id}` fetch in `initState` (store has `LoadResponse`, detail needs `LoadDetailResponse`)

**active_load_screen.dart — deleted.** All navigation to it is replaced by `LoadDetailsScreen`.

---

## Critical Files to Modify

### 1. `/lib/models/load.dart`
- Add 4 new `LoadStatus` values: `pickingUp`, `pickedUp`, `droppingOff`, `droppedOff`
- Update `fromString()` for new backend strings (`"picking_up"`, `"picked_up"`, `"dropping_off"`, `"dropped_off"`)
- Update `isActive` getter to cover all 6 post-accept statuses (including `droppedOff` — GPS still runs)
- Add `stepIndex` computed property (returns 0–5 for the 6 active statuses, -1 otherwise)
- Add `nextActionKey` nullable property returning action label key per status (null for terminal)
- Add `LoadHistoryItem` model class (maps `query.HistoryResponse` from API)
- Add `history` field to `LoadItem`, parsed from `LoadDetailResponse`

### 2. `/lib/services/api_service.dart`
- Add 4 new methods (all follow identical pattern to existing `acceptLoad`/`startLoad`):
  - `beginPickup(id)` → `POST /loads/{id}/pickup/begin`
  - `confirmPickup(id)` → `POST /loads/{id}/pickup/confirm`
  - `beginDropoff(id)` → `POST /loads/{id}/dropoff/begin`
  - `confirmDropoff(id)` → `POST /loads/{id}/dropoff/confirm`
- Rename existing `completeLoad()` → `confirmDropoff()` (maps to new endpoint)

### 3. `/lib/store/app_store.dart`
- Replace `bool isLoading` with `Set<String> _loadingIds` for per-card loading state
  - Add `bool isLoadingId(String id)` and keep `bool get isLoading` as `_loadingIds.isNotEmpty`
- Add 4 new action methods: `beginPickup`, `confirmPickup`, `beginDropoff`, `confirmDropoff`
  - All follow existing pattern: add to `_loadingIds`, call API, `fetchLoads()`, remove from set, `notifyListeners()`
- Rename `completeLoad()` → `confirmDropoff()`
- **Remove** the auto-transition block in `_deliverPoint()` (`accepted → inTransit` on speed > 1 km/h) — this workaround skips the new intermediate steps and would corrupt the backend audit trail

### 4. `/lib/screens/driver_home_screen.dart`
- Full rewrite — remove `TabController`, `TabBar`, `TabBarView`, `_ActiveLoadTab`, `_LoadsList`
- New structure: `CustomScrollView` with `SliverToBoxAdapter` sections (Active panel → Pending header → Pending list → empty state)
- `_ActiveLoadPanel`: card with primary-tinted border, stepper, GPS pills, action button
- `PendingLoadCard`: rewritten with inline Accept button + per-card loading state

### 5. `/lib/screens/load_details_screen.dart`
- Convert to `StatefulWidget`; add `_fetchDetail()` in `initState` to get `LoadDetailResponse` (for history)
- Replace existing layout with: header card → `StatusStepper` → info card → action button → history timeline
- Action button calls appropriate `store.beginPickup/confirmPickup/...` based on `load.status`
- No `Navigator.pop()` after action — reactive re-render handles it

### 6. `/lib/screens/active_load_screen.dart`
- **Delete file** and remove all imports/references (only `driver_home_screen.dart` currently imports it)

### 7. `/lib/screens/load_history_screen.dart` ← **new file**
- Simple `StatelessWidget`/`ListenableBuilder` reading `store.finishedLoads`
- `ListView` of history cards; tap → `LoadDetailsScreen`

### 8. `/lib/screens/main_shell.dart`
- Add History as the second bottom nav item (between Loads and Settings)
- Update `_screens` list and `BottomNavigationBar` items

### 9. `/lib/widgets/status_stepper.dart` ← **new file**
- `StatusStepper(currentStepIndex: int, compact: bool)`
- 6 step nodes connected by lines; completed = green, current = primary + pulse animation, pending = border grey
- `compact: true` = 20px nodes, no labels (home screen active card)
- `compact: false` = 28px nodes, step labels below (details screen)

### 10. `/lib/widgets/load_status_chip.dart`
- Add color cases for `pickingUp` (orange), `pickedUp` (blue), `droppingOff` (amber-orange), `droppedOff` (green)

### 11. `/lib/l10n/` (all 3 locale files)
- Add status label keys: `statusPickingUp`, `statusPickedUp`, `statusDroppingOff`, `statusDroppedOff`
- Add action button keys: `actionBeginPickup`, `actionConfirmPickup`, `actionStartTransit`, `actionBeginDropoff`, `actionConfirmDropoff`
- Update `loadAccepted` message to remove reference to "Active tab"

---

## Implementation Sequence

**Phase 1 — Data layer** (no UI changes yet, independently testable)
1. `load.dart` — new enum values, `stepIndex`, `nextActionKey`, `LoadHistoryItem`
2. `api_service.dart` — 4 new methods, rename `completeLoad`
3. `app_store.dart` — per-load loading set, 4 new methods, remove auto-transition

**Phase 2 — New widgets**
4. `status_stepper.dart` — new widget
5. `load_status_chip.dart` — new status colors

**Phase 3 — Screen redesigns**
6. `driver_home_screen.dart` — full rewrite (no tabs)
7. `load_history_screen.dart` — new file
8. `main_shell.dart` — add History to bottom nav
9. `load_details_screen.dart` — add stepper, action button, history timeline
10. Delete `active_load_screen.dart`

**Phase 4 — i18n + cleanup**
11. Add new translation keys in all 3 locales
12. Remove dead references, run `flutter analyze`

---

## Verification

1. `flutter analyze` — zero errors after all changes
2. Hot restart — home screen shows active load card at top if `/loads/active` returns a load; pending list below
3. Accept a pending load → it moves to the active panel (does NOT disappear); Accept button shows per-card spinner
4. Tap active load card body → `LoadDetailsScreen` opens with correct stepper step highlighted
5. Tap action button in details → stepper advances in-place (no pop/push)
6. Bottom nav History tab → `LoadHistoryScreen` shows completed loads
7. GPS tracking still runs for all `isActive` statuses including `droppedOff`
