# List Watch Progress Resume Design

## Goal

Use the `watch_progress` returned with every list drama to give the normal
player an immediate, best-effort resume target before detail loading completes.

## API contracts

- `/api/home/tags` returns `data` as a root array. Each item may contain
  `watch_progress`.
- `/api/home`, `/api/home/search`, `/api/home/search/hot`,
  `/api/home/play/hot`, `/api/home/online/new`, and `/api/home/vip-only`
  return list items under `data.dramas`; each item may contain
  `watch_progress`.
- `watch_progress` has `watch_episode_id`, `watch_episode_no`,
  `watch_second`, `progress_percent`, and `duration_second`.

## Design

Each affected list DTO and domain item carries an optional immutable watch
progress value. A single player-entry conversion creates a
`PlayerEntryResumeHint` only when the backend gave a real episode ID and a
positive position. A zero-valued progress object therefore behaves exactly as
a new drama and starts from episode one.

All card entry points pass this optional hint to the existing unified player
preload coordinator. The player keeps local progress and the detail response
as authoritative: the list hint only starts detail/playlist preparation near
the likely resume point, while entitlement, source URL, and final fallback
continue to be resolved by the player detail flow.

`/api/home/tags` remains a root-array decoder. It must not be changed to a
`dramas` wrapper. Search's `guess_like` shares the same DTO as its `dramas`
list and receives the same support whenever that field is returned.

## Error handling

Missing, malformed, or all-zero `watch_progress` is tolerated and does not
block navigation. The player receives no resume hint and follows its existing
episode-one behavior.

## Verification

DTO tests cover parsing a non-zero progress object and a zero object. Mapper
and entry tests cover propagation to `PlayerEntryResumeHint` and the absence
of a hint for new users. Existing player and affected feature tests remain
green.
