# Security Policy

## Scope

Project Ascent is an offline-first Godot demo. It has no accounts, backend,
online service, telemetry, or network gameplay. The optional
`addons/godot_mcp_toolkit/` is development tooling and binds to localhost; it is
excluded from the HTML5 export.

## Reporting

Please do not publish credentials, private files, exploit details that expose a
live service, or other sensitive material in a public issue. If GitHub private
vulnerability reporting is enabled for this repository, use that channel.
Otherwise, contact the repository owner through a private GitHub channel before
opening a public issue.

Security reports should include the affected file or component, reproduction
steps, impact, and any safe mitigation. Do not attach real secrets; use clearly
fake test values.

## Development hygiene

- Do not commit `.env` files, tokens, passwords, private keys, or local bridge
  configuration.
- The root `.mcp.json` is intentionally ignored because it can invoke a local
  development bridge through `npx`; use the shipped template only when needed.
- Review third-party addon licenses and source before adding dependencies.
- Keep the Web export limited to the explicitly configured runtime content.
