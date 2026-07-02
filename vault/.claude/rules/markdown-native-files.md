---
type: rule
id: markdown-native-files
applies-to:
  domains: ["*"]
  intents: ["draft", "edit", "review", "write_prose"]
priority: medium
tier: global
last-updated: 2026-07-02
required-skills: []
---

# Convert .docx/.txt sources to Markdown

Obsidian is Markdown-native, so plain-text sources should not sit in a repo or
vault in a non-Markdown format.

**When a `.docx` or `.txt` file is encountered in a repo or vault:**

- Convert it to Markdown (`.md`).
- Keep the `.md`; remove the source `.docx`/`.txt`.
- Commit both changes together (the add and the deletion in one commit), so the
  source is preserved as Markdown rather than left floating.
- Preserve the content faithfully in the conversion — do not summarize, reorder,
  or drop material; a conversion is a format change, not an edit.

Binary media that has no Markdown equivalent (e.g. `.mp3`, `.mp4`, `.pdf`,
images) is out of scope for this rule — leave it as-is.
