---
title: Vault-System Ontology: Handoff Guide
type: handoff
status: shareable
audience: colleague standing up their own governed vault
note: content genericized; structure and ontology preserved
---

# Vault-System Ontology: Handoff Guide

This document hands off the *structure* of a governed Obsidian vault driven by
`vault-system-mcp`: the folder taxonomy, the domain model, the note schemas, the
rules registry, and the enforcement and runtime layers around them. The
organizing decisions are kept; the personal content (course names, writing
projects, entity names, rule text, notes) is stripped.

Read it in three parts:

1. **The model**: how the vault is organized and why. The ontology itself.
2. **The governance layer**: how the MCP server enforces that organization.
3. **Runtime and replication**: how to stand up your own copy.

## How to read the placeholders

Anything in `<angle-brackets>` is yours to define:

| Placeholder | Means |
|---|---|
| `<vault-root>` | Your Obsidian vault directory (default `~/Obsidian`) |
| `<owner-username>` | Your OS username; the L3 owner actor |
| `<Course-Code>` | One instance of a teaching unit |
| `<discipline>` | A grouping folder one level above units |
| `<Writing-Project>` | One instance of a writing workstream |
| `<Admin-Area>` | One instance of an administrative area |

One **worked example** is carried through the doc so the pattern stays concrete.
Wherever you see `EXAMPLE`, that row is illustrative; replace it with your own.

---

# Part 1: The model (the ontology)

The core idea: the vault is not a pile of notes, it is a typed space. Every path
resolves to a **domain**. A domain is either **prose** (human-authored content
where voice, disclosure, and authorship matter) or **structural** (system files,
scratch, planning). That single distinction drives almost everything downstream:
which writes are gated, which rules apply, what gets stamped, what the autonomous
loop touches.

## 1.1 Folder taxonomy

The canonical top-level layout. Folders are grouped by role, not alphabetically.

```
<vault-root>/
├── AGENTS.md                  # session-entry instructions (auto begin_session)
├── .claude/
│   ├── rules/                 # rules registry (one markdown file per rule)
│   ├── skills/                # skill briefs the rules point to
│   └── agents/                # vault-specific subagents (not promoted to global)
│
├── _entities/                 # entity notes (people, projects, recurring things)
├── context/                   # living state of the vault
│   ├── DECISION_LOG.md
│   ├── TASKS.md
│   ├── current-state.md
│   ├── heartbeat.md           # written by the daily cron
│   ├── academic-calendar-<year>.yaml
│   └── weekly-status-<date>.md # written by the weekly cron
├── 00-System/                 # governance config the vault reads about itself
│   ├── Goals.md
│   ├── Task-Queue.md
│   ├── Triggers.md
│   ├── Authority-Levels.md
│   └── Reflection-Log.md      # bypass/escape-hatch audit trail
│
├── <prose domains>            # the human-authored content (see 1.2)
│   ├── Teaching/ …
│   ├── Writing/ …
│   ├── Admin/ …
│   └── meetings/
│
├── shared/                    # collaboration surface (Syncthing-synced)
│   ├── .claude/rules/         # team rules, unioned with personal at query time
│   └── rules-registry/
│
└── <structural domains>       # ideas/, Archive/, templates/, prompts/
```

The split that matters: **prose domains** under their own roots, **structural
domains** kept separate, and three reserved trees the system owns (`_entities/`,
`context/`, `00-System/`).

## 1.2 The domain model

A path is mapped to a **logical domain** by longest-prefix match. Logical domains
can differ from the physical folder, so you can reorganize on disk without
rewriting every rule. The mapping is an ordered list, most specific prefix first.

**Pattern (genericize):**

```python
# physical vault-relative prefix  →  logical domain string
DOMAIN_PREFIXES = [
    ("shared",                              "shared"),
    ("Teaching/<discipline>/<Course-Code>", "Teaching/<Course-Code>"),  # one row per unit
    ("Teaching/<discipline>",               "Teaching/<discipline>"),
    ("Teaching",                            "Teaching"),
    ("Admin/<Admin-Area>",                  "Admin/<Admin-Area>"),
    ("Admin",                               "Admin"),
    ("Writing/<Writing-Project>",           "Writing/<Writing-Project>"),
    ("Writing",                             "Writing"),
    ("meetings",                            "meetings"),
    # structural domains:
    ("context",                             "context"),
    ("_entities",                           "_entities"),
    ("00-System",                           "00-System"),
    # ... ideas, Archive, templates, prompts
]
```

