## ADDED Requirements

### Requirement: Account-scoped environment configuration

Each saved Claude account MAY have a proxy software, Clash Verge subscription name, and IANA timezone persisted in SQLite independently of other accounts.

#### Scenario: Persist account environment values

- Given two saved Claude accounts
- When different environment values are saved for each account
- Then reloading the database returns the matching values for each account without cross-contamination

### Requirement: Environment configuration form

The official Claude provider editor MUST show an “Environment Configuration” section above “Configuration Preview”. The proxy software selector MUST default to Clash Verge and currently offer only that option.

#### Scenario: Edit environment values

- Given an official Claude provider and an active saved Claude account
- When the user selects a Clash Verge subscription name and enters an IANA timezone
- Then saving persists those values for that Claude account

### Requirement: Environment-aware account switching

Switching a saved Claude account MUST write the Claude login state first, then apply the target account's configured Clash Verge subscription and timezone. Timezone application MUST use a macOS authorization prompt and MUST NOT store or pass the user's password.

#### Scenario: Apply configured environment

- Given a target Claude account with a subscription name and timezone
- When the user switches to that account
- Then the app writes the account login state, requests macOS authorization for the timezone, and asks Clash Verge to select the saved subscription

#### Scenario: Report partial failure

- Given a target account whose login state was written successfully but whose proxy or timezone operation failed
- When the switch finishes
- Then the app reports the failed environment operation explicitly and does not claim that all environment settings were applied
