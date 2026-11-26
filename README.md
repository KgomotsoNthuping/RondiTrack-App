# RondiTrack Mobile

RondiTrack manages stokvel memberships, cycles and contributions.

The app uses real authentication, account-scoped providers, a Drift cache,
a durable payment outbox, create/edit forms and filtered contribution history.
The API remains the authority for permissions, payment confirmation and totals.

## Development

Use Flutter 3.47.9 and Dart 3.13.7.

Run commands from the application repository root.

```powershell
flutter pub get
dart run build_runner build
```

Run on Chrome when the development API is available on the same computer:

```powershell
flutter run -d chrome --dart-define-from-file=config/dev.json --dart-define=API_BASE_URL=http://localhost:5227
```

Run the Android development flavour:

```powershell
flutter run --flavor dev --dart-define-from-file=config/dev.json
```

The Android emulator uses `http://10.0.2.2:5227` for an API on the host.
Chrome uses `http://localhost:5227`. Staging and production require real
deployment URLs and HTTPS.

Registration returns to sign-in. Successful sign-in opens the requested
destination. Chrome uses browser-managed refresh cookies; native platforms
use secure refresh-token storage. Access tokens remain in memory.

## Main routes

| Address | Purpose |
| --- | --- |
| `/` | Home and the current account's stokvels |
| `/stokvels` | Stokvel list |
| `/stokvels/:id` | Stokvel details |
| `/stokvels/:id/cycles/:cycleId` | Cycle details |
| `/stokvels?view=create` | Create a stokvel |
| `/stokvels/:id?view=history` | Filtered contribution history |
| `/stokvels/:id/cycles/:cycleId?view=pay` | Record a contribution |
| `/stokvels/:id/cycles/:cycleId?view=edit` | Edit a cycle |
| `/join/:code` | Continue an invite through authentication |
| `/activity` | Membership activity |
| `/profile` | Account, pending payments, reauthentication and sign-out |

The current payout contract does not expose a payout-order read endpoint.
The app does not invent a payout order or perform a payout to obtain read data.

## Generated API client

The copied contract is `contract/openapi/v1.json`.
Its source is recorded in `contract/source.json`.
`swagger_parser.yaml` selects the generated endpoints.

Generated clients and models are committed under
`lib/core/network/data/generated`. Handwritten mappers and repositories
remain outside that directory.

```powershell
dart run tool/generate_api.dart
dart run tool/check_api_drift.dart
```

The generation command recreates the generated API directory.
Ordinary Riverpod, Freezed and Drift generation uses `dart run build_runner build`.

## Assignment 12.1 delivery plan

This README records the plan before new test or reporting code is added.
The test names below are targets for the assignment, not claims that every
test already exists or passes.

| Commit | Work |
| --- | --- |
| 1 | Test plan, privacy inventory and decisions |
| 2 | Mocked repositories, cached state, failure mapping, session and outbox tests |
| 3 | Home state/accessibility tests and reviewed stokvel-card goldens |
| 4 | Android journey, measured coverage gate, emulator CI and time-zone runs |
| 5 | Contribution-list measurements, seed/cleanup scripts and a rebuild regression test |
| 6 | Sentry, scrubber, analytics interface, privacy tests and final evidence |

Flutter and Dart versions remain pinned.

The assignment's package pins are `mocktail: 1.0.5`,
`alchemist: 0.14.1` and `sentry_flutter: 10.3.0`.
`integration_test` comes from the Flutter SDK.
They will be added with the commits that use them.

After each dependency change, review every resolved hosted version in
`pubspec.lock` and run:

```powershell
dart run tool/check_dependency_age.dart
```

An existing override is not a reason to skip that check.
Record each override's reason and removal condition before final hand-in.

## Test plan

### Rules that protect money and privacy