**Worked example (replace with yours):**

```
EXAMPLE  ("Teaching/history/HIST-201", "Teaching/HIST-201")
```

A file at `Teaching/history/HIST-201/week-7.md` resolves to logical domain
`Teaching/HIST-201`. Rules and memory pointers scoped to `Teaching/HIST-201` fire on
it; a query for `Teaching` (the parent) also matches it, but not the reverse.

**Prose vs structural.** Each logical domain is declared in one of two sets:

- `PROSE_DOMAINS`: writes here require the writing-preflight gate (Part 2.1).
  Your teaching, writing, admin, meeting, and shared domains belong here.
- `CODE_DOMAINS`: writes here are ungated. The reserved trees (`_entities`,
  `context`, `00-System`) plus scratch and planning (`ideas`, `Archive`,
  `templates`, `prompts`) belong here.

**Shared-path handling.** A path under `shared/` is resolved twice. Its *domain*
is computed against the remainder after stripping `shared/`, so
`shared/Teaching/<Course-Code>/x.md` still resolves to `Teaching/<Course-Code>`
and domain rules still fire. Orthogonally, the path is flagged as shared, which
triggers stamping and the union rules registry. Keep these two axes separate in
your own implementation.

## 1.3 Entity notes

`_entities/<name>.md` holds a stable record for any recurring thing worth
tracking across sessions (a person, a project, a course section, a collaborator).
The schema is fixed; the system reads and writes specific sections by heading.

```markdown
---
type: entity
name: <entity-name>
# any other frontmatter you want; the system reads by section heading
---

## Context
<the durable description: what this is, current status. Replaced wholesale
 by update_entity_context, which is L3-only.>

## Recent Activity
- <newest entry, prepended>
- <older entry>
# capped at 7; the oldest is trimmed on each append_entity_activity
```

Two write paths, no raw editing: `append_entity_activity` prepends one line and
trims to the cap; `update_entity_context` replaces the Context section. Direct
`write_file` to `_entities/*` is denied so the schema cannot be corrupted.

## 1.4 Frontmatter conventions

Frontmatter is typed metadata the system reads and, on shared writes, writes.

- **Stamping (reserved fields).** Every MCP write to a `shared/` path stamps
  `last-edited-by: <actor>` and `last-edited-at: <ISO-8601>`. These are reserved;
  a caller cannot supply or forge them through the write tools.
- **Field-length cap.** A small set of canonical context files
  (`context/current-state.md`, `context/heartbeat.md`) cap any single frontmatter
  field at 200 chars. This prevents a long field from bleeding prose into every
  session-bootstrap excerpt. Long narrative goes in the body or a changelog, not
  in frontmatter.

## 1.5 Marker taxonomy

Markers are inline tokens in note bodies that the system scans and resolves
through tool calls instead of manual grep. Four types, each with a writer, a
resolver, and a time-to-live.

| Marker | Written by | Resolved by | TTL |
|---|---|---|---|
| `@claude:` | interactive session | the active session | current session |
| `@coordination:` | anyone or cron | coordination pass or cron | 7 days |
| `@drift:` | the autonomous drift checks | cron or a session | 14 days |
| `@stale:` | cron, when a marker ages out | manual | escalates at 30 days |

One top-level tree is excluded from marker, tag, task, and backlink scans
(`Archive/`) because it holds historical content that would otherwise produce
false positives. Keep an equivalent skip-list for your own scratch and archive
folders.

## 1.6 Rules registry

Rules are **vault content, not server config.** They live at
`<vault-root>/.claude/rules/` as one markdown file per rule, edited like any note,
synced like any note, read fresh on every query (no restart). The server is a
query engine, not the owner of the rules.

Rule file schema:

