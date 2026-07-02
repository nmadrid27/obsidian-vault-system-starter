"""Domain ontology for this vault (active config; rendered from domains.example.py).

This file declares every domain in the vault and classifies each as prose (writing
gated) or structural (ungated). Fold these three structures into vault-system-mcp's
config.py.

Three rules:
  1. DOMAIN_PREFIXES is ordered. List the MOST SPECIFIC prefix first, because the
     resolver takes the first matching prefix.
  2. Every logical domain you create should appear in exactly one of
     PROSE_DOMAINS or CODE_DOMAINS.
  3. A path under shared/ resolves to the domain of its remainder, so
     shared/Teaching/<Course-Code>/x.md still resolves to Teaching/<Course-Code>.

Business second-brain (added 2026-07-02): two logical prose domains, Business and
Meetings. Business subfolders (Market/, Funding/, Company/) intentionally resolve
to "Business" via longest-prefix match rather than being registered separately.
"""

# physical vault-relative prefix  ->  logical domain string
# (most specific first)
DOMAIN_PREFIXES = [
    ("shared", "shared"),

    # --- prose domains ---
    # One row per teaching unit. EXAMPLE row shows the real shape; replace it.
    ("Teaching/history/HIST-201", "Teaching/HIST-201"),  # EXAMPLE: delete or replace
    ("Teaching/<discipline>/<Course-Code>", "Teaching/<Course-Code>"),
    ("Teaching/<discipline>", "Teaching/<discipline>"),
    ("Teaching", "Teaching"),

    ("Admin/<Admin-Area>", "Admin/<Admin-Area>"),
    ("Admin", "Admin"),

    ("Writing/<Writing-Project>", "Writing/<Writing-Project>"),
    ("Writing", "Writing"),

    # --- business second-brain (added 2026-07-02) ---
    # Business/Market, Business/Funding, Business/Company resolve here via prefix.
    ("Business", "Business"),
    ("Meetings", "Meetings"),

    # --- structural domains ---
    ("context", "context"),
    ("_entities", "_entities"),
    ("00-System", "00-System"),
    ("ideas", "ideas"),
    ("Archive", "Archive"),
    ("templates", "templates"),
    ("prompts", "prompts"),
]

# Writes to these logical domains require the writing-preflight gate.
PROSE_DOMAINS = {
    "shared",
    "Teaching", "Teaching/<discipline>", "Teaching/<Course-Code>",
    "Admin", "Admin/<Admin-Area>",
    "Writing", "Writing/<Writing-Project>",
    "Business",
    "Meetings",
}

# Writes to these logical domains are ungated (system files, scratch, planning).
CODE_DOMAINS = {
    "_entities", "context", "00-System",
    "ideas", "Archive", "templates", "prompts",
}

# Top-level folders excluded from marker / tag / task / backlink scans, because
# they hold history or illustrative examples that would produce false positives.
SCAN_SKIP_TOPLEVEL = {"Archive"}