| Rule | Planned proof |
| --- | --- |
| Concurrent expired requests share one refresh and replay with the new access token. | `test/unit/session_interceptor_test.dart` |
| No signal preserves the session; 403 does not refresh. | `test/unit/session_interceptor_test.dart` |
| A refused refresh ends authenticated API access. Pending payments remain protected until same-account reauthentication or confirmed discard. | `test/unit/session_interceptor_test.dart` and `test/session_test.dart` |
| A previous account's requests and cached state cannot update the next account. | `test/account_join_test.dart` and `test/unit/cached_stokvel_notifier_test.dart` |
| Failed refreshes retain cached Home and stokvel data and its saved timestamp. | `test/unit/cached_home_notifier_test.dart` and `test/unit/cached_stokvel_notifier_test.dart` |
| Confirmed sign-out clears identity, cached data and queued attempts. A pending-payment warning is not bypassed. | `test/unit/sign_out_cache_test.dart` |
| A queued payment keeps its key and frozen body across unanswered retries. | `test/payment_outbox_test.dart`: retry with the same key |
| A 429 keeps the attempt and prevents sending before Retry-After. | `test/payment_outbox_test.dart`: deferred retry with the same key |
| Restarting the app retains the key on disk. | `test/payment_outbox_test.dart`: close and reopen a temporary database file |
| A terminal refusal removes the queued attempt, records the reason and never resends it. | `test/payment_outbox_test.dart`: refusal table |
| An expired attempt stops for review. The maximum age stays below server key retention. | `test/outbox_policy_test.dart` and `test/payment_outbox_test.dart` |
| Typed rands and decimal API money convert to exact integer cents. | `test/cents_test.dart` and `test/unit/exact_money_json_test.dart` |
| A payment at 00:30 SAST belongs to that South African day, regardless of machine time zone. | `test/south_african_dates_test.dart` |
| Stale edits preserve typed inputs and require reviewing the latest version. | `test/unit/cycle_editor_test.dart` |
| An unanswered or pending payment does not change confirmed totals. | `test/payment_outbox_test.dart` and `test/widgets/home_states_test.dart` |
| Reports and analytics cannot include personal names, contact details, amounts, credentials or proof names. | `test/privacy/report_scrubber_test.dart` and `test/privacy/analytics_test.dart` |

### Outbox response table

| API outcome | Expected outbox behaviour |
| --- | --- |
| Valid 201 with matching account, stokvel, cycle, amount and accepted status | Persist confirmation, remove the queued row and refresh authoritative data. |
| Replayed 201 for the same key and body | Recognise the same contribution; do not create a second local payment. |
| 400 | Record validation feedback and stop that queued attempt. |
| 401 | Keep the intent and key; restore authentication through the session coordinator. A refused refresh requires reauthentication. |
| 403 or 404 | Record the refusal and stop that attempt without exposing another account's data. |
| 409: already paid, cycle closed or key/body conflict | Remove the attempt, explain the refusal and do not retry it. |
| 422 | Record the business-rule refusal and stop that attempt. |
| 429 | Retain the key/body and persist the retry deadline. Test delta-seconds and HTTP-date headers; the current invalid-header fallback is one minute. |
| No answer, connection failure, cancellation or 5xx | Preserve the unconfirmed attempt and its key; do not label it paid. |
| Unexpected success status or malformed/mismatched 201 body | Treat the result as unconfirmed; do not fabricate success. |

The existing local maximum age is 24 hours and the recorded server retention
default is 48 hours. The server's deployed configuration must be checked
before using those assumptions in a live environment.

### Test layers and execution

| Layer | What it proves | Where it runs |
| --- | --- | --- |
| Unit/controller | State transitions, repository call counts, mapping, money, dates, retries and privacy rules | Fast CI job and locally |
| Widget | Home loading/data/empty/error/cached states, accessibility and list rebuilds | Fast CI job and locally |
| CI golden | Card appearance with text rendered as blocks | Fast CI job and locally |
| Platform golden | Card appearance with real Inter text | Windows only |
| Integration | Sign in, record a contribution, see it on the cycle and verify the outbox is empty | Android emulator locally and a dependent CI job |
| Live | Selected checks against an explicitly enabled, disposable seeded API | Local opt-in only; skipped in normal CI |
| Manual | TalkBack, visual golden review, Sentry event inspection and real-device performance | Local evidence |

Mocktail will replace repository contracts and verify exact call counts.
The two cached screen controllers will be tested through ProviderContainer
overrides with a real in-memory Drift database.
Register mocktail fallback values for custom argument types in setUpAll.

Where a final implementation prevents mocking, introduce a narrow session
or read-repository interface. Keep the real production implementation
behind that interface and explain the refactor in the pull request.

Listen to auto-disposed providers. Disable or explicitly control automatic
provider retries. Inject clocks instead of sleeping.

Widget database tests use `closeStreamsSynchronously: true` and
`tester.runAsync` when seeding. The restart test uses a temporary file,
closes the first database and reopens a new database instance.

### Home and card cases