```yaml
---
type: rule
id: <kebab-case-id>
applies-to:
  domains: ["*"]              # or specific logical domains, e.g. ["Teaching/<Course-Code>"]
  intents: ["draft", "edit"]  # e.g. write_prose, draft, edit, review
priority: high                # high | medium | low
tier: global                  # see tier model below
last-updated: <date>
required-skills: []            # skill briefs the preflight gate will fetch
---

<the rule prose>
```

**Tier model** (how a query decides what to return):

- `global`: returned on every query, regardless of domain or intent. Your
  safety net: voice profile, disclosure protocol, house style.
- `combo`: domain *and* intent both match.
- `domain`: domain matches.
- `intent`: intent matches.

A query like `get_relevant_rules(domain, intent)` returns the union, with
`global` always included. The writing-preflight gate is a thin wrapper over this
call (Part 2.1).

**Shared registry.** When a write targets `shared/`, the query unions your
personal registry with the team registry at `shared/.claude/rules/`. Personal and
team rules coexist; the union is computed at query time.

## 1.7 Context and system files

Two reserved trees hold the vault's knowledge about itself.

`context/`: living state, written by tools and cron, not by hand:

- `DECISION_LOG.md`: append-only; written only through `append_decision_log`,
  direct writes denied.
- `current-state.md`: the rolling snapshot bootstrap reads.
- `heartbeat.md`: the daily cron's morning brief.
- `TASKS.md`, `academic-calendar-<year>.yaml`, `weekly-status-<date>.md`.

`00-System/`: governance declarations the vault reads about itself:

- `Authority-Levels.md`: the authority model in prose; write-denied.
- `Goals.md`, `Task-Queue.md`, `Triggers.md`, `Reflection-Log.md` (the latter is
  the escape-hatch audit trail).

## 1.8 Memory tiers

Recall is tiered so a session loads pointers, not bulk content.

- **Layer 1: always-on.** A lean `MEMORY.md` index that Claude Code auto-loads
  every session. Cross-cutting rules and pointers to load-bearing memories. Files
  marked `always_on: true` in frontmatter are pinned here and excluded from
  Layer 2.
- **Layer 2: per-call.** A domain-filtered, tier-balanced pointer index
  (feedback / project / reference) returned on request. Domain matching is
  prefix-aware and parent-to-child only: a `Teaching` entry surfaces in a
  `Teaching/<Course-Code>` session, not the reverse. Wildcard domains
  (`general`, `all`, `global`, `*`) match everything.
- **Layer 3: on demand.** The model reads the file named by a matched pointer.
  One match, one read.

---

# Part 2: The governance layer

This is the machinery that enforces Part 1. The principle throughout: make the
non-negotiable parts non-negotiable, and leave everything else alone.

## 2.1 The writing-preflight gate

Two layers stop prose being written without the right skills and rules loaded.

- **Layer A: the MCP gate.** Write tools (`write_file`, `append_to_file`,
  `update_frontmatter`, `edit_file`) check that `writing_preflight(domain)` ran
  this session for the path's domain. If not, they refuse with
  `preflight_required` and a next-action hint. `writing_preflight` calls the rules
  query for that domain, fetches the `required-skills` briefs, marks the domain
  preflighted in session state, and returns it all in one response.
- **Layer B: native deny rules.** `~/.claude/settings.local.json` denies the
  native `Edit` and `Write` tools on every prose path (`Teaching/**`,
  `Writing/**`, `Admin/**`, `meetings/**`, `shared/**`). With the native path
  closed, the MCP path is the only way in, so the gate cannot be bypassed.

**Escape hatch.** `bypass_preflight(domain, reason)` is L3-only and appends a
structured entry to `00-System/Reflection-Log.md`. For genuine emergencies, audit
-only, never silently.

## 2.2 Path safety

Every tool that takes a path runs it through `safe_resolve` before any I/O:

1. Expand `~` and env vars.
2. Resolve to absolute, collapsing `../` traversal.
3. Confirm the result is inside `<vault-root>`.
4. Reject symlinks whose target escapes the vault.
5. Normalize case on case-insensitive filesystems (macOS/APFS) before comparing.
6. Reject paths into `.git/`, `.obsidian/`, `.stversions/`, worktrees, or any
   denied directory.

