# Design

## Data ownership

Environment fields belong to `ClaudeAccounts`, because the same official provider can contain multiple Claude accounts and the requested binding is account-specific:

- `proxySoftware`: nullable string, initially `clash_verge`.
- `proxySubscription`: nullable string containing the user-visible Clash Verge subscription name.
- `timezone`: nullable string containing an IANA timezone identifier.

The provider editor exposes the section only when editing the official Claude provider and uses the active Claude account context. Account management remains the source of truth for each account's values.

## Clash Verge integration

Use a small service adapter with a command-first strategy: call a locally available Clash Verge command if detected, otherwise use its localhost API when the endpoint is discoverable. The adapter accepts a subscription display name and reports a structured failure; it does not guess or silently select a different subscription.

## Timezone integration

Use a macOS native authorization prompt for `systemsetup -settimezone <timezone>`. The command must receive the timezone as a validated argument and the app must not pass or persist a password. A failed authorization is reported to the user and does not claim the environment switch completed.

## Switch order

1. Write the Claude credential and account identity.
2. Apply the target account's Clash Verge subscription, if configured.
3. Request authorization and apply the target account's timezone, if configured.
4. Mark the Claude account active only after step 1 succeeds; report later environment failures separately.

## UI

Add a bordered/sectioned form block titled “Environment Configuration” above “Configuration Preview”. It contains:

- Proxy software dropdown, defaulting to Clash Verge.
- Subscription text/dropdown value using the saved Clash Verge subscription name.
- Timezone text field with IANA examples.

All labels and errors are localized in Chinese and English.