Home tests cover loading, memberships, no memberships with a next step,
a readable failure with reference and retry, and offline cached data with age.

Use the real theme and router with fakes behind them. Prefer visible words
and semantics labels to widget keys.

Check Home against `androidTapTargetGuideline`,
`labeledTapTargetGuideline` and `textContrastGuideline` in both themes.

Card goldens cover Treasurer and Member, arrears and up-to-date states,
and an unknown status, in light and dark. Each dark card receives its own
theme so the golden group's labels remain legible.

Alchemist configuration is not const. Real-text platform goldens run only
on Windows through `test/flutter_test_config.dart`.
Review images before committing; ignore generated `failures/` folders.

### Android journey

Use controlled fakes with synthetic users and a persistent temporary test
database. Never use production data or a shared API.

The journey crosses sign-in, payment creation, the outbox worker, server
confirmation and the refreshed cycle view.

Wait for visible words with a timeout instead of relying on pumpAndSettle
to finish database or network work. At the end, read the outbox and assert
that it is empty. A separate sign-out check must await the database wipe.

Run the dev-flavour journey three consecutive times and retain the real output.

## Coverage

Current measured line coverage: not recorded yet.
Enforced floor: to be selected after a successful baseline measurement.

Measure the current suite with:

```powershell
flutter test --coverage --exclude-tags live
```

If that run fails, record and repair the failure before selecting the floor.

Count handwritten application files under `lib/`. Exclude generated
`.g.dart`, `.freezed.dart`, `.drift.dart` files and
`lib/core/network/data/generated/`.

Do not exclude the coordinator, interceptor, outbox, cache, money, date,
list or privacy code to improve the percentage.

Use the same filtering for the baseline and CI. Set the floor close to,
and below, that measured baseline. Record both numbers and enforce the
floor through a small Dart script. Do not use the archived coverage action.

CI will run the fast checks first, then the Android emulator job.
Date tests must run under `TZ=UTC` and `TZ=Africa/Johannesburg`.
Preserve the existing generated-client and contract-copy checks.

## Privacy

This is the planned outbound-data contract for Assignment 12.1.
Sentry and an external analytics provider are not configured by this commit.

### Outbound inventory

| Channel | Destination and fields | Privacy rule |
| --- | --- | --- |
| Normal API traffic | Configured RondiTrack API; the authentication and business fields required by each endpoint | Operational API traffic, separate from telemetry. Never copy its bodies, headers or proof contents into reports. |
| Current API console logger | Local console/debugging tools: method, path, status, elapsed milliseconds and correlation id | No external logging sink is configured. Paths can contain identifiers; audit route normalisation and development-only logging before hand-in. |
| Planned Sentry error event | Configured Sentry project: event id, timestamp, environment, SDK/build release, level, controlled failure code, validated correlation id and scrubbed stack information | No raw messages, member identifiers, arbitrary contexts, request data, contact details, amounts, credentials or proof names. Test the serialised event. |
| Sentry automatic sessions, tracing, profiling, replay, attachments and automatic breadcrumbs | Disabled in the planned configuration | No launch session envelope or unreviewed attachment/event is allowed. Scrub deliberately supplied breadcrumbs and requests as a defence in depth. |
| Planned analytics interface | No external destination; no-op in normal builds and a recording implementation in tests | Allow only the events and fields below. A future external destination requires an updated inventory and explicit review. |
| Golden, emulator, mutation and performance evidence | Local evidence files and the assignment pull request | Synthetic accounts and payments only. Review screenshots and logs before sharing. |

Sentry collection is off when `SENTRY_DSN` is empty.
Each flavour will contain an empty value; a developer supplies a DSN through
a runtime build define. Tests never receive a real DSN and never send reports.

Set Sentry's environment from APP_FLAVOR and sendDefaultPii to false.
Keep the release generated by the SDK from the app id, version and build.

With reporting enabled, the service also processes connection metadata,
including the network address. Disabling default PII is not a substitute
for reviewing payloads, project access, retention and the external destination.
The actual Sentry ingestion host, project and hosting region must be recorded
before a DSN is enabled; those deployment details are not configured yet.

Member and stokvel ids are pseudonymous identifiers, not anonymous data.
Their use in the analytics interface does not make unrestricted export safe.

### Reporting policy and correlation ids

Report unexpected exceptions, storage/contract failures and server failures
that need investigation, through one reporter interface.

Expected offline conditions, validation failures, authentication refusals,
permission failures, not-found results, stale edits and rate limits are
handled in the app without becoming individual error reports.

