# Security policy

## Sensitive files

This utility reads:

- `~/.codex/auth.json`
- `~/.codex/state_5.sqlite`

Never attach either file to a public issue. Never share access tokens, ID tokens, email addresses, or copied database rows when reporting a bug.

## Network behavior

The current source sends the locally stored bearer token only to HTTPS routes on `chatgpt.com` when requesting usage information. Local usage statistics are not uploaded.

The usage route is not a documented public API and may change or stop working. Users should review the relevant source before building or running the app.

## Reporting a vulnerability

The repository owner should add a private security contact before publication. Do not disclose credentials or account information in a public issue.
