# F011 — Movie & Series Watchlist

## Summary

A prioritised list of movies and series to watch, tracking what has been watched (per season for series), how long each entry takes, where it can be streamed, and what the user thought of it.

## Priority

Medium

## User Story

As a user, I want to keep an ordered watchlist of movies and series so that I can decide what to watch next without re-researching every evening.

## Description

Entries are either a **movie** or a **series**. Every entry can carry an IMDb code (which becomes a link out to IMDb), a year, a runtime, a poster, a free-form source link, a rating, and a written review.

Series additionally track **individual seasons**. Watch status is *derived*, never stored: an entry with no seasons follows its own watched flag, while a series with seasons is unwatched / partially watched / watched based on those seasons. Adding a newly-released season to a finished series therefore reopens it automatically, which is the behaviour the wish asked for.

Runtime is stored per episode for a series; `totalRuntimeMinutes` multiplies it by the total episode count so the list can answer "what fits in this evening".

Entries carry a manual `sortOrder` — the priority queue — maintained by drag-to-reorder on the list page. New entries are appended to the bottom so they never jump the queue.

## Acceptance Criteria

- [x] Add, edit and remove movies and series
- [x] Record IMDb code, year, runtime, poster, source link, rating and review
- [x] Mark an entry watched / unwatched from the list and the detail page
- [x] Search the list by title and description
- [x] Link entries to streaming platforms and filter by them (WISH-0099)
- [x] Reorder entries by dragging to set watch priority
- [ ] Track watched state per season, reopening a series when a season is added
- [ ] Filter and sort by watched state, rating, runtime and priority
- [ ] Fetch details from an IMDb code and search by title (WISH-0100)

## Streaming platforms (WISH-0099)

Platforms are managed separately at `/watchlist/platforms`: name, URL, streaming quality, icon, and optional subscription start/end dates (`isSubscribed` is derived — started and not ended).

**Credentials are never stored on the platform.** It keeps only `vaultEntryId`, the id of an entry in the encrypted password vault. The picker needs the vault unlocked to browse entries and otherwise shows an Unlock prompt; an already-linked entry stays linked either way, and a link to a deleted vault entry falls back to "None" rather than dangling.

Entries hold `platformIds` and show the matching icons on the list and detail pages; a filter chip row narrows the list to one platform. Ids whose platform has been deleted are skipped silently.

## UI / Screens

- **Watchlist** (`/watchlist`) — searchable list, poster thumbnail, status badge, quick watched toggle, swipe to remove.
- **Entry detail** (`/watchlist/:itemId`) — poster, type/year/runtime/status chips, rating, description, IMDb and source links, review.
- **Entry edit** (`/watchlist/new`, `/watchlist/:itemId/edit`) — all editable fields, including the platform multi-select.
- **Streaming platforms** (`/watchlist/platforms`) — management list, reachable from the watchlist AppBar.
- **Platform edit** (`/watchlist/platforms/new`, `/watchlist/platforms/:platformId`).

Reachable from the More page and the dashboard feature grid.

## Data Requirements

`users/{uid}/watchlist/{itemId}` — see `WatchItem` in `lib/features/watchlist/models/watch_item.dart`. Seasons are embedded in the document rather than a subcollection, matching how recipe ingredients are stored.

`users/{uid}/streamingPlatforms/{platformId}` — see `StreamingPlatform`. Both are covered by the existing `users/{userId}/{document=**}` Firestore rule, so no rules change was needed.

## Dependencies

- F001 Authentication (per-user collection)
- WISH-0099 streaming platforms — entries hold `platformIds`
- WISH-0100 TMDB metadata — populates the IMDb-linked fields

## Open Questions

- None

## Notes

Source links are deliberately unvalidated: the user wants to point them at anything, including the location of a torrent file. The detail page reports a failed launch rather than treating it as an error.