The existing failure mapper reads `ProblemDetails.correlationId` first,
then `X-Correlation-ID`, and validates the result.
Only a safe, validated reference is allowed in the reporting tag
`correlation_id`. Screens do not call Sentry independently.

The scrubber accepts known member names explicitly. Do not infer a real
name from an email address or depend only on patterns.

Use an allowlist for event structure and remove unsafe free text, request
data, user details, arbitrary tags/contexts and breadcrumb URLs/query strings.
Test messages, exceptions, breadcrumb messages and data, tags, user,
request and nested values.

The realistic leak fixture includes a known name, email, token, proof file
name and an amount with both ordinary and no-break spaces. Assert that none
survive serialisation and that the safe correlation id remains.

### Analytics event contract

| Event | Allowed business fields |
| --- | --- |
| `stokvel_opened` | `stokvel_id`, `member_id` |
| `contribution_attempt_queued` | `stokvel_id`, `member_id` |
| `contribution_confirmed` | `stokvel_id`, `member_id` |

Event names are fixed constants. The interface rejects arbitrary fields.
Do not include an amount, name, email, phone number, proof name, invite code,
access token, refresh token or raw URL. Recording tests check exact payloads.

### Android minimum SDK decision

The current Gradle file uses `minSdk = flutter.minSdkVersion`;
a numeric minimum has not been recorded from a build yet.

When Sentry is integrated, pin `minSdk = 26` because Sentry 10 requires
Android 8.0 or later. This excludes Android versions below 8.0.
No real member-device distribution has been supplied, so the number of
affected members is unknown. Record the previous effective minimum and
communicate the supported-platform change.

## Decisions

Use mocktail mocks for repository call/state tests, controlled fakes for the
Android journey, a scripted adapter for HTTP behaviour, and real Drift
databases for persistence assertions. No live API below the live test layer.

Keep platform goldens on Windows and text-as-block CI goldens in the fast job.
Do not claim the unimplemented 11.3 language work as part of this assignment.

The inherited dependency overrides are code_assets 2.1.0, material_ui 1.10.0,
objective_c 9.6.2 and sqlite3 3.9.1. Their exact constraint reasons still need
to be verified; do not invent a justification. Before final hand-in, record
each reason and the successful solve/build/test condition that allows its
removal. Review all resolved versions, including overrides, for age.

## Performance

No before/after performance result has been measured yet.

Use app-repository scripts to seed several hundred synthetic contributions
into a disposable local API and to remove exactly that seed run again.
Persist the created ids in a local cleanup manifest and reject shared or
production targets. Do not add backend code changes.

Measure the current contribution list first. Record fixture size, viewport,
filter/selection action, rebuild counts, device, OS, Flutter version and mode.

Change one source of unnecessary work at a time. Compare the same scenario
afterward and retain screenshots or counts.

Use `debugOnRebuildDirtyWidget` in a widget regression test to preserve the
measured improvement. Restore the previous hook after each test.
Verify scrolling and filtering at 200% text without clipped or overlapping
content. Do not rely on a fixed row height for variable text.

Debug is acceptable for rebuild counts. Timing claims require profile mode
on a physical device; emulator/debug timings are not phone-speed evidence.

## Tests seen to fail

Capture these deliberate failures separately, undo each mutation, then
rerun the correct implementation. Evidence is pending until actually run.

| Mutation | Required failing proof |
| --- | --- |
| Generate a fresh payment key on every send | The unanswered retry, 429 retry and file-restart key tests must all fail. |
| Remove one scrubber protection | The realistic privacy test must identify the leaked field/value. |
| Clear cached data after a fetch failure | The cached notifier test must fail. |
| Change card padding or a colour | The relevant golden comparison must fail; review its image diff. |
| Restore the earlier list implementation | The rebuild regression test must fail. |

## Running tests and final evidence

Existing baseline commands:

```powershell
dart format --output=none --set-exit-if-changed lib test tool
dart analyze --fatal-infos
flutter test --coverage --exclude-tags live
```

The targeted commands below become runnable as the new suites are added:

```powershell
flutter test test/unit --exclude-tags live
flutter test test/widgets --exclude-tags live
flutter test test/goldens --exclude-tags live
flutter test --update-goldens test/goldens
flutter test test/privacy --exclude-tags live
flutter test integration_test --flavor dev --dart-define-from-file=config/dev.json
```