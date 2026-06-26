# obsidian-vault-system-starter

A clonable, genericized, **self-contained** starter for a **governed Obsidian
vault**: the vault skeleton, the ontology template, the wiring, and a build spec
your coding agent uses to construct the MCP server locally. Clone it, define your
domains, have Claude build the server from the spec, and you get a vault where prose
writes are gated behind a preflight, rules are queryable by domain, and state
reconciles itself.

> No external server required. `docs/BUILD-THE-SERVER.md` is an implementation-grade
> spec; hand it to Claude Code and it builds the server on your machine, fitted to
> your domains. (Already have a `vault-system-mcp` checkout? Point `setup.sh
> --mcp-dir` at it instead of building one.)

This repo contains no one's notes. Every domain, rule, and entity here is an empty
template or a labeled example for you to replace.

---

## What you get

```
obsidian-vault-system-starter/
├── vault/                     # the Obsidian vault skeleton (becomes your vault)
│   ├── AGENTS.md              # session-entry hook (makes governance automatic)
│   ├── .claude/               # rules/ (a template + two example global rules), skills/, agents/
│   ├── _entities/             # entity-note template
│   ├── context/               # DECISION_LOG, current-state, TASKS stubs
│   ├── 00-System/             # Goals, Task-Queue, Triggers, Authority-Levels, Reflection-Log
│   ├── Teaching/ Writing/ Admin/ meetings/   # prose-domain roots (empty)
│   ├── shared/                # collaboration surface (Syncthing)
│   └── ideas/ Archive/ templates/ prompts/   # structural domains (empty)
│
├── config/
│   ├── domains.example.py     # YOUR ONTOLOGY: the domain map + prose/structural split
│   └── api-keys.example.yaml  # actor registry schema (no real keys)
│
├── mcp/
│   ├── mcp.json.template      # project-scoped MCP registration
│   └── settings.local.json.snippet   # native deny rules for prose paths
│
├── docs/
│   ├── BUILD-THE-SERVER.md     # implementation spec: hand to Claude to build the server
│   └── ontology-handoff.md     # the full design: what every piece is and why
│
├── install.sh                 # bootstrap installer: clones the repo, hands off to setup.sh
└── setup.sh                   # generates keys, renders configs, copies the skeleton
```

Start with `docs/ontology-handoff.md` for the model, or `docs/BUILD-THE-SERVER.md`
to build the server. The steps below get it running.

---

## Prerequisites

1. **Obsidian** installed.
2. **Claude Code** (or another coding agent) to build the server from
   `docs/BUILD-THE-SERVER.md`. You build your own server locally from the spec; no
   external server is required.
3. **Python 3.12+**, `openssl` (for key generation), and `bash`.

---

## Get the repo

**One-liner** (clones the repo, then prints the next step):

```bash
curl -fsSL https://raw.githubusercontent.com/nmadrid27/obsidian-vault-system-starter/main/install.sh | bash
```

**Clone and run** (more transparent: read the script before you run it):

```bash
git clone https://github.com/nmadrid27/obsidian-vault-system-starter.git
cd obsidian-vault-system-starter
```

> Prefer the GitHub CLI? `gh repo clone nmadrid27/obsidian-vault-system-starter` works the same way.

---

## Build and wire

Define your domains, have Claude build the server from the spec, then run
`setup.sh` to wire and launch it.

```bash
# 1. Define your ontology (the domain map the server enforces)
$EDITOR config/domains.example.py

# 2. Build the server from the spec.
#    In Claude Code from the repo root, hand it docs/BUILD-THE-SERVER.md
#    (Section 7 of that doc has the exact prompt). Claude builds it into ./server.

# 3. Wire keys + configs, then start the server
./setup.sh --mcp-dir ./server --vault ~/Obsidian --owner "$USER"
VAULT_ROOT=~/Obsidian python server/server.py   # or run under launchd/systemd for always-on

# 4. Merge the native deny rules into ~/.claude/settings.local.json
#    (from mcp/settings.local.json.snippet), then open the vault
cd ~/Obsidian && claude
```

`setup.sh` copies the skeleton into your vault root (without clobbering anything),
generates your API keys at mode 0600, and renders `config/api-keys.yaml` (into
`./server`) plus the project-scoped `.mcp.json` (into the vault). It prints the
manual steps it does not automate.

---

## The one file that matters most

`config/domains.example.py`. Everything else follows from it. It declares each
folder in your vault and classifies it as **prose** (writing gated) or
**structural** (ungated). Define your domains there first; the gate, the rules
query, and the build spec all key off that map.

A path resolves to a logical domain by longest-prefix match, and logical domains
can differ from physical folders, so you can reorganize on disk without rewriting
rules. The file carries one worked `EXAMPLE` row to make the pattern concrete;
delete it once yours are in.

---

## Security notes

- The keys (`~/.claude_vault_*key`), `config/api-keys.yaml`, and the rendered
  `.mcp.json` hold secrets. They are gitignored here and must never be committed
  or synced. `setup.sh` writes them at mode 0600.
- The server binds to `127.0.0.1` only. It is never reachable from another machine;
  a clone of this repo points at *your own* localhost, never anyone else's.
- `.mcp.json` is project-scoped on purpose: Claude Code loads it only when launched
  from inside the vault, so unrelated sessions never see the vault tools.
- This is a cooperative-trust tool, not a security product. Stamping records
  authorship; it does not adversarially verify it. See `docs/ontology-handoff.md`
  for the design and trust boundaries.

---

## License

MIT.