Plus a content deny-list enforced above path safety: `Authority-Levels.md` and
`DECISION_LOG.md` reject raw `write_file`; `_entities/*` rejects raw `write_file`
(use the entity tools).

## 2.3 Session model

The server outlives any one Claude session. Sessions are in-memory with a 24-hour
TTL. `begin_session(domain)` is idempotent on `(actor, domain)`: an existing
session for the same pair returns its id, which handles parallel terminals and
lost state gracefully. Per session it tracks the actor (resolved from the API
key, never caller-supplied), the domain, timestamps, the set of preflighted
domains, and any bypass grants. `AGENTS.md` at the vault root is what makes
bootstrap automatic: it instructs the session to call `begin_session` and
`get_session_bootstrap` on entry and infer the domain from the first message.

## 2.4 Authority model

Three actors, three levels. Authority is enforced server-side on every call.

| Level | Who | Can |
|---|---|---|
| L1 | read/query actors | read, search, scan, list |
| L2 | append actors (cron) | the above plus appends |
| L3 | owner | everything, including frontmatter and entity-context writes |

Actors are registered server-side in `config/api-keys.yaml` (gitignored, mode
0600, never synced). Schema:

```yaml
users:
  <owner-username>:
    key: <secret>
    role: owner
    authority_level: 3
    # no allowed_tools → full L3 range
  vault-cron:
    key: <secret>
    role: cron
    authority_level: 2
    allowed_tools: [ ... ]   # explicit allowlist; the allowlist IS the grant
  vault-weekly:
    key: <secret>
    role: cron-weekly
    authority_level: 2
    allowed_tools: [ ... ]   # superset of cron
```

Two enforcement subtleties worth preserving: an actor with an `allowed_tools`
allowlist is gated by the allowlist itself, not by the per-tool level table (so a
cron actor can call an L3 tool that is on its allowlist); and `write_file` to an
*existing* file requires L3 for human actors (an allowlisted actor stays at L2).
Middleware validates the `X-API-Key` header on every request and injects the
resolved actor; tools read it from request scope, never from arguments.

## 2.5 The autonomous loop

Two cadences keep state current with no human in the loop.

- **Daily, no LLM.** A pure-Python cron writes `context/heartbeat.md` (date, week
  of term, break status, marker counts, drift warnings), auto-resolves
  simple-pattern coordination markers, and runs deterministic drift checks,
  writing markers for anything needing review. No API cost.
- **Weekly, headless model.** A Sunday job runs a headless session that reads the
  week of heartbeats, synthesizes `context/weekly-status-<date>.md`, and resolves
  the complex markers it can handle confidently. It runs as an L2 actor with no
  preflight, so it physically cannot write to prose paths.

The loop processes personal content only; `shared/` is left to interactive
sessions with a human present.

## 2.6 Shared-vault stamping

The collaboration extension. Every MCP write to a `shared/` path stamps
`last-edited-by` and `last-edited-at` (reserved fields, Part 1.4). The rules query
unions personal and team registries. An audit tool surfaces shared writes that
landed without stamps (out-of-band edits). Each machine holds its own keys and
actor identity; stamping is how authorship travels across machines. This is a
cooperative-trust model, not an adversarial one: a caller who bypasses MCP can
stamp any name. It assumes a small, trusted team.

---

# Part 3: Runtime and replication

## 3.1 Components

| Component | What | Where |
|---|---|---|
| MCP server | local FastMCP, `127.0.0.1:<port>` | runs under launchd |
| Owner key | single secret string, mode 0600, never synced | `~/.claude_vault_key` |
| Cron keys | daily + weekly actor keys, mode 0600 | `~/.claude_vault_cron_key`, `~/.claude_vault_weekly_key` |
| Actor registry | server-side `users:` map | `config/api-keys.yaml` (0600, gitignored) |
| MCP registration | project-scoped, owner key inline | `<vault-root>/.mcp.json` (0600, per-machine) |
| Services | server + daily + weekly | `~/Library/LaunchAgents/*.plist` |

