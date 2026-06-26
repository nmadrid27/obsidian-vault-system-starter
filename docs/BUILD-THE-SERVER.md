---
title: Build Your Own Vault-System Server
type: build-spec
audience: a colleague handing this to Claude Code (or another coding agent) to build the MCP server locally
---

# Build Your Own Vault-System Server

This is a buildable specification, not source code. Hand it to Claude Code (or any
coding agent) and say: *"Build the MCP server described in this document, in a
`server/` directory, wired to my vault."* The agent implements it on your machine;
you own the result and set your own rules and structure.

Nothing here depends on anyone else's private code. You are building a fresh,
local server that enforces the ontology already templated in this repo.

> **Why a spec instead of a prebuilt server.** The server's whole job is to enforce
> *your* structure. Building it yourself means it fits your domains from the first
> line, there is no secret material to inherit, and you can change any rule without
> waiting on an upstream. The contract below is what matters; the exact code is the
> agent's to write.

---

## 0. What you already have in this repo

Use these as the inputs to the build; do not reinvent them:

- `vault/` : the Obsidian vault skeleton (folder taxonomy, `AGENTS.md`, `00-System/`
  stubs, entity and rule templates). This is the vault the server governs.
- `config/domains.example.py` : your **ontology**. Edit it first (Section 1). The
  server reads its three structures: `DOMAIN_PREFIXES`, `PROSE_DOMAINS`,
  `CODE_DOMAINS`.
- `config/api-keys.example.yaml` : the actor-registry schema.
- `mcp/mcp.json.template`, `mcp/settings.local.json.snippet` : how Claude Code
  connects to the server and how native writes are denied on prose paths.
- `setup.sh` : generates keys, renders the configs, copies the skeleton. Run it
  after the server is built, pointing `--mcp-dir` at your new `server/`.
- `docs/ontology-handoff.md` : the full design rationale. Read it for the "why"
  behind each component below.

---

## 1. Define your ontology first

Before any code, edit `config/domains.example.py`:

1. List every top-level folder in your vault.
2. Write `DOMAIN_PREFIXES` as an ordered list, most specific physical prefix first,
   mapping each to a logical domain string.
3. Put each logical domain in exactly one of `PROSE_DOMAINS` (writing gated) or
   `CODE_DOMAINS` (ungated).

Everything the server does keys off this map. Get it right before building.

---

## 2. Tech stack

- Python 3.12+
- [FastMCP](https://github.com/jlowin/fastmcp) **3.x** for the MCP server (HTTP
  transport). Its wiring API is not obvious; read Section 4.0 before building.
- `python-frontmatter` for reading and writing note frontmatter
- `PyYAML` for the actor registry
- Standard library for everything else

The server runs as a long-lived local HTTP process bound to `127.0.0.1` only. It is
never exposed off the machine.

---

## 3. Architecture in one paragraph

A local FastMCP server listens on `127.0.0.1:8765`. Every request carries an
`X-API-Key` header; middleware resolves it to an actor and injects that actor into
request scope. Tools never accept an actor argument. Each tool checks authority
(level or allowlist) before doing I/O, and every path argument is resolved through
a safety function that keeps it inside the vault. Write tools to prose domains
refuse until a writing-preflight gate has run for that domain in the session. The
server is a query-and-enforce engine over the vault filesystem; the vault holds all
content, rules, and state.

Build the components below in order. Each lists its contract; the agent writes the
code.

---

## 4. Components to build

### 4.0 FastMCP integration notes (read before building)

The contracts below are framework-agnostic, but wiring them to FastMCP has
non-obvious specifics that cost real time if you find them by trial. Target
**FastMCP 3.x**.

- **Health route:** register `/health` with
  `@mcp.custom_route("/health", methods=["GET"])`, not as an MCP tool.
- **Middleware:** attach ASGI middleware via `mcp.http_app(middleware=[...])` (or
  `mcp.run(middleware=[...])`).
- **Reading the key:** FastMCP strips auth-style headers by default. A bare
  `get_http_headers()` will not return your key; call
  `get_http_headers(include={"x-api-key"})`.
- **Actor at tool time:** injected ASGI scope state does not reach tools (they run
  under the streaming transport, not the raw request). Re-resolve the key inside
  `current_actor()` (see 4.4), do not read `scope["state"]`.
- **Testability split:** "tools never accept an actor argument" is the live-path
  rule, but a tool that resolves its own actor cannot be unit-tested. Split each
  tool into a pure function that takes `actor` (for example in `writers.py`) and a
  thin `@mcp.tool` wrapper that calls `current_actor()` and delegates. Test the pure
  functions directly.

### 4.1 `config.py`

Holds path constants and the ontology. Import the three structures from your edited
`domains.example.py` (or inline them). Also define:

- `VAULT_ROOT` from the `VAULT_ROOT` env var, expanded and resolved.
- Reserved dirs: `_entities/`, `context/`, `00-System/`.
- Named files: `context/DECISION_LOG.md`, `context/current-state.md`,
  `context/heartbeat.md`, `00-System/Authority-Levels.md`.
