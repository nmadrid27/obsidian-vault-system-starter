# Vault Session Bootstrap

At the start of every session in this vault, call `begin_session` via vault-system
before responding to any request. Infer the domain from the user's first message
(for example, `Teaching/<Course-Code>`, `Writing/<Writing-Project>`). If the domain
is unclear, call `begin_session` with no domain and update it via `set_session_domain`
once the work becomes clear.

Do not ask the user to call `begin_session` themselves. Do not skip it.

After `begin_session`, call `get_session_bootstrap` with the returned `session_id`
and the inferred domain. Use the bootstrap output to load applicable rules and
pending markers before proceeding.

> This file is read automatically when a Claude Code session starts inside the
> vault. It is the single hook that makes governance automatic. Keep it short.
