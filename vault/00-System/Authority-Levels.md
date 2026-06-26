---
title: Authority-Levels
updated: 2026-01-01
---

# Authority levels

The vault recognizes three authority levels. Each actor (a caller identified by an
API key) is assigned one. The server enforces these on every tool call; this file
is the human-readable statement of the model. It is write-denied: the server
refuses `write_file` to it.

| Level | Who | May |
|---|---|---|
| L1 | read / query actors | read, search, scan, list |
| L2 | append actors (for example, the daily cron) | the above, plus appends and coordination markers |
| L3 | owner | everything, including frontmatter writes, entity-context writes, and the preflight bypass |

Notes that govern enforcement:

- An actor with an explicit `allowed_tools` allowlist is gated by that allowlist,
  not by the per-tool level table. The allowlist is the grant.
- `write_file` to an existing file requires L3 for a human owner; an allowlisted
  actor stays at its assigned level.
- The actor is resolved from the API key by middleware and injected server-side.
  Tools never accept an actor name as an argument.

> Edit this file to describe your own actors, but keep the three-level shape. The
> server's behavior is defined in code, not here; this file documents it.
