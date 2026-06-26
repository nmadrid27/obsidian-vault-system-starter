---
title: Reflection-Log
updated: 2026-01-01
---

# Reflection log

The audit trail for the writing-preflight escape hatch. When an owner calls
`bypass_preflight(domain, reason)`, the server appends a structured entry here.
Audit-only: entries are never resolved or removed. A growing list here is a signal
the gate is being worked around too often.

<!-- Bypass entries are appended below this line. -->
