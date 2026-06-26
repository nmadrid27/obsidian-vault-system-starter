"""Domain ontology for your vault: edit, then fold into vault-system-mcp's config.

This file is the heart of the ontology. It declares every domain in your vault and
classifies each as prose (writing gated) or structural (ungated). Copy these three
structures into your vault-system-mcp `config.py`, replacing the originals.

Three rules:
  1. DOMAIN_PREFIXES is ordered. List the MOST SPECIFIC prefix first, because the
     resolver takes the first matching prefix.
  2. Every logical domain you create should appear in exactly one of
     PROSE_DOMAINS or CODE_DOMAINS.
  3. A path under shared/ resolves to the domain of its remainder, so
     shared/Teaching/<Course-Code>/x.md still resolves to Teaching/<Course-Code>.
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

    ("meetings", "meetings"),

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
    "meetings",
}

# Writes to these logical domains are ungated (system files, scratch, planning).
CODE_DOMAINS = {
    "_entities", "context", "00-System",
    "ideas", "Archive", "templates", "prompts",
}

# Top-level folders excluded from marker / tag / task / backlink scans, because
# they hold history or illustrative examples that would produce false positives.
SCAN_SKIP_TOPLEVEL = {"Archive"}