- `DENY_DIRS = {".git", ".obsidian", ".stversions", ".stfolder", ".claude/worktrees"}`
- `DENY_FILES`: the decision log and `Authority-Levels.md` (no raw `write_file`).
- `EXCERPT_PROTECTED_FILES` and a per-field char cap (e.g. 200) for frontmatter
  length validation on canonical context files. Use `context/current-state.md` and
  `context/heartbeat.md`.
- `SESSION_TTL_SECONDS = 24*60*60`.
- Memory dirs derived from `$HOME` and env vars (never hardcode a username).

**Lifecycle:** `config.py` reads `VAULT_ROOT` and the registry path at import time.
Set the env before the server or tests first import the package; reconfiguring needs
a restart, not a re-read.

### 4.2 Path safety: `safe_resolve(path) -> Path`

The single chokepoint every path argument passes through. It must:

1. Reject empty paths.
2. Resolve relative paths against `VAULT_ROOT`; resolve `~` and env vars.
3. Resolve to absolute, collapsing `../`.
4. Reject anything that resolves outside `VAULT_ROOT`.
5. Reject symlinks whose target escapes the vault. `Path.resolve()` already
   canonicalizes symlinks, so step 4's containment check covers this; do not add an
   `is_symlink()` check on a path that may not exist yet.
6. Reject any path inside a `DENY_DIRS` entry.
7. On case-insensitive filesystems, normalize case before comparison.

Raise a `PathSafetyError` on any violation. No tool does I/O on a path that did not
pass this.

### 4.3 Authority: actor registry + `check_authority`

Actors live in `config/api-keys.yaml` under a top-level `users:` map. Each actor
has `key`, `role`, `authority_level` (1, 2, or 3), and optional `allowed_tools`.

Levels:
- **L1** read/query, **L2** append, **L3** owner (frontmatter writes, entity-context
  writes, preflight bypass).

`check_authority(tool_name, actor, path=None)` returns a structured dict (never
raises) with `success` plus, on success, the `resolved_path` and `actor`. Rules:

- Unknown actor → fail.
- If the actor has an `allowed_tools` list and `tool_name` is not in it → fail. The
  allowlist **is** the grant for such actors (they bypass the level table).
- A per-tool `TOOL_AUTHORITY` map gives the minimum level for human actors (no
  allowlist). Below it → fail.
- `write_file` to an existing file requires L3 for a human actor; an allowlisted
  actor stays at its level. `write_file` is also refused on `DENY_FILES`.

### 4.4 Middleware: `X-API-Key` resolution

ASGI/HTTP middleware that reads the `X-API-Key` header, looks the key up in the
registry, and rejects a missing or unknown key with 401 before any tool runs. Use
constant-time comparison for key checks.

Provide a `current_actor()` helper for tool-time identity. Do **not** rely on
injected ASGI scope state: in FastMCP, tools run under the streaming transport, so
`scope["state"]` does not reach them. Implement `current_actor()` by re-resolving
the key via `get_http_headers(include={"x-api-key"})` against the registry (see
4.0). The middleware owns the 401 gate; `current_actor()` owns tool-time identity.

### 4.5 Session manager

Sessions are in-memory with the configured TTL. `begin_session(domain)` is
idempotent on `(actor, domain)`: an existing session for the same pair returns its
id. Per session, track `actor`, `domain`, `started_at`, `last_activity_at`,
`preflighted_domains` (a set), and `bypass_grants`. Provide `end_session` and
`set_session_domain`.

### 4.6 Domain resolution

- `path_to_domain(path) -> str`: longest-prefix match against `DOMAIN_PREFIXES`.
  For a path under `shared/`, compute the domain against the remainder after
  stripping `shared/`, so `shared/Teaching/<X>/f.md` resolves to `Teaching/<X>`.
- `is_prose_path` / `is_code_path`: membership in `PROSE_DOMAINS` / `CODE_DOMAINS`.
- `is_shared_path`: first path part is `shared`.
- `logical_to_physical(domain) -> Path`: reverse the map for callers that need the
  physical directory of a logical domain.

### 4.7 Rules registry

Rules are vault content at `<vault>/.claude/rules/`, one markdown file per rule with
frontmatter (`type, id, applies-to: {domains, intents}, priority, tier,
required-skills`). Read them fresh on every query (no caching, no restart).

`get_relevant_rules(domain, intent) -> list`: return the union of matching rules.
Tier semantics:
- `global`: always returned.
- `combo`: domain and intent both match.
- `domain`: domain matches (prefix-aware, parent matches child).
- `intent`: intent matches.

When the write targets `shared/`, union the personal registry with a shared one at
`<vault>/shared/.claude/rules/`. Trigger the union with an explicit flag, e.g.
`get_relevant_rules(domain, intent, shared=False)`; the gate sets `shared=True` when
the write path is under `shared/`. Do not infer it from the domain string alone.

### 4.8 Writing-preflight gate (the core enforcement)

This is the point of the whole system. Two layers:

- **Tool layer:** `write_file`, `append_to_file`, `update_frontmatter`, `edit_file`
  check whether `writing_preflight` has run this session for the target path's
  domain. If not, return `{"error": "preflight_required", "next_action": ...}` and
  do nothing else. Gating is by domain: a write to a prose path needs preflight; a
  write to a structural path does not. (The dedicated `append_decision_log` and
  entity tools are separate and not gated this way.)
- **`writing_preflight(domain, session_id)`:** call `get_relevant_rules(domain,
  intent="write_prose")`, collect the rules' `required-skills`, fetch those skill
  briefs, mark the domain preflighted in session state, and return rules + skills in
  one response.

`bypass_preflight(domain, reason, session_id)` is L3-only, appends a structured
entry to `00-System/Reflection-Log.md`, and records the grant in session state.
Audit-only. It takes no actor argument, so enforce L3 inside the tool by
re-resolving the actor's level from the registry; it is not in the per-tool
authority table.

(The companion deny rules in `mcp/settings.local.json.snippet` close the native
`Edit`/`Write` path so this gate cannot be bypassed with a plain editor.)

### 4.9 Write tools

Signatures: `write_file(path, content, frontmatter_data=None)`,
`append_to_file(path, text)`, `update_frontmatter(path, updates)`,
`edit_file(path, old, new)`. Frontmatter is passed as structured data
(`frontmatter_data`), never parsed out of `content`, so reserved-field rejection is
unambiguous.

All take a vault path, run `safe_resolve` + `check_authority`, enforce the gate
(4.8), then write. Additional behavior:

- **Frontmatter stamping:** on any write to a `shared/` path, stamp
  `last-edited-by: <actor>` and `last-edited-at: <ISO-8601>`. These are reserved;
  reject caller-supplied values for them.
- **Frontmatter length cap:** on `EXCERPT_PROTECTED_FILES`, reject any single
  frontmatter field over the cap. For `update_frontmatter`, validate the merged
  result, not the raw update.
- `write_file` is denied on `DENY_FILES` and on `_entities/*` (use entity tools).

### 4.10 Entity tools

Entity notes are `_entities/<name>.md` with a `## Context` section and a
`## Recent Activity` section. Do not allow raw `write_file`; instead:

- `read_entity_note(name)`
- `append_entity_activity(name, activity)`: prepend one line to Recent Activity,
  trim to a cap (e.g. 7).
- `update_entity_context(name, new_context)`: replace the Context section (L3).

### 4.11 Marker tools

Markers are inline tokens scanned across the vault. Support a taxonomy with a
writer, resolver, and TTL per type (for example `@coordination:` 7d, `@drift:` 14d,
`@stale:` escalates at 30d). Provide scan, resolve, and removal tools. Exclude
history/scratch top-level folders from scans to avoid false positives.

### 4.12 Bootstrap

`get_session_bootstrap(session_id, domain)`: return the applicable rules, pending
markers, and (optionally) a domain-filtered memory pointer index in one response.
`vault/AGENTS.md` already instructs the session to call `begin_session` then
`get_session_bootstrap` on entry.

### 4.13 `server.py`

Create the FastMCP app, install the API-key middleware, register every tool, and
serve on `127.0.0.1:8765`. Expose a `/health` endpoint for the installer to poll.

---

## 5. Run it

Once built, wire and launch it (the repo's `setup.sh` does most of this):

1. `./setup.sh --mcp-dir ./server --vault ~/Obsidian --owner "$USER"` : generates
   keys at mode 0600, renders `config/api-keys.yaml` into `server/`, renders the
   project-scoped `.mcp.json` into the vault, copies the skeleton.
2. Merge `mcp/settings.local.json.snippet` into `~/.claude/settings.local.json`
   (adjust the globs to your prose domains).
3. Start the server (`python server/server.py`, or under launchd/systemd for
   always-on). Confirm `curl -s http://127.0.0.1:8765/health`.
4. `cd ~/Obsidian && claude` and start a session.

---

## 6. Acceptance criteria

The build is done when all of these hold:

1. Wrong `X-API-Key` returns 401; the owner key does not.
2. `write_file` to a prose path returns `preflight_required` until
   `writing_preflight` runs for that domain, then succeeds.
3. Native `Edit`/`Write` on a prose path is denied by Claude Code.
4. A write to a `shared/` path lands with `last-edited-by` / `last-edited-at`
   stamped, and a caller cannot forge them.
5. `write_file` to `00-System/Authority-Levels.md`, the decision log, or
   `_entities/*` is refused.
6. A path containing `../` that escapes the vault, or a `.git/` path, is rejected.
7. `get_relevant_rules` returns `global` rules on every query and the right
   domain/intent matches otherwise.
8. `begin_session` called twice for the same `(actor, domain)` returns the same id.

Write a test for each before calling it complete.

---

## 7. What to tell Claude

Paste something like this into Claude Code from the repo root:

> Build the MCP server specified in `docs/BUILD-THE-SERVER.md`, in a new `server/`
> directory. Use my ontology in `config/domains.example.py` (I have edited it).
> Follow the component order in Section 4, write a test for each acceptance
> criterion in Section 6, and stop after each component for me to review. Do not
> copy any external code; implement to the contract.

Then review each component as it lands. The result is your server, governing your
vault, on your machine.
