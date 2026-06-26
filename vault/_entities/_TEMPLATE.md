---
type: entity
name: <entity-name>
---

<!--
Entity notes hold a stable record for any recurring thing worth tracking across
sessions: a person, a project, a course section, a collaborator.

The system reads and writes the two sections below BY HEADING. Keep the headings
exactly as written. Do not edit these files by hand through the write tool; use:
  append_entity_activity  prepends one line to Recent Activity (capped at 7)
  update_entity_context   replaces the Context section (owner / L3 only)

Copy this file to _entities/<entity-name>.md to create a new entity.
-->

## Context
<Durable description: what this is and its current status.>

## Recent Activity
- <Newest activity goes at the top. Oldest is trimmed once there are 7.>
