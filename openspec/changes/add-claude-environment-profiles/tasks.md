# Tasks for add-claude-environment-profiles

## Phase 1: Data model and persistence

- [x] Add nullable environment columns to `ClaudeAccounts` and increment the Drift schema version.
- [x] Add companion fields to account CRUD and migration coverage.
- [x] Add service-level tests proving values survive reload and remain account-specific.

## Phase 2: Environment integrations

- [x] Implement a Clash Verge adapter for switching by saved subscription name.
- [x] Implement macOS timezone application with validated IANA input and native authorization.
- [x] Add deterministic unit tests for command construction, validation, and failure reporting.

## Phase 3: UI and localization

- [x] Add the Environment Configuration section above the provider configuration preview.
- [x] Bind fields to the active Claude account and save them to SQLite.
- [x] Add Chinese and English labels, hints, validation errors, and switch-result messages.

## Phase 4: Account switch orchestration

- [x] Invoke environment application after Claude login-state switching.
- [x] Surface partial failures without falsely reporting a complete environment switch.
- [x] Add integration-oriented tests for successful and failed switch sequences.

## Verification

- [x] Run Drift code generation and `flutter analyze` (no new compile errors; existing lint/info remain).
- [x] Run all relevant service unit tests (20 feature tests passed).
- [ ] Full `flutter test` remains blocked by the pre-existing `test/widget_test.dart` ProviderNotFoundException; the feature service tests pass.
- [ ] Manually verify the macOS authorization prompt and Clash Verge subscription switch with a test subscription (not run to avoid changing the user's live proxy state).
