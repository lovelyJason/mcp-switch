# Add Claude environment profiles

## Why

Claude accounts are sensitive to the network identity and local timezone. The app can already switch Claude OAuth credentials, but it does not persist or apply the proxy subscription and timezone associated with each account.

## Scope

- Persist a Claude account's environment configuration in SQLite.
- Add an “Environment Configuration” section above the provider configuration preview for Claude official accounts.
- Support Clash Verge as the initial proxy software option and persist the selected subscription name.
- Persist an IANA timezone such as `America/New_York` or `America/Chicago`.
- During Claude account switching, switch the Claude login state, switch the Clash Verge subscription, and request macOS authorization to apply the timezone.
- Never store or automate the user's macOS password.

## Non-goals

- Supporting proxy software other than Clash Verge.
- Managing or editing Clash Verge subscription definitions.
- Silently bypassing macOS authorization.
- Changing the Claude account token storage format.