Why `.mcp.json` is project-scoped: Claude Code loads it only when launched from
inside the vault, so unrelated sessions never see the vault tools. It holds the
owner key inline, so it must stay per-machine. If you ever sync the whole vault
root (rather than just `shared/`), add `.mcp.json` to the ignore patterns first.

## 3.2 Replication steps

1. **Decide your domains.** Fill in the worksheet in the Appendix: list your
   prose units and your structural folders, then assign each to `PROSE_DOMAINS`
   or `CODE_DOMAINS`.
2. **Encode the domain map.** Write your `DOMAIN_PREFIXES` ordered list, most
   specific prefix first, mirroring the pattern in Part 1.2.
3. **Scaffold the vault.** Create the reserved trees and stubs:
   - `<vault-root>/AGENTS.md` (session-entry instructions; copy the template).
   - `<vault-root>/00-System/{Goals,Task-Queue,Triggers,Authority-Levels,Reflection-Log}.md`.
   - `<vault-root>/_entities/`, `<vault-root>/context/`,
     `<vault-root>/.claude/{rules,skills,agents}/`.
   - Your prose-domain roots and `shared/` if collaborating.
4. **Author rules.** One markdown file per rule under `.claude/rules/`, using the
   schema in Part 1.6. Start with your `global`-tier safety net (style,
   disclosure) and add domain rules as needed.
5. **Register actors.** Create `config/api-keys.yaml` with your owner (L3) and any
   cron actors (L2 + allowlist), per Part 2.4. Generate the key files at mode
   0600.
6. **Install services.** Register the project-scoped `.mcp.json`, the native deny
   rules in `settings.local.json` for your prose paths, and the launchd services
   for the server and crons.
7. **Verify.** Confirm the auth round-trip (wrong key rejected, owner key
   accepted), the deny rules cover every prose path, and a prose write refuses
   until preflight runs.

## 3.3 Copy-paste templates

**Entity note** (`_entities/<name>.md`):

```markdown
---
type: entity
name: <entity-name>
---

## Context
<durable description and current status>

## Recent Activity
- <first activity, newest at top>
```

**Rule** (`.claude/rules/<id>.md`):

```yaml
---
type: rule
id: <kebab-case-id>
applies-to:
  domains: ["*"]
  intents: ["draft", "edit"]
priority: high
tier: global
last-updated: <date>
required-skills: []
---

<rule prose>
```

**Actor registry** (`config/api-keys.yaml`, mode 0600, never commit):

```yaml
users:
  <owner-username>:
    key: <secret>
    role: owner
    authority_level: 3
  vault-cron:
    key: <secret>
    role: cron
    authority_level: 2
    allowed_tools: [reconcile_state, write_coordination_marker, append_to_file]
```

---

# Appendix: domain worksheet

Fill this in first; everything else follows from it.

| Your folder | Logical domain | Prose or structural? | Gated? |
|---|---|---|---|
| `Teaching/<discipline>/<Course-Code>` | `Teaching/<Course-Code>` | prose | yes |
| `Writing/<Writing-Project>` | `Writing/<Writing-Project>` | prose | yes |
| `Admin/<Admin-Area>` | `Admin/<Admin-Area>` | prose | yes |
| `meetings` | `meetings` | prose | yes |
| `_entities` | `_entities` | structural | no |
| `context` | `context` | structural | no |
| `00-System` | `00-System` | structural | no |
| `<your scratch>` | `<…>` | structural | no |

`EXAMPLE` row, replace with yours:
`Teaching/history/HIST-201` → logical `Teaching/HIST-201`, prose, gated.

Rule of thumb for the prose/structural split: if a human authors it and voice,
disclosure, or authorship matter, it is prose and you gate it. If the system or a
script owns it, or it is scratch you never publish, it is structural and you do
not.

---

*Prepared as a structural handoff. The system design and ontology are the
author's; this document and its genericization were produced in collaboration
with Claude (Anthropic). Personal vault content has been removed; verify the
placeholders against your own setup before relying on them.*
