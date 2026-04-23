# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A Japanese care-facility **bath scheduling and tracking** web application for two residential units: さくら (Sakura) and けやき (Keyaki). Residents have recurring weekly bath schedules; staff record completion status and vital signs each day.

There is no build system. The app is two self-contained HTML files that can be opened directly in a browser or served with any static file server:

```bash
python -m http.server 8080
# then open http://localhost:8080/nyuyoku-app_15.html
```

## Two Versions

| File | Description |
|---|---|
| `nyuyoku-app.html` | v1 — simple daily tracker. One flat table (`nyuyoku`) with date-based records. |
| `nyuyoku-app_15.html` | v15 — current version. Recurring schedules with weekly overrides. Preferred file for future edits. |

## Backend: Supabase

Both files connect directly to a Supabase project via hardcoded constants at the top of each file:

```js
const SUPABASE_URL = '...';
const SUPABASE_KEY = '...';  // anon/public key
```

All DB access is through plain `fetch()` calls to the Supabase REST API with the anon key. No Supabase JS SDK is used.

## Database Schema (v15)

**`residents`** — master list of residents  
- `id` UUID, `unit` ('sakura'|'keyaki'), `name`, `bath_type` ('一般浴'|'特浴'), `base_day` (0–6), `base_time` ('午前'|'午後'), `created_at`

**`bath_records`** — daily bath completion records  
- `resident_id` FK, `bath_date` date, `bathed` bool, `vital` (''|'ok'|'recheck'), `treatment` bool

**`resident_overrides`** — per-week schedule overrides  
- `resident_id` FK, `week_start` date, `day_of_week` int|null, `time_of_day` text|null

The v1 schema uses a single `nyuyoku` table with `unit`, `resident_name`, `scheduled_time`, `bath_date`, `bathed`, `vital_ok`.

## v15 Architecture

Everything lives in one HTML file with inline `<script>`. Global state is kept in plain JS objects:

- `residents` — array from `residents` table
- `overrides` — map of `resident_id → override` for the active week
- `records` — map of `resident_id → record` for each visible date

Key functions:
- `loadAll()` — fetches residents, overrides, and records for the current week
- `renderWeek()` — renders the 7-day grid header
- `renderSec(date, timeOfDay)` — renders one morning or afternoon section
- `makeCard(resident, date)` — renders a single resident card with dropdown controls
- `upsert(table, data, conflict)` — generic Supabase upsert helper
- `api(path, opts)` — raw fetch wrapper for Supabase REST API
- `ds(date)` — converts a Date to `YYYY-MM-DD` string

The week currently in view is tracked by `weekStart` (a Monday Date object). Navigation buttons call `changeWeek(±1)` which updates `weekStart` and re-runs `loadAll()`.

## UI Conventions

- Colors: Sakura unit uses `#c4677e` (pink); Keyaki unit uses `#4a8a6a` (green).
- Bath types are color-badged: 一般浴 (general) vs 特浴 (special).
- Vital status has three states rendered as badges: blank / `ok` (green) / `recheck` (red).
- Days are split into 午前 (morning) and 午後 (afternoon) sections per day.
- All user-facing labels are in Japanese.
- Toast notifications are used for async feedback (success/error).

## Language & Style

- Vanilla JS, no framework, no TypeScript, no bundler.
- camelCase for JS variables and functions; kebab-case for CSS classes and IDs.
- Short abbreviated names in v15 (e.g., `res` for residents, `rec` for records, `rv` for reactive values).
- HTML is escaped via a local `escHtml()` helper before insertion into the DOM.
