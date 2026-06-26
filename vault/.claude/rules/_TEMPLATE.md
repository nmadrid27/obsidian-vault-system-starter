---
type: rule
id: <kebab-case-id>
applies-to:
  domains: ["*"]              # "*" = every domain, or list logical domains e.g. ["Teaching/<Course-Code>"]
  intents: ["draft", "edit"]  # e.g. write_prose, draft, edit, review
priority: high                # high | medium | low
tier: global                  # global | combo | domain | intent  (see below)
last-updated: 2026-01-01
required-skills: []            # skill briefs the writing-preflight gate will fetch
---

<!--
Tier model. How a query decides whether to return this rule:
  global  returned on every query, regardless of domain or intent (your safety net)
  combo   domain AND intent both match
  domain  domain matches
  intent  intent matches

Copy this file, rename it to your rule id, replace the frontmatter, and write the
rule below. The server reads rules fresh on every query; no restart needed.
-->

# <Rule title>

<The rule, in plain language. State what must or must not happen, and why.>
