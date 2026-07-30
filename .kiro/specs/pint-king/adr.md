# Architecture Decision Records — Pint King

This is an append-only log of significant design decisions. Each ADR captures **why** something is the way it is.

## How to use this document

- **One section per decision.** Each ADR has a stable heading (`## ADR-NNNN: Title`) and a fixed number.
- **Append, do not edit.** Once an ADR is `Accepted`, do not change its content. If the decision changes, add a new ADR with a new number and set the old one's `Status` to `Superseded by ADR-XXXX`.
- **Status values**: `Proposed`, `Accepted`, `Superseded`, `Deprecated`.
- **Template** (copy when adding a new ADR):

```
## ADR-NNNN: Title

Status: <Proposed | Accepted | Superseded by ADR-XXXX | Deprecated>
Date: YYYY-MM-DD

### Context
What is the situation? What forces are at play?

### Decision
What is being decided?

### Alternatives Considered
What other options were on the table, and why were they rejected?

### Consequences
What are the trade-offs? What becomes easier? What becomes harder?
```

---

## Index

| ADR | Title | Status |
|-----|-------|--------|
| 0001 | S3-first ordering for pint creation | Accepted |
| 0002 | DB-first ordering for pint deletion | Accepted |
| 0003 | Active group stored on `users` table | Accepted |
| 0004 | Removed members tracked in `group_blocks` table | Accepted |
| 0005 | Leaderboard rank deltas via period snapshots | Accepted |
| 0006 | MVVM + Repository pattern for iOS | Accepted |
| 0007 | Three-tab navigation with centre "+" modal | Accepted |
| 0008 | Custom AVFoundation camera (vs UIImagePickerController) | Accepted |
| 0009 | URLSession + async/await (no third-party HTTP library) | Accepted |
| 0010 | Zero third-party dependencies for MVP (iOS) | Accepted |
| 0011 | UUID primary keys with `gen_random_uuid()` | Accepted |
| 0012 | Offset-based pagination | Accepted |
| 0013 | ISO 8601 UTC timestamps everywhere | Accepted |
| 0014 | Refresh tokens stored as SHA-256 hashes, single-use rotation | Accepted |
| 0015 | All photos stored as JPEG (HEIC and PNG converted on upload) | Accepted |
| 0016 | Pre-signed URLs with 15-minute expiry for photo reads | Accepted |
| 0017 | API-mediated uploads (not direct-to-S3 with pre-signed PUT URLs) | Accepted |
| 0018 | PostgreSQL with PostGIS | Accepted |
| 0019 | Kotlin + Spring Boot for the API | Accepted |
| 0020 | SwiftUI targeting iOS 17+ | Accepted |
| 0021 | Single-AZ RDS for MVP, Multi-AZ deferred | Accepted |
| 0022 | API hosting: ECS Fargate vs App Runner | Proposed |
| 0023 | iOS offline behaviour | Accepted |
| 0024 | Migration tool: Flyway | Accepted |
| 0025 | Pending pints visible in My Pints only (not leaderboard) | Accepted |
| 0026 | Redundant index on group_blocks | Proposed |
| 0027 | Plain UUID fields instead of JPA relationship annotations | Accepted (revisit) |
| 0028 | String constants instead of Kotlin enums for DB-constrained values | Accepted (revisit) |
| 0029 | Manual `updatedAt` management (no JPA lifecycle callback) | Accepted (revisit) |
| 0030 | Always-explicit S3 credentials (no conditional endpoint check) | Accepted (revisit) |
| 0031 | Open class for AppleJwksClient (test overriding) | Accepted (revisit) |
| 0032 | Default display name for new users | Accepted (revisit) |
| 0033 | No rate limiting on auth endpoints in MVP | Accepted (revisit) |
| 0034 | JWT filter writes error response directly (bypasses GlobalExceptionHandler) | Accepted (revisit) |
| 0035 | Public auth paths enumerated explicitly, not by `/auth/` prefix | Accepted (revisit) |
| 0036 | PATCH /users/me partial update cannot clear active_group_id | Accepted (revisit) |
| 0037 | Image type validation by magic bytes, not Content-Type | Accepted (revisit) |
| 0038 | Avatar re-upload deletes old object after persisting new key | Accepted (revisit) |
| 0039 | Servlet multipart limit set above all business size limits | Accepted (revisit) |
| 0040 | Account deletion: DB cascade in one transaction, S3 cleanup async after commit | Accepted (revisit) |
| 0041 | Account deletion reassigns `groups.created_by` to satisfy the NOT NULL creator FK | Accepted (revisit) |
| 0042 | Longest-standing member (`joined_at` ascending) inherits admin / ownership on deletion | Accepted (revisit) |
| 0043 | Invite codes via mixed-case Base62, DB-uniqueness with bounded retry | Accepted (revisit) |
| 0044 | Group creation limit counted from `groups.created_by` | Accepted (revisit) |
| 0045 | Group join check order: not-found → already-member → blocked | Accepted (revisit) |
| 0046 | Group detail hides non-members behind 403 (never 404) | Accepted (revisit) |
| 0047 | Group rename reuses the 403-before-404 auth pattern, admin-only | Accepted (revisit) |
| 0048 | Single remove/leave endpoint branches on caller-vs-target identity | Accepted (revisit) |
| 0049 | `BadRequestException` for message-only 400s (sole-admin leave) | Accepted (revisit) |
| 0050 | Promotion mutates role in place, idempotent, no demotion counterpart | Accepted (revisit) |
| 0051 | Invite-code regeneration reuses the generator, invalidation is implicit | Accepted (revisit) |
| 0052 | Image magic-byte validation extracted to a shared `ImageValidation` helper | Accepted (revisit) |
| 0053 | Pint metadata as flat multipart form fields, not a JSON part | Accepted (revisit) |
| 0054 | Pint group derived from the author's `active_group_id`, not the request | Accepted (revisit) |
| 0055 | `saveAndFlush` to make the S3-first orphan-cleanup catch reachable | Accepted (revisit) |
| 0056 | Latitude/longitude are all-or-nothing (400 if only one supplied) | Accepted (revisit) |
| 0057 | Period filtering derives an inclusive UTC lower bound in-service | Accepted (revisit) |
| 0058 | Feed pagination — 0-based page, default size 20, hard cap 100 | Accepted (revisit) |
| 0059 | Feed authors batch-loaded via `findAllById` (no N+1) | Accepted (revisit) |
| 0060 | Pint update is a partial PATCH; absent fields untouched, blank note clears | Accepted (revisit) |
| 0061 | Pint delete 24h window is inclusive, measured against wall-clock now | Accepted (revisit) |
| 0062 | Period logic lifted to a shared `Periods` helper | Accepted |
| 0063 | Leaderboard dense ranking, zero-pint members, former-member split | Accepted (revisit) |
| 0064 | Rank delta reads previous period's snapshot; null for all_time / first period | Accepted |
| 0065 | Leaderboard snapshot job: per-period cron, per-group isolation, exists-check idempotency | Accepted (revisit) |
| 0066 | Dense ranking extracted to a shared `DenseRanking` helper | Accepted |
| 0067 | Map bounding-box via native `ST_Within` + `ST_MakeEnvelope` queries | Accepted (revisit) |
| 0068 | Map returns a bare pin array (no pagination envelope) | Accepted (revisit) |
| 0069 | Map scope defaults to `group`; former members flagged, never filtered | Accepted (revisit) |
| 0070 | Orphan cleanup diffs bucket keys against DB references, guarded by a grace window | Accepted (revisit) |
| 0071 | Property-based tests assert invariants against independent oracles, one spec per property | Accepted (revisit) |
| 0072 | End-to-end tests drive real HTTP journeys, threading tokens between calls | Accepted (revisit) |
| 0073 | OpenAPI docs auto-generated from controllers, global bearer scheme, off in prod | Accepted (revisit) |
| 0074 | Multi-stage Dockerfile; prod profile fails fast on missing env vars | Accepted (revisit) |
| 0075 | Keep empty feature folders with `.gitkeep`, excluded from the build via a sync-group membership exception | Accepted (revisit) |
| 0076 | iOS domain models double as API DTOs, decoded through one shared camelCase/ISO-8601 coder | Accepted (revisit) |
| 0077 | Repository protocols are `@MainActor` class-bound with `async throws` methods | Accepted (revisit) |
| 0078 | Mock repositories are stateful `@Observable` classes over one shared `MockData` fixture set | Accepted (revisit) |
| 0079 | `GroupDetail` composite and `MapScope` enum added for detail and map endpoints | Accepted (revisit) |
| 0080 | `ImageValidator` detects format by magic bytes and throws, mirroring the API | Accepted (revisit) |
| 0081 | `InitialsGenerator` splits on whitespace, keeps grapheme clusters whole, and never returns empty | Accepted (revisit) |
| 0082 | The "+" tab is a trigger routed through a `RootTabViewModel`, not a selectable tab | Accepted (revisit) |
| 0083 | Root view gates Login vs tab bar by observing the auth repository; LoginViewModel maps errors, owns no auth state | Accepted (revisit) |
| 0084 | Location permission behind a `LocationPermissionRequesting` protocol (real CLLocationManager + mock); full LocationService deferred | Accepted (revisit) |
| 0085 | Profile Setup gated in `RootView` by a session-local `didCompleteSetup` flag; view model owns no persisted profile state | Accepted (revisit) |
| 0086 | Group switcher reads Active_Group live from the repository (shared state), caching only the fetched group list | Accepted (revisit) |
| 0087 | Leaderboard view model derives active/former split and crown from the fetched board; Home composes switcher + leaderboard | Accepted (revisit) |
| 0088 | Leaderboard rows navigate to Member Pint History via a value-based `MemberRoute`; history view model reads the active group live | Accepted (revisit) |
| 0089 | Camera photo pipeline extracted into a pure `PhotoProcessor`; `CameraModel` runs the AVCaptureSession off-main and publishes on the main actor | Accepted (revisit) |
| 0090 | Camera screen logic behind `CameraViewModel`; permission and session driven through `CameraPermissionRequesting`/`CameraControlling` protocols so gating and shutter are unit-tested | Accepted (revisit) |
| 0091 | Post-capture sheet is a `PostCaptureViewModel` owning optional note (280-cap)/drink type; Done logs via `createPint` and dismisses the modal; `CameraView` drives it off `capturedPhoto` | Accepted (revisit) |
| 0092 | Shutter-time GPS behind a `LocationProviding` protocol returning `Coordinate?` (never throws); the fetch starts when the sheet appears and `save()` awaits it; real `LocationService` races `requestLocation()` against a 10s timeout | Accepted (revisit) |
| 0093 | Profile tab card is a `ProfileViewModel` reading profile from `UserRepository` and the total count from `PintRepository.getMyPints(nil)`; sub-screen rows fire inert closures until Tasks 16–19 supply destinations | Accepted (revisit) |
| 0094 | Edit Profile is an `EditProfileViewModel` that saves only what changed; Profile navigates to it value-based via a `ProfileRoute` carrying the loaded `User` | Accepted (revisit) |

---

## ADR-0001: S3-first ordering for pint creation

Status: Accepted
Date: 2026-05-31

### Context
Pint creation involves two non-atomic operations against two different systems: uploading a photo to S3 and inserting a row into `pint_logs`. There is no distributed transaction. We must choose which to do first, and how to handle partial failure.

### Decision
The API uploads to S3 first. Only after a successful `PutObject` does it insert the `pint_logs` row. If the DB insert fails after a successful S3 upload, the orphaned S3 object is enqueued for asynchronous cleanup by the orphan-cleanup job.

### Alternatives Considered
- **DB-first**: insert the row, then upload. Rejected because a successful insert with a failed upload leaves a row pointing to a non-existent photo — user-visible corruption (broken image).
- **Two-phase commit or saga**: rejected as overengineered for MVP.
- **Pre-signed PUT URL with client direct-upload**: see ADR-0017; deferred.

### Consequences
- Users never see a pint with a broken photo link.
- Server-side file validation runs before any S3 cost is incurred.
- Orphaned S3 objects are possible (rare). Mitigated by the cleanup job.
- API request latency includes S3 PutObject time. Acceptable for MVP.

---

## ADR-0002: DB-first ordering for pint deletion

Status: Accepted
Date: 2026-05-31

### Context
Pint deletion is the inverse of creation: we must remove both the DB row and the S3 object. Same atomicity problem. We must choose ordering.

### Decision
Delete the DB row first within a transaction. After commit, dispatch an asynchronous `DeleteObject` to S3. If the S3 deletion fails, the orphan-cleanup job picks it up later.

### Alternatives Considered
- **S3-first**: rejected because a successful S3 delete with a failed DB delete leaves the user able to see the row but unable to fetch the photo — same broken-image problem as ADR-0001 in reverse.
- **Synchronous S3 delete in the request**: rejected because it blocks the user response on S3 latency without any benefit (orphaned S3 objects are tolerated; orphaned DB rows are not).

### Consequences
- The user response returns quickly; S3 cleanup is best-effort.
- Eventually-consistent storage state. Acceptable because the user-visible state (the DB row) is correct.
- The orphan-cleanup job is a hard requirement.

---

## ADR-0003: Active group stored on `users` table

Status: Accepted
Date: 2026-05-31

### Context
Each user has a single "active group" that scopes their pint logging and home screen view. This selection must persist across sessions and devices. We must decide where to store it.

### Decision
A nullable `active_group_id` column on the `users` table, FK to `groups.id`.

### Alternatives Considered
- **Client-only (NSUbiquitousKeyValueStore or local)**: rejected because it would not survive a reinstall and would not sync across devices.
- **Separate `user_settings` table**: rejected as over-structured for a single setting. Can be introduced later if user settings expand.

### Consequences
- One extra FK column on `users`. Negligible.
- Invariant must be maintained: `active_group_id` must always reference a group the user is a member of, or be NULL. See Property 16 in `design/04-api.md`.
- Fallback logic required when the active group is left or removed.

---

## ADR-0004: Removed members tracked in `group_blocks` table

Status: Accepted
Date: 2026-05-31

### Context
When a Group_Admin removes a member, that user must be prevented from re-joining via the same (or any) invite code. We must track this rejection somewhere.

### Decision
A separate `group_blocks` table with `(group_id, user_id, blocked_at)`. The invite-code join flow checks this table before adding a `group_members` row.

### Alternatives Considered
- **Soft-delete on `group_members` with a `status` column** ('active', 'removed', 'left'): rejected because it complicates every membership query with a status filter, and conflates two distinct concerns (current membership vs. join eligibility).
- **No tracking**: rejected because the requirement (3.9) explicitly mandates rejecting removed members.

### Consequences
- Clean separation: `group_members` always means "currently a member".
- Join check is one extra index lookup.
- "Left voluntarily" vs. "removed by admin" are distinguishable: only the latter creates a `group_blocks` row.

---

## ADR-0005: Leaderboard rank deltas via period snapshots

Status: Accepted
Date: 2026-05-31

### Context
The leaderboard shows rank movement (delta) compared to the previous period's final ranking. We need a way to compute this efficiently.

### Decision
A `leaderboard_snapshots` table records the final rank of each member at the end of each completed period (week, month). The delta is `(snapshot rank − current rank)`. A scheduled job writes snapshots at period boundaries.

### Alternatives Considered
- **Compute on the fly from `pint_logs`**: would require scanning all logs in the prior period for every leaderboard request. Acceptable at low scale; expensive at higher counts; complicates the query.
- **Store deltas directly**: rejected because the current rank is dynamic — only the prior snapshot is stable.

### Consequences
- One additional table and a scheduled job to maintain it.
- Leaderboard read is a single query plus a snapshot lookup.
- Snapshot job must be reliable; missed snapshots leave deltas null until the next period.

---

## ADR-0006: MVVM + Repository pattern for iOS

Status: Accepted
Date: 2026-05-31

### Context
SwiftUI does not prescribe an architecture. We need to pick one that's understandable, testable, and not over-engineered for the app's size.

### Decision
MVVM with a Repository layer. Views observe `@Observable` ViewModels; ViewModels hold screen-local state and call Repositories; Repositories own shared/global state and the network layer.

### Alternatives Considered
- **TCA (The Composable Architecture)**: powerful but heavy, third-party, and a steep learning curve for a portfolio MVP.
- **MV (Model-View, no ViewModel)**: viable for small apps but conflates screen-local state with shared state, making testing harder.
- **VIPER / Clean Architecture**: massive boilerplate; overkill for this app's size.

### Consequences
- Clear layering: testable ViewModels with mocked Repositories.
- One ViewModel per screen is a convention to maintain.
- The Repository layer is the seam for offline support (ADR-0023).

---

## ADR-0007: Three-tab navigation with centre "+" modal

Status: Accepted
Date: 2026-05-31

### Context
The primary user action is logging a pint. It must be reachable in one tap from anywhere in the app.

### Decision
A three-tab `TabView` with `[ Home ]  [ + ]  [ Profile ]`. The centre "+" is not a real tab; tapping it presents the camera as a `.fullScreenCover`. Dismissing returns to the previously active tab.

### Alternatives Considered
- **Floating action button**: rejected because it overlaps content (covers leaderboard rows, map pins) and is less discoverable.
- **"+" in the navigation bar**: rejected because navigation bars are screen-local and the "+" should always be reachable.
- **Single tab + camera button in top toolbar**: rejected for the same reason.

### Consequences
- TikTok-style pattern; familiar to users.
- The centre-tab-as-action is a slight UX convention to learn (the "tab" doesn't navigate to a tab).
- Profile becomes the home for everything not in the main loop (groups, settings, account).

---

## ADR-0008: Custom AVFoundation camera (vs UIImagePickerController)

Status: Accepted
Date: 2026-05-31

### Context
The pint logging flow requires zero confirmation between shutter tap and submission (requirement 4.5).

### Decision
Build a custom camera using AVFoundation: an `@Observable CameraModel` owning `AVCaptureSession` + `AVCapturePhotoOutput`, with a minimal `UIViewRepresentable` hosting `AVCaptureVideoPreviewLayer`.

### Alternatives Considered
- **`UIImagePickerController`**: Apple's built-in camera UI includes a retake/confirmation screen that cannot be removed. Directly violates requirement 4.5.
- **`PHPickerViewController`**: photo library only; no live capture.
- **Third-party camera library**: violates ADR-0010 (zero dependencies).

### Consequences
- More code to maintain (session lifecycle, error handling, permissions).
- Full control over capture flow — no Apple-imposed UI.
- The `UIViewRepresentable` is the smallest possible bridge (~10 lines).

---

## ADR-0009: URLSession + async/await (no third-party HTTP library)

Status: Accepted
Date: 2026-05-31

### Context
The app needs an HTTP client with JWT injection, 401 retry, and typed error mapping.

### Decision
Use `URLSession` directly with `async/await`. Wrap it in a thin `NetworkClient` class that handles JWT injection, refresh-on-401 retry, and error mapping.

### Alternatives Considered
- **Alamofire**: more features than needed; adds a dependency for a problem URLSession solves cleanly since iOS 15.
- **Apollo / GraphQL client**: not applicable (REST API).

### Consequences
- One less dependency.
- Modern Swift concurrency (no callbacks).
- We write a small amount of plumbing (interceptor logic) ourselves.

---

## ADR-0010: Zero third-party dependencies for MVP (iOS)

Status: Accepted
Date: 2026-05-31

### Context
The iOS app is small enough that Apple's native frameworks cover everything. Adding dependencies introduces supply-chain risk, build complexity, and updates to manage.

### Decision
No third-party Swift packages in the MVP. SwiftUI, AVFoundation, MapKit, CoreLocation, URLSession, CoreImage, Security, and Codable cover all current needs.

### Alternatives Considered
- **Kingfisher for image caching**: rejected; `AsyncImage` + `URLCache` is sufficient.
- **SwiftCheck for property tests**: this is a test-only dependency and may be added later. Treated as a separate decision if/when introduced.

### Consequences
- Faster build times, no SPM resolution.
- Some marginally more verbose code in a few places (e.g. Keychain wrapper).
- Easier portfolio story: "built with Apple-native frameworks".

---

## ADR-0011: UUID primary keys with `gen_random_uuid()`

Status: Accepted
Date: 2026-05-31

### Context
We need a primary key strategy for every table.

### Decision
UUID v4 generated server-side via PostgreSQL's `gen_random_uuid()` (from `pgcrypto`).

### Alternatives Considered
- **Sequential integers (BIGSERIAL)**: smaller, faster, but expose business volume in URLs and enable enumeration attacks.
- **ULIDs**: lexicographically sortable, but require a Postgres extension or app-side generation.
- **Client-generated UUIDs**: usable for idempotency but not needed in MVP since the API mediates all writes.

### Consequences
- Slightly larger PKs and indexes; negligible at MVP scale.
- Safe to expose in URLs.
- Built-in randomness sufficient for non-enumeration.

---

## ADR-0012: Offset-based pagination

Status: Accepted
Date: 2026-05-31

### Context
The pint history endpoint paginates results.

### Decision
Offset-based pagination with `page`, `size`, and `total` in the response envelope.

### Alternatives Considered
- **Cursor-based pagination**: better at scale and consistent across inserts, but more complex to implement and consume. Not needed for MVP traffic.
- **Keyset pagination**: similar trade-offs to cursor.

### Consequences
- Simple to implement and document.
- Pages can shift if rows are inserted during browsing. Acceptable for MVP.
- May be revisited if pagination becomes a hot path (e.g. very large groups).

---

## ADR-0013: ISO 8601 UTC timestamps everywhere

Status: Accepted
Date: 2026-05-31

### Context
Pints are logged with timestamps that need to round-trip between the app, the API, and the DB.

### Decision
All timestamps in API requests and responses are ISO 8601 in UTC (e.g. `2024-01-15T14:30:00Z`). The DB stores `TIMESTAMPTZ`. Timezone-dependent logic (e.g. "this week" boundary) is applied at presentation time on the client *or* explicitly noted in the API contract.

### Alternatives Considered
- **Local time strings**: rejected because they break aggregation and comparison across timezones.
- **Unix epoch integers**: viable but less human-readable when debugging.

### Consequences
- One consistent format; no parsing ambiguity.
- The "this week" leaderboard filter currently uses ISO week in UTC (per Property 21). User-local-timezone weeks may be revisited later.

---

## ADR-0014: Refresh tokens stored as SHA-256 hashes, single-use rotation

Status: Accepted
Date: 2026-05-31

### Context
Refresh tokens are long-lived (30 days) and must survive token database compromise to a reasonable extent.

### Decision
Store only the SHA-256 hash of each refresh token in `refresh_tokens.token_hash`. Issue plaintext tokens to the client; verify by hashing on lookup. Each token is single-use: rotated on every successful refresh; reusing a used token invalidates the entire token family for that user (reuse-detection).

### Alternatives Considered
- **Plaintext storage**: rejected; a DB leak would expose all sessions.
- **bcrypt/argon2**: unnecessary computational cost for high-entropy random tokens. SHA-256 of a 256-bit random token is appropriate.
- **Long-lived non-rotating tokens**: rejected; rotation is a meaningful security improvement at low cost.

### Consequences
- DB leak does not expose usable tokens.
- Reuse-detection is a strong signal of either a buggy client or a token theft.
- Slightly more DB churn (insert + mark-used on every refresh).

---

## ADR-0015: All photos stored as JPEG (HEIC and PNG converted on upload)

Status: Accepted
Date: 2026-05-31

### Context
iOS captures HEIC by default. Some shared/library photos are PNG. Mixed formats complicate storage, processing, and bandwidth.

### Decision
Convert all uploads to JPEG before storing in S3. Conversion happens on the client (HEIC → JPEG) and the server validates the final format.

### Alternatives Considered
- **Store originals**: more storage, mixed formats downstream, and HEIC is poorly supported outside Apple platforms.
- **Server-side conversion only**: increases API CPU load and bandwidth.

### Consequences
- Single format throughout the system.
- Client must implement HEIC → JPEG conversion.
- Some quality loss vs HEIC (acceptable for the use case).

---

## ADR-0016: Pre-signed URLs with 15-minute expiry for photo reads

Status: Accepted
Date: 2026-05-31

### Context
S3 is a private bucket. The client needs to display photos.

### Decision
The API generates pre-signed GET URLs (15-minute expiry) for each photo when a list is fetched. The client uses these URLs directly via `AsyncImage`.

### Alternatives Considered
- **Public bucket**: rejected; user photos are private.
- **Proxy reads through the API**: doubles bandwidth and adds latency.
- **Longer expiry (e.g. 1 hour or 24h)**: marginally less re-signing churn, but increases the window in which a leaked URL is usable.

### Consequences
- The client must handle URL refresh on long-lived screens (rare; 15 minutes is usually enough).
- API generates URLs on every list response.
- No public exposure of S3 contents.

---

## ADR-0017: API-mediated uploads (not direct-to-S3 with pre-signed PUT URLs)

Status: Accepted
Date: 2026-05-31

### Context
For uploads, we could either have the client send the photo to the API (which writes to S3) or issue a pre-signed PUT URL for direct client-to-S3 upload.

### Decision
For MVP, all uploads go through the API. The API receives the multipart body, validates type and size, and writes to S3.

### Alternatives Considered
- **Pre-signed PUT direct upload**: saves API bandwidth, but requires a presign-then-confirm flow to perform server-side validation (per requirement 7.6) and complicates the S3-first creation ordering (ADR-0001). May be reconsidered post-MVP.

### Consequences
- API bandwidth costs grow with upload volume.
- Server-side validation is simple and synchronous.
- The S3-first creation flow (ADR-0001) is straightforward.

---

## ADR-0018: PostgreSQL with PostGIS

Status: Accepted
Date: 2026-05-31

### Context
We need relational storage and geospatial queries (bounding-box for map view).

### Decision
PostgreSQL 16 with the PostGIS extension. Pint locations stored as `GEOMETRY(Point, 4326)`. Bounding-box queries use a GIST index on `location`.

### Alternatives Considered
- **PostgreSQL with native earthdistance / cube**: less capable than PostGIS for arbitrary spatial queries.
- **MongoDB with geo indexes**: viable but introduces a second paradigm; we'd lose transactional guarantees that matter for account deletion (Property 28).
- **DynamoDB with geo-hash sort keys**: lots of application-level glue; overkill for MVP.

### Consequences
- Single database for relational and spatial data.
- PostGIS adds operational complexity (extension management, larger image).
- AWS RDS supports PostGIS natively.

---

## ADR-0019: Kotlin + Spring Boot for the API

Status: Accepted
Date: 2026-05-31

### Context
We need a backend language and framework.

### Decision
Kotlin with Spring Boot.

### Alternatives Considered
- **Node.js (TypeScript)**: viable; rejected because Kotlin's type system and Spring's ecosystem (validation, security, JPA, Testcontainers) make a portfolio project look more substantive.
- **Go**: minimal frameworks, less batteries-included; would require more hand-rolled plumbing.
- **Java + Spring Boot**: same ecosystem but more verbose than Kotlin.

### Consequences
- Strong type system, null safety, coroutines available if needed.
- Spring's opinionatedness reduces decision count.
- JVM cold-start cost matters for serverless hosting (relevant to ADR-0022).

---

## ADR-0020: SwiftUI targeting iOS 17+

Status: Accepted
Date: 2026-05-31

### Context
We need to pick a UI framework and minimum iOS version.

### Decision
SwiftUI, minimum iOS 17. This unlocks the `@Observable` macro (replacing `ObservableObject` / `@Published`) and modern navigation APIs (`NavigationStack`).

### Alternatives Considered
- **UIKit**: more mature, more code, slower to build.
- **SwiftUI on iOS 16**: missing `@Observable` and some navigation niceties; not worth supporting an older OS for a new app.

### Consequences
- A small share of iOS users on iOS 16 or older cannot install. Acceptable for a portfolio/MVP product.
- Less code, more declarative.

---

## ADR-0021: Single-AZ RDS for MVP, Multi-AZ deferred

Status: Accepted
Date: 2026-05-31

### Context
RDS Multi-AZ doubles cost and provides automatic failover. MVP traffic is low; downtime tolerance is high.

### Decision
Run a single-AZ RDS instance for MVP. Plan to migrate to Multi-AZ when traffic or uptime requirements warrant it.

### Alternatives Considered
- **Multi-AZ from day one**: rejected on cost.
- **Aurora Serverless**: more expensive at low/idle load than a t-class RDS instance; revisit if traffic patterns favour bursting.

### Consequences
- Automated backups still configured (RDS default).
- A single-AZ outage causes downtime; acceptable for MVP.
- Migration to Multi-AZ is non-disruptive when triggered.

---

## ADR-0022: API hosting: ECS Fargate vs App Runner

Status: Proposed
Date: 2026-05-31

### Context
The API is stateless and containerised. AWS offers several hosting options. We need to choose between ECS Fargate (explicit container orchestration) and App Runner (simpler, opinionated).

### Decision (Pending)
TBD. Both options are documented as candidates.

### Alternatives Considered
- **ECS Fargate**: more configuration, more control, integrates well with VPC and ALB. Lower abstraction.
- **App Runner**: easier to set up; automatic scaling; less control over networking. Higher abstraction but limited tunability.
- **Lambda**: rejected; cold-start on JVM is poor, and the API is not a fit for the request model.
- **EKS**: massive overkill for a single-container backend.

### Consequences
*To be filled in when the decision is made.*

---

## ADR-0023: iOS offline behaviour

Status: Accepted
Date: 2026-05-31

### Context
Users will log pints in venues with weak connectivity. We need to decide how much offline support is in MVP.

### Decision
Offline queue for pint creation only (Option B). Photos and metadata are saved to local file storage on capture. Upload completes in the background via `URLSessionConfiguration.background` when connectivity returns — even if the app is suspended. All other features require connectivity.

Failed uploads are retried up to 3 times over 24 hours. After that, the pint is marked "failed" and the user is prompted to retry or discard.

### Alternatives Considered
- **A. Online-only**: simplest but poor UX in the most common usage environment (bars with weak signal).
- **C. Full offline-first with local DB**: best UX but massive complexity (sync conflicts, cache invalidation, stale data). Overkill for MVP.

### Consequences
- The core action (logging a pint) works in low/no connectivity — the most important UX scenario.
- Requires local file storage management (pending photos) and background session handling.
- Pending pints don't appear on the leaderboard until synced — acceptable tradeoff.
- The `PintRepository` becomes the seam: it decides whether to upload immediately or queue locally.

---

## ADR-0024: Migration tool: Flyway vs Liquibase

Status: Accepted
Date: 2026-06-01

### Context
We need a tool to manage DB schema evolution.

### Decision
Flyway. SQL-based, forward-only migrations. Simpler than Liquibase, integrates natively with Spring Boot, and matches the convention already specified in `l3-database.md` (naming: `V{N}__{description}.sql`).

### Alternatives Considered
- **Liquibase**: more features (declarative changesets, rollbacks, conditional logic), but more verbose and complex than needed for this project.
- **Hand-rolled SQL with manual tracking**: rejected; loses traceability.

### Consequences
- Simple SQL files, one per migration.
- No rollback support (forward-only by convention). Corrections go in new migrations.
- Spring Boot auto-runs migrations on startup.

---

## ADR-0025: Pending pints visible in My Pints only (not leaderboard)

Status: Accepted
Date: 2026-05-31

### Context
When a pint is logged offline (or upload is in progress), we need to decide where the pending pint appears in the UI and whether it counts toward the leaderboard.

### Decision
Pending pints appear only in the "My Pints" screen with a "pending" badge. They do NOT appear on the leaderboard or map until the server confirms the upload. The leaderboard only reflects server-confirmed data.

### Alternatives Considered
- **Optimistic leaderboard (count increments immediately)**: rejected because it shows unconfirmed data to other group members and requires a rollback if the upload permanently fails — confusing UX.
- **Home screen indicator ("1 pint uploading...")**: cleaner than optimistic counting but adds UI complexity for MVP. May be revisited post-MVP.

### Consequences
- The leaderboard is always truthful (server-confirmed only).
- Users may notice a brief delay between logging and their count updating — acceptable since upload is typically fast.
- My Pints is the single place to see pending/failed state and take action (retry/discard).
- **Future improvement**: consider adding a subtle home-screen indicator (e.g. "1 pint uploading...") post-MVP for better feedback without compromising leaderboard accuracy.

---

## ADR-0026: Redundant index on group_blocks

Status: Proposed
Date: 2026-06-01

### Context
`V5__create_group_blocks.sql` declares both a `UNIQUE (group_id, user_id)` constraint and an explicit `CREATE INDEX idx_group_blocks_lookup ON group_blocks (group_id, user_id)`. In PostgreSQL, a UNIQUE constraint automatically creates a unique index on those columns. The explicit index is therefore redundant — any query that would use it will use the UNIQUE index instead.

### Decision (Pending)
Leave as-is for now. Decide later whether to remove `idx_group_blocks_lookup` in a future migration (it has no performance cost, just minor clutter).

### Alternatives Considered
- **Remove now**: cleaner schema, but requires editing an applied migration or adding a new one to drop it.
- **Keep permanently**: harmless but technically redundant; PostgreSQL doesn't duplicate internal structures.

### Consequences
*No immediate impact. One extra index name in metadata, no extra storage or performance cost.*

---

## ADR-0027: Plain UUID fields instead of JPA relationship annotations

Status: Accepted (revisit)
Date: 2026-06-01

### Context
JPA supports `@ManyToOne`/`@OneToMany` annotations that model relationships between entities. These enable lazy loading (navigate from a `PintLogEntity` to its `UserEntity` via a field) and cascade operations (deleting a user auto-deletes their pint logs). We need to decide whether to use them.

### Decision
Store all foreign keys as plain `UUID` fields (e.g. `val userId: UUID`) instead of JPA relationship associations. All related entities are loaded explicitly through their own repositories.

### Alternatives Considered
- **`@ManyToOne` / `@OneToMany` relationships**: enables navigation (`pintLog.user.displayName`) and cascade deletes. Rejected for now because lazy loading introduces hidden N+1 queries, bidirectional relationships are complex to manage, and explicit repository calls are easier to reason about for a learning project.

### Consequences
- No accidental N+1 queries from lazy loading.
- Slightly more manual work in service code (multiple repository calls to assemble related data).
- No cascade deletes — must handle manually in service layer (relevant for account deletion, Task 13).
- **Revisit when**: service code becomes cluttered with repetitive multi-repository lookups, or cascade logic gets error-prone.

---

## ADR-0028: String constants instead of Kotlin enums for DB-constrained values

Status: Accepted (revisit)
Date: 2026-06-01

### Context
The database uses CHECK constraints on columns like `group_members.role` (`'admin'`, `'member'`), `pint_logs.drink_type`, and `leaderboard_snapshots.period_type`. We need to decide how to represent these in Kotlin.

### Decision
Use plain `String` fields with companion object constants (e.g. `GroupMemberEntity.ROLE_ADMIN = "admin"`). No Kotlin `enum class`.

### Alternatives Considered
- **Kotlin enum with `@Enumerated(EnumType.STRING)`**: provides compile-time safety (can't accidentally write `"admim"`). Rejected for now because renaming an enum value breaks all existing DB rows, and the mapping between enum conventions (UPPERCASE) and DB values (lowercase) requires extra configuration.

### Consequences
- Typos in role/type strings are only caught at the DB level (CHECK constraint rejects them), not at compile time.
- No risk of breaking the DB if an enum value is renamed or reordered.
- Simpler entity code.
- **Revisit when**: typo bugs actually occur in practice, or when adding validated request DTOs (which can use enums at the API boundary independently of the entity layer).

---

## ADR-0029: Manual `updatedAt` management (no JPA lifecycle callback)

Status: Accepted (revisit)
Date: 2026-06-01

### Context
Several entities have an `updatedAt` timestamp that should reflect the last modification time. JPA offers `@PreUpdate` lifecycle callbacks that can set this automatically before every flush.

### Decision
Set `updatedAt` manually in service code (`entity.updatedAt = Instant.now()`) rather than using a `@PreUpdate` callback or a shared `@MappedSuperclass` with automatic timestamp management.

### Alternatives Considered
- **`@PreUpdate` callback on each entity**: auto-updates the field but hides behaviour (readers must know to look for the annotation). Also requires a no-arg constructor or `@EntityListeners` setup.
- **`@MappedSuperclass` with `@PrePersist` / `@PreUpdate`**: DRY across entities but adds inheritance and a base class that every entity must extend.

### Consequences
- Explicit — you can see exactly where `updatedAt` is set.
- Potential footgun: forgetting to set it in a new service method means the timestamp goes stale.
- **Revisit when**: we forget to update it and it causes a bug, or when we have enough entities that a shared base class would reduce repetition meaningfully.

---

## ADR-0030: Always-explicit S3 credentials (no conditional endpoint check)

Status: Accepted (revisit)
Date: 2026-06-01

### Context
The original `S3Config` conditionally applied static credentials and endpoint override only when the endpoint URL contained "localhost" or "localstack". In production, it relied on the default AWS credential chain. However, AWS SDK v2.25's `S3AuthSchemeInterceptor` resolves credentials independently, and environment variables like `AWS_PROFILE` interfere even when `credentialsProvider()` is set on the builder — causing `SdkClientException` in tests.

### Decision
Always pass explicit `StaticCredentialsProvider`, endpoint override, and `forcePathStyle(true)` to both `S3Client` and `S3Presigner`. Credentials come from Spring properties (`app.s3.access-key` / `app.s3.secret-key`) with a default of `"test"` for local development.

### Alternatives Considered
- **Conditional endpoint check**: broke under `AWS_PROFILE=bedrock` environment variable due to SDK auth scheme interceptor.
- **Unset `AWS_PROFILE` in tests**: fragile, wouldn't help in CI or other environments with different credential setups.
- **Use `@Profile`-specific beans**: adds complexity for a problem solved by one consistent config path.

### Consequences
- Tests work regardless of host machine's AWS configuration.
- Production must supply `app.s3.access-key` and `app.s3.secret-key` via environment variables (or the defaults will be "test").
- `forcePathStyle(true)` is always on — fine for LocalStack, harmless for most S3 configurations but won't work with virtual-hosted-style bucket access.
- **Revisit when**: deploying to AWS (may need to switch to `DefaultCredentialsProvider` for IAM role-based auth and remove `forcePathStyle`).

## ADR-0031: Open class for AppleJwksClient (test overriding)

Status: Accepted (revisit)
Date: 2026-06-02

### Context
The `AppleJwksClient` fetches Apple's public keys over HTTPS. Integration tests need to verify token verification without hitting Apple's real JWKS endpoint.

### Decision
Mark `AppleJwksClient` as `open class` with `open fun getPublicKey()` so tests can subclass it and return a known test key pair. The test configuration (`TestAuthConfig`) provides a `@Primary` bean that overrides the real client.

### Alternatives Considered
- **Interface + implementation**: Adds an interface file for a class that will only ever have one production implementation. More ceremony for no gain.
- **MockBean**: Spring's `@MockBean` recreates the application context and makes tests slower. Also, mocking at this level would skip the actual JWKS-to-RSAPublicKey conversion logic.
- **WireMock**: Would test the HTTP fetch but adds a test dependency and setup complexity for something we can verify manually once.

### Consequences
- Simple, low-ceremony approach to testing.
- The `open` keyword on a Spring `@Component` is slightly unusual in Kotlin but required since Kotlin classes are `final` by default.
- **Revisit when**: if we need multiple JWKS providers or caching, extract to an interface at that point.

## ADR-0032: Default display name for new users

Status: Accepted (revisit)
Date: 2026-06-02

### Context
When a user authenticates for the first time, we create their account. The `display_name` column is NOT NULL. Apple's identity token doesn't contain a display name — Apple provides name info only on the very first Sign In (via a separate field, not in the identity token itself).

### Decision
Set `displayName = "User"` as the default for newly created accounts. The iOS app will prompt the user to set their name immediately after first sign-in.

### Alternatives Considered
- **Require name in the auth request**: Would couple auth with profile setup, making the endpoint more complex. The iOS client may not have the name ready at auth time.
- **Nullable display_name**: Would require null-handling everywhere the name is used (leaderboards, group lists, etc.).

### Consequences
- User creation is simple — one endpoint, one concern.
- Briefly, a user exists with display name "User" until they update their profile.
- **Revisit when**: if we get name from Apple's initial sign-in response, we could pass it through.

## ADR-0033: No rate limiting on auth endpoints in MVP

Status: Accepted (revisit)
Date: 2026-06-02

### Context
Auth endpoints (`/auth/apple`, `/auth/refresh`) are public and could be targets for abuse or DDoS. Rate limiting is a common defense.

### Decision
Skip rate limiting for MVP. The Apple auth endpoint accepts cryptographically signed JWTs — you can't brute-force a valid token without Apple's private key. The refresh endpoint uses 256-bit random tokens — also not brute-forceable.

### Alternatives Considered
- **Spring Boot Bucket4j or resilience4j**: Adds a dependency and configuration for a threat that's low-risk given our token format.
- **API gateway rate limiting (AWS ALB / API Gateway)**: Better fit for production, but we don't have infrastructure yet.

### Consequences
- Simpler MVP with fewer moving parts.
- A determined attacker could still flood the endpoints to waste server resources (DDoS), even though they can't forge valid tokens.
- **Revisit when**: deploying to production. Add rate limiting at the API gateway level (per-IP, per-endpoint) to protect against resource exhaustion.

---

## ADR-0034: JWT filter writes error response directly (bypasses GlobalExceptionHandler)

Status: Accepted (revisit)
Date: 2026-06-02

### Context
The JWT authentication filter runs before Spring MVC's DispatcherServlet. When the filter rejects a request (no token, invalid token, expired token), it cannot throw an exception that would be caught by `@RestControllerAdvice` because exception handlers only apply to exceptions thrown inside the controller layer.

### Decision
The filter writes the 401 JSON error response directly to `HttpServletResponse` using Jackson's `ObjectMapper`, matching the same `ErrorResponse` structure used by the `GlobalExceptionHandler`.

### Alternatives Considered
- **Delegate to `AuthenticationEntryPoint`**: Spring Security's standard hook for authentication failures. Adds indirection — the filter would need to let the request through unauthenticated, then rely on Spring Security's access-denied flow. More framework-idiomatic but harder to reason about the error path.
- **Re-dispatch to an error controller**: Forward the request to a `/error` endpoint that returns the response. Adds a request cycle for something that should be a simple rejection.

### Consequences
- Error format stays consistent across filter and controller layers without coupling them.
- The filter owns its own serialization — if `ErrorResponse` changes shape, this must be updated too.
- **Revisit when**: if we add more filters that need to return structured errors (consider extracting a shared utility).

---

## ADR-0035: Public auth paths enumerated explicitly, not by `/auth/` prefix

Status: Accepted (revisit)
Date: 2026-06-06

### Context
Tasks 7–9 treated the entire `/auth/**` path space as public — both the JWT filter's `shouldNotFilter()` and the `SecurityConfig` rules used the `/auth/` prefix. Task 10 introduces `POST /auth/logout`, the first auth endpoint that *requires* authentication (it invalidates the caller's refresh tokens, so it needs to know who the caller is).

### Decision
Replace the `/auth/` prefix match with an explicit allow-list of public paths: `/auth/apple` and `/auth/refresh`. Both the filter (`JwtAuthenticationFilter.PUBLIC_PATHS`) and `SecurityConfig` now permit only those two. Everything else under `/auth`, including `/auth/logout`, flows through the JWT filter like any protected endpoint.

### Alternatives Considered
- **Keep `/auth/**` public, read the user from the request body**: Logout would have to accept a token/userId in its payload, which is unauthenticated and spoofable — any client could wipe another user's tokens.
- **Move logout outside `/auth`** (e.g. `/users/me/logout`): Would keep the prefix rule intact but fragments the auth surface; logout is conceptually an auth operation.

### Consequences
- Adding a new *public* auth endpoint now requires updating two places (filter set + SecurityConfig). This is intentional friction — public-by-default is the riskier mistake.
- Logout reuses the exact same JWT enforcement as protected endpoints; no special-casing.
- **Revisit when**: the public list grows — consider a single shared constant referenced by both the filter and SecurityConfig to avoid drift.

---

## ADR-0036: PATCH /users/me partial update cannot clear active_group_id

Status: Accepted (revisit)
Date: 2026-06-06

### Context
`PATCH /users/me` updates `display_name` and/or `active_group_id`. PATCH semantics mean a client sends only the fields it wants to change; omitted fields stay as they are. In Kotlin/Jackson the request DTO uses nullable fields with a `null` default (`displayName: String? = null`, `activeGroupId: UUID? = null`). An absent JSON field and an explicit `null` both deserialise to the same Kotlin `null`, so the service treats `null` as "leave unchanged" (`request.field?.let { ... }`).

### Decision
A `null`/absent `active_group_id` means "no change". There is therefore no way to *clear* `active_group_id` back to NULL through this endpoint. Clearing only happens implicitly via the leave/remove flows (Task 18), which set the active group to a fallback (another group or NULL) when the current one is left or the member is removed.

### Alternatives Considered
- **`JsonNullable<T>` (or an `Optional` wrapper) to distinguish absent from explicit-null**: lets the client send `"active_group_id": null` to clear it. Rejected for MVP as added complexity for a capability no current flow needs — the iOS app never asks the user to "have no active group" directly.
- **A sentinel value (e.g. empty string) to mean clear**: rejected as a hack that muddies the contract.

### Consequences
- Simple, conventional PATCH semantics; the DTO stays a plain data class.
- The active-group invariant (Property 16) is upheld on the *set* path here (membership is verified before assignment); the *fallback-to-null* path is owned entirely by Task 18.
- **Revisit when**: a product need arises to let a user explicitly deselect their active group — switch the field to `JsonNullable` at that point.

## ADR-0037: Image type validation by magic bytes, not Content-Type

Status: Accepted (revisit)
Date: 2026-06-06

### Context
`POST /users/me/avatar` must accept only JPEG or PNG (Property 6). A multipart upload carries a client-supplied `Content-Type` header per part, but that header is trivially spoofable — a client can label any bytes `image/jpeg`. We need a check that reflects the actual file contents.

### Decision
Validate the file by inspecting its leading bytes (the format's magic number): `FF D8 FF` for JPEG, `89 50 4E 47 0D 0A 1A 0A` for PNG. The declared `Content-Type` is ignored for validation. Anything that does not start with a recognised signature is rejected with 422.

### Alternatives Considered
- **Trust the multipart `Content-Type`**: simplest, but spoofable and therefore not a real validation. Rejected.
- **Full image decode (e.g. `ImageIO.read`)**: strongest guarantee (the bytes really are a decodable image) but pulls in decode cost and a dependency on the JDK image stack for what is, at this stage, a gatekeeping check. Deferred — magic bytes are enough to satisfy the property and stop obvious misuse.

### Consequences
- Cheap, dependency-free, and resistant to header spoofing.
- A file with a valid signature but corrupt body still passes (we only read the prefix). Acceptable for MVP; the bytes are stored as-is and served back via pre-signed URL.
- **Revisit when**: we start server-side transcoding (HEIC/PNG → JPEG, per the design doc's "converted on upload" note), at which point a real decode happens anyway and subsumes this check.

## ADR-0038: Avatar re-upload deletes old object after persisting new key

Status: Accepted (revisit)
Date: 2026-06-06

### Context
Re-uploading an avatar replaces the previous S3 object. The old key would otherwise leak (orphaned forever). S3 and the DB cannot share a transaction, so the order of "upload new", "persist new key", and "delete old" determines what a partial failure leaves behind.

### Decision
Order: (1) upload the new object to a fresh UUID key, (2) set `avatar_url` to the new key on the managed entity (committed by the surrounding `@Transactional`), (3) best-effort `deleteObject` on the previous key. If the delete fails, the user still has a working new avatar and the stale object is left for the orphan-cleanup job (Task 28) to reap.

### Alternatives Considered
- **Delete old first, then upload new**: a failure between the two would leave the user with no avatar and a dangling DB key. Worse user-facing outcome than a leaked object. Rejected.
- **Reuse a single deterministic key per user (overwrite in place)**: no orphan to clean, but loses the content-addressed-by-UUID property the rest of the codebase uses and makes pre-signed-URL cache-busting harder. Rejected for consistency with the existing key scheme.

### Consequences
- The user-visible state is always consistent: `avatar_url` points at an object that exists.
- A failed cleanup leaves at most one orphan per re-upload, bounded and recoverable by the cleanup job.
- The `deleteObject` call sits after the entity mutation but executes synchronously within the request; a slow delete adds latency. Acceptable given avatar uploads are rare. **Revisit when**: we move S3 deletes to an async dispatch (as pint deletion does), at which point avatar cleanup should use the same mechanism.

## ADR-0039: Servlet multipart limit set above all business size limits

Status: Accepted (revisit)
Date: 2026-06-06

### Context
Upload size is gated in two independent layers:

1. **Servlet/container layer** (`spring.servlet.multipart.max-file-size`, currently `10MB`). Enforced by embedded Tomcat *during multipart parsing, before the controller runs*. Exceeding it throws `MaxUploadSizeExceededException` — which `GlobalExceptionHandler` does not handle, so it falls through to a generic 500.
2. **Application layer** (explicit `bytes.size > LIMIT` checks in the service). Enforces the per-endpoint business rule (5 MB avatars, 10 MB pint photos per Property 6) and throws `UnprocessableException` → a clean 422.

These two collide at the boundary. The servlet limit is a single global number; it cannot distinguish an avatar request (5 MB rule) from a pint request (10 MB rule). With the servlet limit set *equal to* the largest business limit (10 MB = the pint-photo limit), an over-limit **pint** photo trips the servlet gate *first* and yields an unhandled 500 — never reaching the in-code check that was supposed to return 422. The avatar endpoint is unaffected only because its 5 MB rule sits comfortably below the 10 MB servlet gate, so the 5–10 MB band still produces a clean 422.

### Decision
Set the servlet `max-file-size` **strictly above the largest business size limit** (e.g. `11MB` or `15MB`, with `max-request-size` a little higher again to allow for multipart overhead + metadata parts). This makes the **application-layer checks the single authoritative source of truth** for upload size rules. The servlet limit reverts to its proper role: a coarse abuse backstop that only fires on absurd uploads, well outside any legitimate request.

### Alternatives Considered
- **Add `@ExceptionHandler(MaxUploadSizeExceededException)` mapping it to 422**: makes even servlet-gate rejections return a sane status. More robust against genuinely huge uploads (rejects before fully buffering), but splits the "max size" rule across two places (yml + handler) and lets the container, not the service, decide the business outcome. *Not chosen as the primary mechanism, but a reasonable backstop to add alongside #1 later.*
- **Leave the limits equal (status quo)**: rejected — produces an unhandled 500 for the exact case the spec says must be a 422, and the failure is silent (the in-code check looks correct but is dead code at the boundary).

### Consequences
- All upload-size validation lives in service code, returns a consistent 422 with a readable message, and is unit/integration-testable without provoking container-level errors.
- The servlet limit still protects the process from memory/disk exhaustion by truly enormous uploads — it just no longer overlaps with any legitimate business limit.
- A truly over-the-servlet-limit upload still yields an unhandled 500 until/unless we also add the `@ExceptionHandler` backstop (alternative above). Acceptable: that band is abuse, not normal use.
- **Revisit when**: we add a third upload type with a larger limit, or decide to add the `MaxUploadSizeExceededException` handler as defence-in-depth.

### Note for Task 21 (POST /pints)
Pint photos have a **10 MB** business limit — currently *equal* to the servlet `max-file-size`, so the in-code 10 MB check would be dead at the boundary (over-limit → 500, not 422). **Before/while implementing Task 21:** raise `spring.servlet.multipart.max-file-size` above 10 MB (and bump `max-request-size` accordingly) so the in-code 10 MB check is the one that fires and returns 422, as the task's test matrix requires ("Photo over 10 MB → 422"). The avatar endpoint already works because 5 MB < 10 MB; this only needs fixing for the pint-photo path.


---

## ADR-0040: Account deletion — DB cascade in one transaction, S3 cleanup async after commit

Status: Accepted (revisit)
Date: 2026-07-09

### Context
Deleting an account (Property 28) must remove the user and everything that references them across seven tables, plus their photos in S3. The DB and S3 cannot participate in one transaction. Requirement 8.6 mandates "no partial deletion state" at the DB level; the design doc (§4 Account Deletion) prescribes a single DB transaction followed by an async S3 batch.

### Decision
`AccountService.deleteAccount` runs entirely inside one `@Transactional` method. It:
1. Collects the S3 keys (all `pint_logs.photo_url` for the user + `users.avatar_url`) **before** deleting the rows that hold them.
2. Resolves each group's fate (see ADR-0042), reassigns creator ownership (ADR-0041), then bulk-deletes `pint_logs`, `refresh_tokens`, `leaderboard_snapshots`, `group_blocks`, `group_members`, and finally the `users` row.
3. Registers a `TransactionSynchronization.afterCommit` hook that hands the collected keys to `S3CleanupDispatcher.deleteObjects`, an `@Async` (`@EnableAsync`) fire-and-forget method. Per-key failures are logged and left for the orphan-cleanup job (Task 28).

### Alternatives Considered
- **Delete S3 objects inline before/after the DB work, synchronously**: blocks the request on S3 latency for a potentially large batch, and an inline delete that runs before commit would orphan-delete live photos if the transaction later rolls back. Rejected.
- **Register the S3 dispatch with `@Async` but call it directly (not via `afterCommit`)**: the async task could start before the transaction commits (or after a rollback), deleting photos for a user who was never actually deleted. `afterCommit` guarantees the DB delete is durable first. Chosen.
- **DB-level `ON DELETE CASCADE` foreign keys**: would remove the explicit per-table delete code, but the schema (V2–V8) defines plain `REFERENCES` without cascade, and the group-fate logic (promotion / group deletion / ownership handoff) needs application-level decisions that a blanket cascade can't express. Rejected for MVP; revisit if the delete list grows.

### Consequences
- DB deletion is atomic: a failure anywhere rolls back the whole cascade, so there is never a half-deleted user.
- S3 cleanup is eventually consistent, not transactional. A crash between commit and the async dispatch, or an S3 outage, leaves orphaned objects — bounded and reclaimed by the orphan-cleanup job.
- The default `@Async` executor is Spring's `SimpleAsyncTaskExecutor` (a new thread per call, unbounded). Fine for the current low volume. **Revisit when**: deletion volume grows — configure a bounded pool, or move to the SQS + DLQ design the doc mentions.

---

## ADR-0041: Account deletion reassigns `groups.created_by` to satisfy the NOT NULL creator FK

Status: Accepted (revisit)
Date: 2026-07-09

### Context
`groups.created_by` is `UUID NOT NULL REFERENCES users(id)` (V3). When a user who created a group deletes their account but the group survives (it has other members), deleting the `users` row would violate this FK — the group would point at a non-existent creator.

### Decision
Before deleting the user row, for every surviving group the user created, reassign `created_by` to the longest-standing remaining member (ADR-0042). Groups that are being deleted anyway (user was sole member) are skipped.

### Alternatives Considered
- **Make `created_by` nullable and null it on creator deletion**: loses the "who made this group" record and requires a schema migration. `created_by` is currently informational only (admin rights live in `group_members.role`), so nulling would be harmless, but reassigning to a real member keeps the column meaningful. Rejected for now.
- **`ON DELETE SET NULL`**: same nullability requirement, plus pushes the decision into the schema. Rejected.

### Consequences
- `created_by` always references a live member of a surviving group.
- The reassigned creator gains no special power (rights are role-based), so this is a bookkeeping fix, not an authorization change.
- **Revisit when**: we decide `created_by` should be nullable, or attach real semantics to it — either would change this handling.

---

## ADR-0042: Longest-standing member inherits admin / ownership on deletion

Status: Accepted (revisit)
Date: 2026-07-09

### Context
When the sole admin of a group deletes their account and other members remain, the group needs a new admin (design §Property 28f: "the longest-standing member SHALL be promoted"). Ownership reassignment (ADR-0041) needs the same choice of heir.

### Decision
The heir is the member with the earliest `joined_at` among the remaining members (`others.minByOrNull { it.joinedAt }`). Promotion only happens when the leaving user is an admin **and** no other admin already exists; if any other admin remains, no promotion is needed. Ties on `joined_at` are broken arbitrarily by `minByOrNull`.

### Alternatives Considered
- **Promote a random member**: simpler but non-deterministic and not what the spec says. Rejected.
- **Promote all remaining members to admin**: over-grants privileges. Rejected.
- **Deterministic tie-break (e.g. lowest UUID)**: `joined_at` collisions are near-impossible at real timestamps; not worth the extra code for MVP. Revisit if tests need determinism on identical timestamps.

### Consequences
- A group is never left admin-less after its sole admin deletes their account.
- If multiple admins exist, deleting one leaves the others in place with no reshuffle.
- **Revisit when**: we add an explicit tie-break rule, or let users choose their successor before deleting.

---

## ADR-0043: Invite codes via mixed-case Base62, DB-uniqueness with bounded retry

Status: Accepted (revisit)
Date: 2026-07-11

### Context
Group creation must produce a unique 8-character alphanumeric invite code (Requirement 3.3, Property 10). The schema declares `groups.invite_code` as `VARCHAR(8) UNIQUE`. We need a generation strategy that satisfies the format and guarantees uniqueness.

### Decision
Generate each code as 8 characters drawn uniformly from the 62-character Base62 alphabet (`A–Z`, `a–z`, `0–9`) using a single shared `SecureRandom`. After generating, check `groupRepository.existsByInviteCode(code)`; on collision, retry up to 10 times, then throw `IllegalStateException`. Case is significant — `ABCD1234` and `abcd1234` are distinct codes, matching the DB's case-sensitive unique index.

### Alternatives Considered
- **Uppercase-only (36 chars)**: friendlier to type/say aloud, but 36^8 ≈ 2.8e12 vs 62^8 ≈ 2.2e14 — a smaller space. Kept mixed-case for the larger keyspace; can revisit for UX. 
- **Rely solely on the DB unique constraint + catch the violation**: works, but the retry-on-`exists` loop keeps the happy path clean and avoids surfacing a `DataIntegrityViolationException`. The DB constraint remains the ultimate backstop.
- **UUID-derived / sequential codes**: sequential is guessable; UUID is longer than 8 chars. Rejected.

### Consequences
- Collision probability is negligible at MVP scale, so the loop almost always succeeds on the first attempt.
- The bounded retry (10 attempts) means a pathologically saturated keyspace fails loudly rather than looping forever — though that is astronomically unlikely.
- The `exists` check is a read before the insert; a concurrent creator could still race to the same code, but the DB `UNIQUE` constraint would then reject the second insert. Acceptable for MVP given the collision odds.
- **Revisit when**: we want human-friendlier codes (uppercase-only, ambiguity-free alphabet excluding `0/O/1/l`), or codes become high-volume enough to warrant precomputation.

---

## ADR-0044: Group creation limit counted from `groups.created_by`

Status: Accepted (revisit)
Date: 2026-07-11

### Context
Requirement 3.2 caps a user at 99 *created* groups (422 on the 100th). We must decide what "created" counts: groups the user made, or groups they belong to.

### Decision
Enforce the limit with `groupRepository.countByCreatedBy(userId) >= 99`. The count is based on `groups.created_by`, so it counts groups the user originally created — independent of membership. A user can still *join* unlimited groups; only creation is capped.

### Alternatives Considered
- **Count `group_members` rows where role = admin**: conflates promotion-to-admin with creation, and admin count changes as membership churns. Rejected — the requirement says "created".
- **Count all memberships**: would cap joining too, which the requirement does not ask for. Rejected.

### Consequences
- Account deletion reassigns `created_by` to an heir (ADR-0041), which means a surviving heir's created-count can rise when they inherit a group they didn't create. This is an accepted quirk: the cap is a coarse anti-abuse guard, not an exact accounting of authorship. 
- The check is a cheap indexed `COUNT`; no need to load rows.
- **Revisit when**: the `created_by` reassignment quirk matters, or we want the limit to track "groups currently owned" with a dedicated counter.

---

## ADR-0045: Group join check order: not-found → already-member → blocked

Status: Accepted (revisit)
Date: 2026-07-11

### Context
`POST /groups/join` has four outcomes (Property 11 / Requirements 3.5, 3.7–3.9): 404 unknown code, 409 already a member, 403 blocked, or success. When more than one condition could apply to the same request, the order in which we check them determines which status the client sees.

### Decision
Check in this fixed order and short-circuit on the first match:
1. **Resolve the invite code** → 404 if no group matches.
2. **Already a member?** → 409.
3. **Blocked (`group_blocks` row)?** → 403 with "You have been removed from this group".
4. Otherwise → insert `group_members` with role `member`, auto-set active group if none.

### Alternatives Considered
- **Blocked before already-member**: a removed user cannot also be a current member (removal deletes the membership and inserts the block), so the two are mutually exclusive in practice; order between them is only theoretical. We still fix an order for determinism and put the membership check first because it is the cheaper, more common case.
- **404 last (validate membership first)**: leaks nothing useful and would require a group context we don't have until the code resolves. Rejected — code resolution must come first.

### Consequences
- A blocked user probing an unknown code gets 404, not 403 — no information leak about which groups they are blocked from.
- The membership and block lookups are single indexed reads (`findByUserIdAndGroupId`, `findByGroupIdAndUserId`); the whole method is one `@Transactional` unit.
- **Revisit when**: removal semantics change such that a user could be both a member and blocked simultaneously.

---

## ADR-0046: Group detail hides non-members behind 403 (never 404)

Status: Accepted (revisit)
Date: 2026-07-11

### Context
`GET /groups/{id}` must reject non-members (Property 26 / Requirement 7.2). A request for a group the caller doesn't belong to and a request for a group that doesn't exist are two distinct failure modes; we must decide whether to distinguish them (404 vs 403) or collapse them.

### Decision
Check membership first (`findByUserIdAndGroupId`) and throw `ForbiddenException` (403) if there is no membership row — before ever loading the group. A non-existent group therefore also returns 403, because a random UUID has no membership row for the caller either. Only after membership is confirmed do we load the group and its members.

### Alternatives Considered
- **404 for missing group, 403 for non-member**: leaks group existence. An attacker enumerating UUIDs could distinguish "real group I'm not in" (403) from "no such group" (404), revealing which IDs are live. Rejected on the same information-hiding grounds as ADR-0045.
- **Load group first, then check membership**: an extra DB read on the unauthorized path and easy to accidentally leak details (e.g. via an error message) before the auth check runs. Rejected — auth check goes first.

### Consequences
- A non-member and a bad UUID are indistinguishable to the client. This is intentional: the endpoint reveals nothing about groups you can't see.
- The member list is assembled by resolving each `group_members` row to its `UserEntity` (N+1 reads) and pre-signing avatar URLs. Fine at MVP group sizes; **revisit when** groups grow large enough that a single join query or batch fetch is worth the complexity.
- `memberCount` in the detail response is derived from the loaded member list (`members.size`) rather than a separate `COUNT`, keeping the count and the list consistent within one transaction. The list endpoint (`GET /groups`) still uses `countByGroupId` because it never loads the members.

---

## ADR-0047: Group rename reuses the 403-before-404 auth pattern, admin-only

Status: Accepted (revisit)
Date: 2026-07-11

### Context
`PATCH /groups/{id}` renames a group and is an admin-only action (Requirement 10.13, Property 26 / Requirement 14.3). Three distinct failure modes overlap: the group may not exist, the caller may not be a member, or the caller may be a non-admin member. We must decide the order of the validation and authorization checks and which HTTP status each produces.

### Decision
Check in this fixed order:
1. **Validate the name** (trimmed length 1–50) → 400 with a field-level error. This runs first so a malformed request is rejected identically regardless of who sends it.
2. **Resolve membership + role** (`findByUserIdAndGroupId`) → 403 if there is no membership row *or* the role is not `admin`. Both a non-member and a non-admin member get the same 403.
3. **Load the group** and apply the rename; bump `updated_at` explicitly.

A non-existent group also yields 403, because a random UUID has no membership row for the caller — the same information-hiding stance as ADR-0046.

### Alternatives Considered
- **Auth before validation**: would let an admin's malformed name and a non-admin's malformed name diverge (403 vs 400), leaking role information through validation behaviour. Putting validation first keeps a bad body a 400 for everyone. Rejected.
- **Distinguish non-member (403) from non-existent group (404)**: leaks group existence to UUID enumeration, exactly as rejected in ADR-0046. Rejected for consistency.
- **Distinguish non-admin member (403) from non-member (403 or 404)**: no benefit — both are "you can't do this" and collapsing them is simpler. Kept collapsed.

### Consequences
- Validation-before-auth means an unauthenticated-but-malformed body is still gated by the JWT filter (401) before reaching the controller; within the controller, a member/non-member/admin distinction never affects the 400 path.
- `updated_at` is set manually (`group.updatedAt = Instant.now()`) rather than via a JPA lifecycle callback, matching how `UserService` handles its own `updated_at`. **Revisit when** we adopt JPA auditing (`@PreUpdate` / `@LastModifiedDate`) project-wide.
- The response is the same `GroupResponse` shape as create/join (id, name, inviteCode, role, memberCount), so the client reuses one decoder.

---

## ADR-0048: Single remove/leave endpoint branches on caller-vs-target identity

Status: Accepted (revisit)
Date: 2026-07-11

### Context
`DELETE /groups/{id}/members/{userId}` serves two conceptually different actions (Requirements 3.11/3.14/3.15 for admin removal; 3.17/3.18 for voluntary leave). They share a URL but differ in who is allowed to call them, what side effects they have (a block row on removal, none on leave), and their failure modes (sole-admin-with-members is a 400 only on the leave path).

### Decision
Branch inside `GroupService.removeMember` on whether the path `userId` equals the authenticated caller:
- **`userId == caller` → leave flow.** Sole admin with other members → 400 "Promote another admin before leaving"; sole member → delete the group; otherwise → drop the membership. No block row is written — a voluntary leaver may re-join.
- **`userId != caller` → remove flow (admin-only).** Non-member/non-admin caller → 403; target not a member → 404; otherwise delete the membership **and** insert a `group_blocks` row so the removed user can't re-join with the invite code (Requirement 3.9). Their `pint_logs` are deliberately left in place.

### Alternatives Considered
- **Two separate endpoints** (`DELETE .../members/{id}` for removal, `POST .../leave` for self): clearer intent, but the iOS client would still send the caller's own id to leave, and the REST-canonical "delete my membership resource" is exactly `DELETE .../members/{me}`. One endpoint keeps the URL space smaller. Rejected for MVP; revisit if the flows diverge further.
- **Block on leave too**: would prevent a user who left from re-joining, contradicting Requirement 3.17's "voluntary" framing. Rejected — blocks are a moderation tool, not a self-service one.

### Consequences
- The removed/leaving user's active-group fallback (Requirement 3.23) runs on the **affected** user, not the caller — on removal that's the target, on leave it's the caller. A shared `clearActiveGroupIfPointingAt(userId, groupId)` handles both.
- A sole-member leave reuses the same group-teardown as account deletion (delete pints/blocks/snapshots/members, then the group, then async S3 cleanup after commit). That logic now lives in **two** places (`AccountService.deleteGroup` and `GroupService.deleteGroup`); **revisit when** a third caller appears — extract a `GroupTeardownService`.
- Fallback and teardown order matters: the active-group reference is cleared **before** the group/membership row is deleted, so the `users.active_group_id → groups` FK never dangles mid-transaction.

---

## ADR-0049: `BadRequestException` for message-only 400s

Status: Accepted (revisit)
Date: 2026-07-11

### Context
The sole-admin-leave case must return 400 with a plain explanatory message ("Promote another admin before leaving"). The existing `ValidationException` always serialises a `errors: [{field, message}]` array, which is wrong here — there's no offending *field*, the whole request is validly formed but rejected by group state. No other exception mapped to 400.

### Decision
Add a `BadRequestException(message)` that the `GlobalExceptionHandler` maps to `400` with the standard message-only `ErrorResponse` (no `errors` array), exactly as `ForbiddenException`/`NotFoundException` are handled. Use it for bad *request state*; keep `ValidationException` for malformed *input fields*.

### Alternatives Considered
- **Reuse `ValidationException` with a synthetic field** (e.g. `field = "role"`): misleads the client into thinking a form field is wrong. Rejected.
- **Reuse `UnprocessableException` (422)**: 422 is already taken for the group-creation limit; the spec (Task 18) explicitly says 400 for this case, and semantically the request is malformed-in-context, not un-processable-entity. Rejected to stay faithful to the task.

### Consequences
- There are now two distinct 400 shapes: field-level (`ValidationException` / bean-validation) and message-only (`BadRequestException`). Clients must handle both, but they already tolerate an absent `errors` array (it's nullable in `ErrorResponse`).
- **Revisit when** we have several message-only 400s and want to standardise an error `code` enum instead of matching on human-readable strings.

---

## ADR-0050: Promotion mutates role in place, idempotent, no demotion counterpart

Status: Accepted (revisit)
Date: 2026-07-11

### Context
`POST /groups/{id}/members/{userId}/promote` (Requirement 3.12) raises a member to admin. It's the third admin-gated group action and reuses the now-familiar shape: resolve caller membership → 403 if not an admin, resolve target membership → 404 if not present, then act. Task 19 explicitly requires promoting an already-admin to be a no-op success (idempotent).

### Decision
Load the target's `GroupMemberEntity` and set `role = ROLE_ADMIN` directly; JPA dirty-checking flushes the update on commit — no explicit save. Promoting an existing admin sets `admin` over `admin`, which is a silent no-op, satisfying idempotency for free. Return 204 No Content (no body), matching the remove/leave endpoint's response shape rather than returning the mutated membership.

### Alternatives Considered
- **Return the updated membership/group** (200 with body): the iOS client already refetches group detail after admin actions, and the other membership-mutating endpoint (remove/leave) returns 204. Chose 204 for consistency. Revisit if the client needs the new role echoed back.
- **Guard on current role and skip the write when already admin**: unnecessary — assigning the same value is already a no-op, and the guard adds a branch with no observable difference. Rejected.
- **A `demote` counterpart in the same task**: out of scope — no requirement covers demotion, and it raises the "can't remove the last admin" question that leave-flow already answers. Deferred.

### Consequences
- Auth-before-existence ordering means a non-admin promoting a stranger gets 403 (not 404): the caller learns nothing about who is or isn't in a group they can't administer — same information-hiding stance as ADR-0047/0048.
- No block/active-group side effects, so promotion doesn't touch `group_blocks` or `users.active_group_id` — it's the simplest of the admin actions.
- **Revisit when** demotion or "transfer admin" is added; promotion + the sole-admin-leave rule (ADR-0048) together imply a group can accumulate admins but the last one can never leave without promoting first.

---

## ADR-0051: Invite-code regeneration reuses the generator, invalidation is implicit

Status: Accepted (revisit)
Date: 2026-07-11

### Context
`POST /groups/{id}/invite-code/regenerate` (Requirement 3.10) lets an admin mint a fresh invite code and must invalidate the previous one immediately. The fourth admin-gated group action, structurally identical to `updateGroup` (ADR-0047): resolve caller membership → 403 if not an admin, then mutate the group.

### Decision
Reuse the existing private `generateUniqueInviteCode()` (retry-on-collision, bounded attempts — ADR from Task 14) rather than a second generation path. Overwrite `group.inviteCode` in place; JPA dirty-checking flushes on commit. "Invalidation" of the old code is a free consequence: `invite_code` is a unique column with a single value, so `findByInviteCode(old)` returns nothing once overwritten — no tombstone, no separate revoke step. Return the updated `GroupResponse` (200 with body) so the client gets the new code to display/share directly.

### Alternatives Considered
- **Return 204 No Content** (like promote/remove): the whole point of this call is to hand the caller a new code, so echoing it back in the body is the natural fit — unlike promote, where the mutated value is uninteresting. Chose 200 + body.
- **Track historical/revoked codes** (a `revoked_invite_codes` table or a `valid` flag): unnecessary for MVP. A group has exactly one live code; old codes simply cease to resolve. Rejected as over-engineering. Revisit if we ever need to audit who shared which code, or support multiple simultaneous codes.

### Consequences
- Auth-before-existence ordering: a non-admin (or non-member) regenerating gets 403, never leaking whether the group exists — same stance as ADR-0047/0050.
- Because generation reuses the shared helper, the invite-code format guarantee (8 alphanumeric, collision-checked) holds identically for created and regenerated codes.
- **Revisit when** invite links/QR codes are added (Requirement 3.10 also names those): they'll need to be derived from the current code so regeneration invalidates them too.

---

## ADR-0052: Image magic-byte validation extracted to a shared `ImageValidation` helper

Status: Accepted (revisit)
Date: 2026-07-11

### Context
Task 12 (avatar upload) validated image type by magic bytes (ADR-0037) with private `isJpeg`/`isPng` functions living inside `UserService`. Task 21 (pint photo upload) needs the identical check — same two formats, same byte signatures — differing only in the size limit (10 MB vs 5 MB) and the error message wording.

### Decision
Lift the magic-byte checks into a stateless `com.pintking.api.common.ImageValidation` object exposing `isJpeg`, `isPng`, and `isJpegOrPng`. Both `UserService` and `PintService` call it. The size limit and the human-readable message stay in each service (they differ per endpoint); only the format-detection logic is shared.

### Alternatives Considered
- **Duplicate the byte checks in `PintService`**: rejected — two copies of the same signature table drift over time (e.g. if we later accept a third format, or fix an edge case in one and forget the other).
- **A full `FileValidator` that also enforces size**: rejected as premature — the size limit and message are genuinely per-endpoint, so folding them in would need parameters that add more surface than they remove. Kept the shared piece to exactly the invariant part (the byte signatures).

### Consequences
- One place defines "what is a valid image" for the whole API; adding a format (or the HEIC handling hinted at in ADR-0015) is a single edit.
- `ImageValidation` is a plain object with no Spring wiring, trivially unit-testable and cheap to call.
- **Revisit when** we add server-side HEIC→JPEG conversion (ADR-0015): detection and conversion may want to live together, changing this helper's shape.

---

## ADR-0053: Pint metadata as flat multipart form fields, not a JSON part

Status: Accepted (revisit)
Date: 2026-07-11

### Context
`POST /pints` is a multipart request: a mandatory `photo` file plus optional metadata (`note`, `drinkType`, `latitude`, `longitude`). The task text describes the metadata as "optional JSON metadata". Two encodings are possible: a single `application/json` part holding an object, or individual form fields alongside the file.

### Decision
Accept the metadata as separate multipart form fields bound with `@RequestParam` on the controller, mirroring the avatar endpoint's `@RequestParam("file")` style. The controller assembles them into a `CreatePintMetadata` data class before calling the service, so the service still takes one typed object.

### Alternatives Considered
- **A JSON `@RequestPart` metadata object**: closer to the task wording and tidier for large payloads, but mixing a JSON part with a file part in Spring MockMvc/`multipart` tests is fiddlier, and the client (iOS, `URLSession` multipart per ADR-0009) already builds form fields naturally. For four flat scalar fields, form params are simpler with no real downside.
- **All metadata via query string, only the file in the body**: rejected — semantically the note/location are part of the created resource, not a query, and query strings are logged more freely (a note is user content).

### Consequences
- Controller signature is explicit about every accepted field; Spring handles type coercion (e.g. `latitude` → `Double`) and returns 400 on a malformed number without custom code.
- The service layer is transport-agnostic (takes `CreatePintMetadata`), so a later switch to a JSON part only touches the controller.
- **Revisit when** metadata grows structured/nested (e.g. multiple tags), at which point a JSON part earns its keep.

---

## ADR-0054: Pint group derived from the author's `active_group_id`, not the request

Status: Accepted (revisit)
Date: 2026-07-11

### Context
Every `pint_logs` row has a NOT NULL `group_id`. Requirement 4.6 says a pint is associated with "the User and the Active_Group". The request could carry a `groupId`, or the API could read the author's current `active_group_id`.

### Decision
The API ignores any client-supplied group and uses the authenticated user's `active_group_id` as the pint's group. If the user has no active group, creation is rejected with a 400 before any S3 upload.

### Alternatives Considered
- **Client sends `groupId`**: rejected — it duplicates state the server already owns (`users.active_group_id`, ADR-0003) and opens an authorization hole (a user could post to a group they aren't in, requiring an extra membership check). Deriving it server-side makes "you can only log to your active group" true by construction.
- **Default the group but allow an override**: rejected as unused — the iOS flow (Requirement 4.2/4.3) logs to the active group only; there is no UI to pick a group at capture time.

### Consequences
- Property 17b ("associated with the user's current active_group_id") holds by construction — there is no other code path.
- Requirement 4.2 (client disables logging with no active group) is backed by a server guard: a 400, so the invariant can't be violated even by a direct API call.
- A member is always a member of their active group (ADR-0003/Property 16 keep `active_group_id` pointing at a joined group), so no separate membership check is needed here.
- **Revisit when** we support logging to a non-active group (would require a request field + explicit membership check).

---

## ADR-0055: `saveAndFlush` to make the S3-first orphan-cleanup catch reachable

Status: Accepted (revisit)
Date: 2026-07-11

### Context
S3-first ordering (ADR-0001) requires: on a DB-insert failure *after* a successful S3 upload, enqueue the orphaned object for cleanup and return 500. The service wraps the insert in a try/catch to do this. But with UUID-generated ids (ADR-0011 uses DB-side `gen_random_uuid()`; the entity uses `GenerationType.UUID`), Hibernate has no need to hit the DB at `save()` time — it can defer the INSERT to transaction commit, which happens *after* the method returns and *outside* the try/catch. A constraint or connectivity failure would then surface at commit, bypassing the cleanup entirely.

### Decision
Use `pintLogRepository.saveAndFlush(...)` rather than `save(...)` for the pint insert. The explicit flush forces the INSERT to execute synchronously inside the try block, so a DB failure is caught there and the orphaned S3 key is dispatched to `S3CleanupDispatcher`.

### Alternatives Considered
- **Plain `save()`**: rejected — the catch block becomes dead code for the exact failure mode it exists to handle (deferred INSERT throws at commit, past the catch).
- **A `TransactionSynchronization.afterCompletion(STATUS_ROLLBACK)` hook to fire cleanup**: works without a flush and even catches commit-time failures, but is heavier and less obvious than forcing the write where the ordering contract already lives. Kept in reserve if we later need to catch failures that only manifest at commit (e.g. deferred constraints).

### Consequences
- The orphan-cleanup path is actually exercised by `PintServiceOrderingTest` (mocked `saveAndFlush` throwing), not just present-but-unreachable.
- One extra flush per pint creation — negligible, and the row is being written immediately anyway.
- The insert still participates in the surrounding `@Transactional`, so a later failure in the same method would still roll the row back (not a concern today — nothing runs after the insert).
- **Revisit when** additional writes are added after the insert within the same transaction, or if we move to app-generated UUIDs (which would make `save()` flush eagerly regardless).

---

## ADR-0056: Latitude/longitude are all-or-nothing (400 if only one supplied)

Status: Accepted (revisit)
Date: 2026-07-11

### Context
Location on a pint is optional (Requirement 4.13/4.15 — omitted silently if GPS isn't available). It is stored as a single PostGIS `GEOMETRY(Point, 4326)` built from a (longitude, latitude) pair. A client could, by bug, send only one of the two coordinates.

### Decision
Validate that `latitude` and `longitude` are either both present or both absent. Exactly one present is a 400 with a `location` field error. Both absent → the pint is created with a null location; both present → a `Point` is constructed and stored.

### Alternatives Considered
- **Silently drop a lone coordinate** (treat as no location): rejected — it hides a client bug and produces a pint that silently lost its location, which is harder to diagnose than a clear 400.
- **Accept a lone coordinate and store a partial/zeroed point**: rejected — a point needs both axes; a zeroed one would be a real location (off the coast of Africa at 0,0), i.e. silent data corruption.

### Consequences
- A malformed location request fails loudly and early (before S3 upload), consistent with the other metadata validations.
- The JTS `Coordinate(lng, lat)` axis order (x=longitude, y=latitude) is applied in one place; the response echoes `latitude = point.y`, `longitude = point.x`.
- **Revisit when** we accept location in a different shape (e.g. a GeoJSON part), which would move this pairing check.

---

## ADR-0057: Period filtering derives an inclusive lower bound in-service (UTC), not a DB date function

Status: Accepted (revisit)
Date: 2026-07-11

### Context
`GET /pints?period=this_week|this_month` filters the feed by `logged_at`. The bound could be computed in SQL (`date_trunc('week', now())`) or in the service and passed as a parameter.

### Decision
Compute the inclusive lower bound in Kotlin: `this_week` = Monday 00:00 UTC of the current ISO week (`TemporalAdjusters.previousOrSame(MONDAY)`), `this_month` = the 1st at 00:00 UTC. `all_time` → no bound. The bound is passed to a derived Spring Data query (`findByGroupIdAndLoggedAtGreaterThanEqualOrderByLoggedAtDesc`). An unrecognised period is a 400 `period` field error; a missing period defaults to `all_time`.

### Alternatives Considered
- **`date_trunc` in a `@Query`**: rejected — pushes the timezone decision into SQL where it's less visible, and it's the same logic the leaderboard (Task 25) will need, so keeping it in Kotlin lets both share a helper later.
- **Half-open upper bound too (`< next period`)**: unnecessary — pints can't be logged in the future, so a lower bound alone is exact.

### Consequences
- All period maths is UTC. The requirement text mentions the user's local timezone; MVP treats "current week/month" as UTC and revisits if per-user timezones are added.
- **Revisit when** the leaderboard lands — the `periodStart` helper should be lifted to a shared location rather than duplicated.

---

## ADR-0058: Feed pagination — 0-based `page`, default size 20, hard cap 100

Status: Accepted (revisit)
Date: 2026-07-11

### Context
`GET /pints` is offset-paginated via Spring Data `Pageable`. The client controls `page` and `size`; both need defaults and bounds so a caller can't request an unbounded or negative page.

### Decision
`page` defaults to 0 and is clamped to `>= 0`; `size` defaults to 20 and is clamped to `1..100`. Out-of-range values are silently coerced, not rejected. The response uses the existing `PageResponse` envelope (`data`, `page`, `size`, `total`) with `total` taken from `Page.totalElements`.

### Alternatives Considered
- **400 on an out-of-range size**: rejected — coercion is friendlier for a paging control and matches the "be liberal in what you accept" stance already used for optional params.
- **Cursor/keyset pagination**: rejected for MVP — offset paging is simpler and the feed is small; keyset can come later if deep pages become slow.

### Consequences
- The cap bounds the worst-case query and the number of pre-signed URLs generated per request.
- `page`/`size` echoed back are the *coerced* values, so the client sees what was actually applied.
- **Revisit when** feeds grow large enough that offset paging on high page numbers is slow.

---

## ADR-0059: Feed authors batch-loaded via `findAllById`, not per-pint lookups

Status: Accepted (revisit)
Date: 2026-07-11

### Context
Each feed item carries the author's `displayName` and pre-signed `avatarUrl`. Naively resolving the author inside the per-pint mapping would issue one `findById` per row (N+1).

### Decision
Collect the page's distinct `user_id`s and load them in a single `userRepository.findAllById(...)`, keyed into a map for O(1) lookup during mapping. An author missing from the map (e.g. a since-deleted user) yields null `displayName`/`avatarUrl` rather than failing the request.

### Alternatives Considered
- **A JPA `@ManyToOne` from `PintLogEntity` to `UserEntity`**: rejected — the entity is deliberately id-only (no relationship graph), and a join fetch would still need care to avoid N+1; the explicit batch load is simpler and keeps the entity flat.
- **A projection/join query returning pint + author columns**: reasonable, deferred — the two-query approach is clear and the page is capped at 100, so it's cheap enough for MVP.

### Consequences
- Exactly two queries back the feed (the page + the authors), independent of page size.
- Former/deleted authors degrade gracefully to null identity fields instead of 500-ing.
- **Revisit when** the feed needs more author fields or the two-query pattern recurs enough to justify a projection.

---

## ADR-0060: Pint update is a partial PATCH; absent fields untouched, blank note clears

Status: Accepted (revisit)
Date: 2026-07-11

### Context
`PATCH /pints/{id}` (Task 23) edits an existing pint's `note` and/or `drink_type`. The request DTO has both fields nullable, and JSON omission deserialises to null — so a null value is ambiguous between "not supplied" and "explicitly clear this". We had to pick a semantics and stay consistent with the rest of the API.

### Decision
Treat the PATCH as partial: apply a field only when it is present (non-null) in the body, using `request.field?.let { ... }`. An absent field leaves the persisted value untouched. For `note`, a present-but-blank value (whitespace) is trimmed to null, clearing the note — the same trim-to-null rule used at creation. `drink_type` has no clear-via-blank path; a present value must be a valid enum member. Only the creator may update (403 otherwise), and a missing pint is 404 (checked before the ownership guard). Photo and location are immutable via this endpoint. The dirty entity is flushed by the surrounding `@Transactional`, so there is no explicit `save`.

### Alternatives Considered
- **Mirror `PATCH /users/me` exactly (no clear path)**: the user PATCH also uses `?.let`, but its fields are non-clearable. We extend the same pattern and additionally allow `note` clearing because an empty note is a legitimate end state a user may want.
- **A distinct sentinel to distinguish "omit" from "set null"** (e.g. `JsonNullable`): rejected as over-engineered for two fields; blank-string-clears covers the only field that can meaningfully be cleared.
- **Require the note field always present**: rejected — that makes drink-type-only edits awkward and breaks the partial-update contract clients expect from PATCH.

### Consequences
- Clients edit one field without resending the other; there is no risk of a round-trip accidentally wiping the untouched field.
- The validation logic (280-char note, enum drink type) is duplicated from create rather than shared — small enough to accept for now.
- **Revisit when** a third updatable field appears or a caller genuinely needs to distinguish "leave note" from "clear note" without sending whitespace.

---

## ADR-0061: Pint delete 24h window is inclusive and measured against wall-clock now

Status: Accepted (revisit)
Date: 2026-07-11

### Context
`DELETE /pints/{id}` (Task 24) may only succeed within 24 hours of the pint's `logged_at` (Requirements 4.16–4.18, Property 19). Two things needed pinning down: the exact boundary semantics (is exactly-24h in or out?) and where the S3 photo delete fires relative to the DB delete. The design (`l3-api.md` "Pint Deletion: DB-First", ADR-0002) mandates DB-first: delete the row in the transaction, then dispatch the S3 delete after commit.

### Decision
The check is `Duration.between(loggedAt, Instant.now()) > 24h → 400`. This makes the window **inclusive** of the exact 24-hour mark (a pint exactly 24h old is still deletable; only strictly older is rejected) and measures elapsed time against the request's wall-clock `Instant.now()`, not any DB-side clock. The 24h duration lives as a private `DELETE_WINDOW` constant on `PintService`. The 404-then-403-then-400 ordering matches the rest of the pint endpoints: missing pint → 404, not-the-creator → 403, outside window → 400. The photo key is captured before `delete(pint)`, and the S3 delete is dispatched via a `TransactionSynchronization.afterCommit` hook (the same pattern as `AccountService`) so a rollback never orphan-deletes a live photo. An S3 failure is swallowed by `S3CleanupDispatcher` and left to the orphan-cleanup job — the row stays deleted regardless.

### Alternatives Considered
- **Exclusive boundary (`>=` rejects at exactly 24h)**: functionally indistinguishable in practice (nanosecond-exact hits are impossible), but `>` reads as "more than 24 hours" which matches Requirement 4.17's wording ("older than 24 hours").
- **Dispatch S3 delete inline before/after the DB delete without an after-commit hook**: rejected — an inline pre-commit dispatch could delete the photo then have the transaction roll back, orphaning a still-referenced row's expectation; the after-commit hook is the established DB-first pattern.
- **Enforce the window in SQL (`DELETE ... WHERE logged_at > now() - interval '24h'`)**: rejected — we need to distinguish 404 (no such pint), 403 (not creator), and 400 (too old) with distinct responses, which a single conditional DELETE can't express cleanly.

### Consequences
- The window is evaluated on the API server's clock; clock skew between app servers is the only thing that could shift the boundary, and it's sub-second.
- Reusing the `afterCommit` dispatch pattern keeps deletion consistent with account deletion — a rollback can never trigger a photo delete.
- A failed S3 delete leaves an orphan that the cleanup job reclaims; the user's delete still appears (correctly) successful.
- **Revisit when** deletion needs an audit trail (soft-delete) or the window becomes configurable per group.

---

## ADR-0062: Period logic lifted to a shared `Periods` helper

Status: Accepted
Date: 2026-07-11

### Context
ADR-0057 flagged that the `periodStart` helper on `PintService` should be lifted to a shared location "when the leaderboard lands". Task 25's leaderboard needs the same current-week / current-month lower bound to filter pints, plus a second piece of period maths the feed never needed: the `(period_type, period_key)` of the *previous* completed period, to look up the snapshot the rank delta is measured against (ADR-0005).

### Decision
Introduce `common/Periods.kt` — an `object` holding the period constants (`all_time`/`this_week`/`this_month`), the `ALLOWED` set, `lowerBound(period)` (the inclusive UTC start, previously `PintService.periodStart`), and `previousSnapshotKey(period)` (last week's `"YYYY-Www"` or last month's `"YYYY-MM"`). `PintService` now calls `Periods.lowerBound` / `Periods.ALLOWED` and its private `periodStart` is deleted. Both `lowerBound` and `previousSnapshotKey` take an optional `now` parameter defaulting to `Instant.now()` so tests can pin a clock without touching wall time.

### Alternatives Considered
- **Leave `periodStart` on `PintService` and have the leaderboard duplicate it**: rejected — exactly the duplication ADR-0057 said to avoid; the two would drift.
- **A Spring `@Service` bean instead of an `object`**: rejected — the logic is pure and stateless (no injected collaborators), so a plain object is simpler and needs no wiring.
- **ISO week key via manual date arithmetic**: rejected in favour of `java.time.temporal.IsoFields` (`WEEK_BASED_YEAR` + `WEEK_OF_WEEK_BASED_YEAR`), which handles the year-boundary edge cases (e.g. a week that spans Dec/Jan) correctly.

### Consequences
- One source of truth for "what does this_week mean"; the feed and leaderboard can never disagree.
- The `period_key` format (`YYYY-Www`, `YYYY-MM`) is now pinned in one place and must match what the snapshot job (Task 26) writes — that job will consume the same helper.
- Still UTC-only, inheriting ADR-0057's revisit condition for per-user timezones.

---

## ADR-0063: Leaderboard dense ranking, zero-pint members, and former-member split

Status: Accepted (revisit)
Date: 2026-07-11

### Context
`GET /groups/{id}/leaderboard` (Task 25) ranks members by pint count for a period. Several semantics needed pinning: how ties rank, whether a current member with no pints appears, and how "former members" (users with pints in the group but no current membership — the retained-log case from ADR-0004) are handled (Requirement 5.12, Property 23).

### Decision
Counts are aggregated in the DB via `PintLogRepository.countByUser(groupId)` / `countByUserSince(groupId, from)`, returning one row per user who logged (a `UserPintCount` projection), so a group with thousands of pints returns at most one row per user. Ranking is computed in Kotlin: current members sorted by count descending, then a single pass assigns **dense** ranks (equal counts share a rank; the next distinct count is previous rank + 1, not + tie-count). A current member with **zero** pints still appears, ranked last with count 0 (the count map simply has no entry for them → treated as 0). Former members are `counts.keys − memberIds`: they get their own `formerMembers` array (sorted by count desc, no rank) and are excluded from the ranked set so their pints never shift an active member's rank. Rank 1 — including every member of a top tie — carries `isCrown = true` (Requirement 5.5). The response shape is `{ period, entries, formerMembers }`.

### Alternatives Considered
- **Standard competition ranking (1, 1, 3)**: rejected — Requirement 5.6 explicitly specifies dense ranking (1, 1, 2).
- **Rank in SQL with a window function (`DENSE_RANK() OVER (ORDER BY count DESC)`)**: viable, but the delta join against snapshots and the former-member split are cleaner in Kotlin, and the member set is small (a group's membership, not its whole log). Kept ranking in-service alongside the delta computation.
- **Omit zero-pint members**: rejected — Requirement 5.1 ranks "all Group_Members", so a member who hasn't logged this period is rank-last, not absent.
- **Fold former members into the main list flagged**: rejected — Requirement 5.12 wants a visually separate, unranked section; a separate array makes the contract explicit.

### Consequences
- Ranking and delta live in one readable pass; if the member set ever grows large, the ranking could move to a window function without changing the response contract.
- The former-member split depends on the ADR-0004 invariant that removal deletes `group_members` but retains `pint_logs`.
- **Revisit when** ranking cost matters at scale (push `DENSE_RANK` into SQL) or a member's zero-pint appearance is undesirable in some period views.

---

## ADR-0064: Rank delta reads the previous period's snapshot; null for all_time and first period

Status: Accepted
Date: 2026-07-11

### Context
For week/month views the leaderboard shows each member's rank movement vs. the previous period's final ranking (Requirements 5.7/5.8, Property 22). ADR-0005 established `leaderboard_snapshots` as the delta baseline. Task 25 consumes those snapshots even though the writer job (Task 26) doesn't exist yet.

### Decision
Delta = `previousSnapshotRank − currentRank` (positive = climbed). The service resolves the previous period via `Periods.previousSnapshotKey(period)`, loads that period's snapshot rows for the group, and builds a `userId → rank` map. For each ranked member: if a snapshot rank exists, delta is the difference; if not (member is new this period, or no snapshot was ever written), delta is `null`. For `all_time`, `previousSnapshotKey` returns null and every delta is `null` (Requirement 5.9) — a stray weekly snapshot cannot leak into an all_time response because the key is never computed.

### Alternatives Considered
- **Default a missing snapshot to rank = member count + 1 (treat newcomers as "last")**: rejected — Property 22 says a missing prior snapshot yields a null delta, not a fabricated movement.
- **Compute the previous period's ranking on the fly from `pint_logs`**: rejected by ADR-0005 (expensive, and the snapshot is the stable baseline).

### Consequences
- Until Task 26 writes snapshots, every week/month delta is null — correct behaviour, just no movement shown yet.
- The delta's correctness is entirely coupled to the snapshot job writing the same `period_key` format `Periods` produces; both now share that helper.
- Members who leave and rejoin, or who had no rank last period, correctly show no delta rather than a misleading jump.

---

## ADR-0065: Leaderboard snapshot job — per-period cron, per-group isolation, exists-check idempotency

Status: Accepted (revisit)
Date: 2026-07-11

### Context
Task 26 writes the `leaderboard_snapshots` rows that ADR-0005/ADR-0064's delta reads back. It runs at period boundaries and must (a) snapshot the *completed* period, (b) be idempotent on re-runs, (c) store nothing for groups with no pints in the period, and (d) produce rankings identical to what the read endpoint shows.

### Decision
A `@Scheduled` `LeaderboardSnapshotJob` (`@EnableScheduling` on the app) with two cron entries, both UTC: weekly `0 5 0 * * MON` and monthly `0 5 0 1 * *`. Each computes a `Periods.CompletedPeriod` (the just-ended week/month, as a `(periodType, periodKey, from, until)` tuple) and loops over all groups. `CompletedPeriod` reuses `previousSnapshotKey` for its key and `lowerBound` for `until`, so the boundary and key format can't drift from the reader. Counts come from a new **bounded** query `countByUserBetween(groupId, from, until)` — a past period needs both ends, unlike the live feed's lower-bound-only `countByUserSince`. Only current members who logged in the period are ranked and stored (former members excluded per ADR-0004; zero-pint members omitted because dense ranking makes their absence invisible to the loggers' ranks, and this yields "no pints → no rows" for free). Idempotency is a pre-insert `existsByGroupIdAndPeriodTypeAndPeriodKey` check, backstopped by the table's unique `(group, user, period_type, period_key)` constraint. Each group is wrapped in a try/catch so one group's failure is logged and skipped, not fatal to the run.

### Alternatives Considered
- **Compute `until` independently in the job**: rejected — deriving it from `Periods.lowerBound(current)` guarantees the completed-period boundary is exactly the current-period boundary the feed uses.
- **Rely solely on the unique constraint for idempotency (no pre-check)**: the constraint is the real guarantee, but a naive `saveAll` on a re-run would throw a `DataIntegrityViolation` mid-batch; the exists-check makes a re-run a clean no-op.
- **One transaction for the whole job**: rejected — a single bad group would roll back every other group's snapshot. Per-group try/catch isolates failures; `saveAll` still writes each group's rows atomically.
- **Snapshot zero-pint members too (to mirror the endpoint's row-for-every-member)**: unnecessary — the snapshot only feeds the delta lookup, which is keyed by user; a member absent from the snapshot correctly yields a null delta, same as a brand-new member.

### Consequences
- The job and the read endpoint share `Periods` and `DenseRanking`, so a snapshot's ranks match what the leaderboard showed at period close.
- Snapshots are UTC-boundary, inheriting ADR-0057/0062's revisit condition for per-user timezones.
- A missed run (downtime across the boundary) leaves that period's deltas null until manually backfilled — acceptable per ADR-0005.
- **Revisit when** group count grows enough that `findAll()` over every group per run is costly (page it, or shard the job), or a manual/backfill trigger is needed.

---

## ADR-0066: Dense ranking extracted to a shared `DenseRanking` helper

Status: Accepted
Date: 2026-07-11

### Context
Task 25's read endpoint and Task 26's snapshot job both assign dense ranks to a group's members by pint count. Duplicating the ranking pass would let the stored snapshot and the live leaderboard drift — exactly the delta-baseline mismatch ADR-0064 warns about.

### Decision
Lift the ranking pass into `leaderboard/DenseRanking.kt` — a stateless `object` with `rank(userIds, counts): List<Ranked>`. It sorts by count descending and assigns dense ranks (equal counts share a rank; next distinct count is +1). `LeaderboardService.rankMembers` now maps its output into `LeaderboardEntry` (adding display name, avatar, delta, crown); the job maps the same output into `LeaderboardSnapshotEntity`. The helper deliberately knows nothing about users, deltas, or persistence — just IDs and counts in, ranks out.

### Alternatives Considered
- **Leave ranking inlined in each caller**: rejected — two copies of Property 20's logic that must stay byte-for-byte identical to keep deltas correct.
- **Rank in SQL with `DENSE_RANK()`**: still deferred (see ADR-0063) — the shared Kotlin helper keeps ranking next to the delta/crown decoration and is trivially unit-testable.

### Consequences
- One implementation of dense ranking; the snapshot and the endpoint can't disagree by construction.
- The helper's "zero-pint members sort last and don't shift loggers" property is what lets the job pass only loggers while the endpoint passes full membership and still agree on the loggers' ranks.

## ADR-0067: Map bounding-box via native `ST_Within` + `ST_MakeEnvelope` queries

Status: Accepted (revisit)
Date: 2026-07-11

### Context
Task 27's `GET /pints/map` must return only pints whose `location` falls inside the client's viewport (Requirement 6.8, Property 24), pushing the spatial filter into PostGIS rather than fetching a group's whole log and filtering in Kotlin. JPQL/HQL has no portable spatial predicates, and the `location` column is a raw `geometry(Point,4326)` backed by a GIST index.

### Decision
Two `@Query(nativeQuery = true)` methods on `PintLogRepository`: `findInBoundingBox(groupId, box)` and `findInBoundingBoxForUser(groupId, userId, box)`. Both use `ST_Within(location, ST_MakeEnvelope(:swLng, :swLat, :neLng, :neLat, 4326))`. `ST_MakeEnvelope`'s argument order is `(xmin, ymin, xmax, ymax, srid)` = `(sw_lng, sw_lat, ne_lng, ne_lat, 4326)` — longitude is x, latitude is y, mirroring how the JTS `Coordinate(lng, lat)` is built on write. An explicit `location IS NOT NULL` guard makes Property 24c (null locations never returned) obvious at the query, even though `ST_Within` on a null yields null (not true) anyway. Native `SELECT *` maps cleanly back to `PintLogEntity` because the query returns whole rows.

### Alternatives Considered
- **Fetch all group pints, filter the box in Kotlin**: rejected — defeats the point of PostGIS and the GIST index; transfers the whole log to filter it down (Requirement 6.8 is explicitly about limiting data transfer).
- **Hibernate Spatial JPQL functions (`within`, `st_within`)**: possible but adds a dialect-function dependency for two queries; raw native SQL is clearer and the GIST index is used identically.
- **`ST_Contains`/`&&` bounding-box operator**: `ST_Within(a, b)` is the readable "a inside b" form; the `&&` index operator is what GIST uses under the hood regardless.

### Consequences
- The two queries are the only native SQL in the codebase; they bypass JPQL type-checking, so a column rename wouldn't be caught at compile time.
- Points exactly on the envelope boundary follow `ST_Within` semantics (boundary points are *not* strictly within); acceptable for a map viewport where the box is the visible screen.
- **Revisit when** the map needs clustering/heatmap (Post-MVP Requirement 10) or result caps — a bare `ST_Within` returns every matching pin with no limit.

## ADR-0068: Map returns a bare pin array (no pagination envelope)

Status: Accepted (revisit)
Date: 2026-07-11

### Context
Every other list endpoint (`GET /pints`) returns the `{ data, page, size, total }` `PageResponse` envelope (ADR-0012/0058). The map endpoint returns pins for a viewport, not a scrollable page.

### Decision
`GET /pints/map` returns a plain `List<MapPin>` (JSON array), not a paginated envelope. The viewport bounding box *is* the bound — the client asks for exactly the region it can render, so page/size/total add nothing. The response is capped only by how many pints fall in the box.

### Alternatives Considered
- **Reuse `PageResponse`**: rejected — there is no meaningful page or total for a spatial query; the client never paginates a map, it re-queries on pan/zoom with a new box.

### Consequences
- Response shape is inconsistent with the feed, but intentionally so — a map and a feed are different access patterns.
- No server-side cap on pin count. A pathologically large box (whole world) over a huge group returns everything. **Revisit when** clustering/heatmap lands (Requirement 10) — that's the natural place to cap or aggregate.

## ADR-0069: Map scope defaults to `group`; former members flagged, never filtered

Status: Accepted (revisit)
Date: 2026-07-11

### Context
`scope` is an optional query param (`personal` | `group`). The endpoint must also render former members' pins greyed out (Requirement 6.6) rather than dropping them.

### Decision
An absent `scope` defaults to `group` (the shared view), matching the home screen's default map mode. `personal` restricts to the caller's own `user_id` via the dedicated query; `group` returns all authors' pins in the box. Former members are computed exactly as the leaderboard does (ADR-0063/Property 23): an author with pints but no current `group_members` row is flagged `isFormerMember = true` and still returned — the flag greys the pin client-side, it never removes the pin. Membership is resolved with one `findByGroupId` set after the spatial query, and authors are batch-loaded via `findAllById` (same N+1 avoidance as the feed, ADR-0059).

### Alternatives Considered
- **Make `scope` required**: rejected — a sensible default (`group`) keeps the common call terse; the client can always be explicit.
- **Exclude former members from the map**: rejected — Requirement 6.6 wants their historical pins visible-but-distinct, same stance as the leaderboard's "Former Members" section.
- **Personal scope ignores `group_id`**: rejected — personal pins are still scoped to the active group's map, so both `group_id` and `user_id` bound the query; a user's pints in another group don't leak in.

### Consequences
- Map and leaderboard share the same former-member definition, so a pin's grey state matches the roster's grey row.
- `personal` scope still requires group membership (403 otherwise) — you can't view your own pins on a group you've left.
- **Revisit when** a "my pints across all groups" map is wanted — that would need a scope that drops the `group_id` filter.

---

## ADR-0070: Orphan cleanup diffs bucket keys against DB references, guarded by a grace window

Status: Accepted (revisit)
Date: 2026-07-12

### Context
Three flows cross the DB ↔ S3 boundary non-transactionally and can leave S3 objects with no DB reference: pint creation is S3-first (ADR-0001), so a DB-insert failure after upload orphans the object; pint deletion is DB-first (ADR-0002) and account deletion is DB-cascade-then-async-S3, so a failed/lost async delete leaves the object behind. All three name a scheduled cleanup job as the safety net (l3-api.md §4). Both `pint_logs.photo_url` and `users.avatar_url` store the S3 **key** (not a URL), so "referenced" is exact string equality on keys.

### Decision
A daily `@Scheduled` job (03:15 UTC) computes the set difference `all bucket keys − all referenced keys` and deletes the remainder. Referenced keys come from two projection queries (`findAllPhotoKeys`, `findAllAvatarKeys`) that select only the key column, not whole rows. Bucket keys come from `S3Service.listAllObjects()`, which follows `ListObjectsV2` continuation tokens so the 1000-key page cap doesn't silently truncate the scan.

The load-bearing guard is a **grace window** (`app.cleanup.orphan-grace-minutes`, default 60): an object is only deleted if it is both unreferenced *and* last modified before `now − grace`. Because creation is S3-first, an object is legitimately unreferenced in the gap between its upload and its DB insert; the grace window keeps such in-flight uploads off the delete list. DB references are read *before* the bucket is listed, so any reference that could be missed belongs to an object newer than the cutoff anyway — the window covers it. Per-object delete failures are caught and logged, not fatal; the next run retries.

### Alternatives Considered
- **No grace window (delete any unreferenced object immediately)**: rejected — it races the S3-first creation flow and would delete a photo uploaded seconds before its DB row exists.
- **Per-object existence check (query the DB once per S3 object)**: rejected — N queries for N objects; the two projection queries + an in-memory `HashSet` is one round-trip per table and O(1) membership tests.
- **SQS-consumer / event-driven cleanup**: rejected for MVP — needs extra infrastructure; a periodic full-bucket sweep is the simplest net that also catches orphans from *any* cause, not just enqueued ones.
- **List whole entities to get keys**: rejected — loads columns and geometry we don't need; projections scan just the key column.

### Consequences
- The sweep is O(bucket size) each run; fine at MVP scale, but a large bucket means a full `ListObjectsV2` walk daily. **Revisit when** the bucket grows enough that a full scan is costly — a marker-based incremental scan or event-driven deletes would replace it.
- An orphan lives at most ~1 day + grace before reclamation; acceptable for cost, and users never see it (nothing references it).
- The grace default (60 min) is comfortably longer than any realistic upload→insert gap; if a deploy ever made that gap larger, the window is a single config knob.
- Deleting a DB reference before its object (deletion flows) is always safe here: the object just becomes eligible on a later run.

---

## ADR-0071: Property-based tests assert invariants against independent oracles, one spec per property

Status: Accepted (revisit)
Date: 2026-07-12

### Context
The design doc (l3-api.md §6) marks 13 correctness properties as **(PBT)** — invariants that must hold across *all* valid inputs, not just the hand-picked examples the endpoint tests already cover. Task 29 implements them with `kotest-property`'s `checkAll`, ≥100 iterations each. Two questions had to be settled: (a) what plays the role of the "expected" value when the input is random, and (b) at what layer each property runs.

### Decision
**Independent oracle, never the implementation restated.** Each property asserts against a computation derived straight from the specification, phrased differently from the production code, so a bug in the code can't hide behind the same bug in the test. Examples: bounding-box membership is checked with an in-JVM `lat > swLat && … && lng < neLng` rectangle test, not by re-running PostGIS; the JPEG/PNG signature is spelled out as a literal byte prefix rather than calling `ImageValidation`; time-period filtering recomputes the Monday-00:00 boundary from `java.time` adjusters independently of `Periods`.

**One spec file per property**, under a new `property/` test package, each documented with the design's `Feature: pint-king, Property N: <text>` tag in its class KDoc. Layer is chosen per property:
- **Pure specs** (no Spring context) for logic with no DB dependency — file-type detection (6), dense ranking (20), period bounds (21), and the create/validate/delete-window service rules (17, 18, 19) with the repository and S3 mocked. These run in milliseconds and fuzz hundreds of cases cheaply.
- **Container-backed specs** (`@SpringBootTest` + Testcontainers Postgres/LocalStack, same companion-object pattern as every other integration spec) for properties whose meaning *is* the database: invite-code uniqueness and join outcomes (10, 11), the active-group invariant under a random join/leave walk (16), authorization by role (26), rank delta (22), the PostGIS bounding box (24), and the account-deletion cascade (28). Each iteration cleans the tables first and uses an `AtomicInteger` suffix to keep unique columns (`apple_id`, `invite_code`) distinct across the hundreds of rows a run creates.

Iteration counts are set per property (100–500) rather than a blanket 100 — cheap pure fuzzers run more; expensive container walks that reseed the DB every iteration run fewer but still ≥ the design's floor.

### Alternatives Considered
- **Assert against the implementation's own helper** (e.g. call `Periods.lowerBound` on both sides): rejected — a tautology; it proves the function equals itself, not that it's correct.
- **All properties as pure/mocked tests**: rejected — the DB-dependent properties (unique constraints, `ST_Within`, cascade FKs) have no meaning without the real engine; mocking them would test the mock.
- **All properties through the HTTP layer (MockMvc)**: rejected — most PBTs target a service/pure function; driving 500 iterations through the full servlet stack is far slower and adds nothing for logic that isn't about routing or serialization.
- **One giant `PropertyTest` file**: rejected — one spec per property keeps each independently runnable and its `Feature/Property` tag unambiguous.
- **Generate points exactly on the box edge for Property 24**: deliberately avoided — points are generated strictly inside/outside so the assertion never hinges on `ST_Within`'s boundary semantics, which the property text doesn't pin down.

### Consequences
- The container-backed property specs each stand up their own Postgres + LocalStack (per-class companion object, as the rest of the suite does), so a full `./gradlew test` run is dominated by these — several minutes. Acceptable for a portfolio project; **revisit when** the suite is slow enough to warrant a shared container or a Kotest tag that runs PBTs only in CI.
- The near-boundary skip in the deletion-window property (Property 19) trades a hair of coverage at exactly 24h for freedom from clock-timing flakes; the exact boundary is still pinned by the example test in PintDeleteTest.
- Properties without the **(PBT)** mark (1–5, 7–9, 12–15, 23, 25, 27) stay example-based in their existing endpoint specs — this task added no tests for them by design.
- A failing property prints the falsifying seed, so any future regression reproduces deterministically.

---

## ADR-0072: End-to-end tests drive real HTTP journeys, threading tokens between calls

Status: Accepted (revisit)
Date: 2026-07-12

### Context
Every endpoint already has a per-endpoint integration test, but each of those seeds its state directly through the repositories (`userRepository.save(...)`, `jwtService.generateToken(...)`) and exercises one endpoint in isolation. Task 30 asks for *end-to-end flows* against real containerised infrastructure. The open question was what an E2E test should add that the per-endpoint tests don't — otherwise it's just duplication.

### Decision
**E2E specs drive complete client journeys purely over HTTP and thread the real outputs of one call into the next.** A single `EndToEndTest` (new `e2e/` package) signs in through `POST /auth/apple` for a genuine JWT + refresh token, then uses that JWT to create a group, reads the *returned* invite code to make a second user join, logs pints via multipart, and reads them back on the leaderboard/map — never reaching into a repository to fabricate an ID or token that a real client would have received from a prior response. Repositories and S3 are touched only to *assert* the promised side-effects landed, not to set state up.

This makes the specs test **composition**: that the invite code minted by create-group is the one join accepts; that the JWT issued by sign-in authorizes pint creation; that a pint's response `photoUrl` is a pre-signed URL a client can actually `GET` (the auth test fetches it over plain HTTP and checks the bytes match the upload); that removing a member creates the block that later makes their rejoin 403.

**Flow chaining over fresh seeding, where it makes a stronger assertion.** The group-join spec walks all four outcomes (200/404/409/403) as one sequence so the 403 is produced by a real prior removal rather than a hand-inserted block row. The leaderboard spec runs the real snapshot job over a backdated completed week, then flips the ranking this week via the live endpoint, asserting the delta the API computes against its own snapshot.

**One concession to HTTP's limits:** `loggedAt` can't be backdated through the API, so the completed-week pints the snapshot job reads are inserted through the repository. Everything a client controls still goes over HTTP.

### Alternatives Considered
- **Seed via repositories like the per-endpoint tests**: rejected — that's what those tests already do; it would never catch a mismatch *between* endpoints (e.g. a response field named differently from the request field the next endpoint expects).
- **A shared abstract base spec / shared containers across all integration tests**: deferred — the whole suite still follows the per-class companion-object container pattern. Consolidating is a suite-wide refactor, noted in ADR-0071's revisit trigger, not something to introduce for one new file.
- **Assert the pre-signed URL only by string-matching its shape**: rejected — actually fetching it over HTTP and comparing bytes is the only check that proves the presigner's endpoint/region/path-style config produces a URL that resolves against LocalStack.
- **Drive the snapshot rollover by manipulating the clock** instead of backdating rows: rejected — reseeding a completed period via `Periods.completedWeek()` is deterministic and needs no clock control.

### Consequences
- The `e2e/` package documents the intended client sequences in one place — useful as living documentation of how the iOS app is expected to string calls together.
- Like the other container specs, it stands up its own Postgres + LocalStack, adding to total suite time; same revisit trigger as ADR-0071 (shared container or a CI-only tag if the suite gets slow).
- Async S3 cleanup is verified with `eventually(10.seconds)` polling, mirroring the per-endpoint delete/account-deletion specs, since cleanup runs after commit on another thread.
- The one repository-seeded step (backdated pints) is called out in a comment so it isn't mistaken for a gap in HTTP coverage.

## ADR-0073: OpenAPI docs auto-generated from controllers, global bearer scheme, off in prod

Status: Accepted (revisit)
Date: 2026-07-12

### Context
Task 31 asks for browsable API documentation. The controllers, their request params, and the response DTOs already fully describe the surface; the question was how much to hand-author versus let a generator infer, and how the docs endpoints interact with the JWT security we already have.

### Decision
**Use SpringDoc (`springdoc-openapi-starter-webmvc-ui`) to generate the spec by scanning the live controller beans; add only the metadata a generator can't infer.** That metadata is: an `OpenApiConfig` bean with the API title/version and a single `bearerAuth` HTTP-bearer/JWT security scheme, applied globally with `addSecurityItem` so every operation renders with an authorize lock; and `@Tag`/`@Operation` annotations grouping and summarising each endpoint. Request and response schemas come for free from the Kotlin data classes.

**The two public endpoints opt out per-operation with `@SecurityRequirements` (empty)** — `/auth/apple` and `/auth/refresh` — so the doc reflects that they take no bearer token, matching the real `permitAll` rules.

**`@AuthenticationPrincipal userId: UUID` params are hidden with `@Parameter(hidden = true)`.** They're populated by the JWT filter, not sent by the client, so surfacing them as query/path parameters in the docs would be misleading.

**Docs are on by default (local/dev) and disabled in the `prod` profile.** A new minimal `application-prod.yml` sets `springdoc.api-docs.enabled=false` and `swagger-ui.enabled=false`; Task 32 will expand that file with the rest of the prod config.

**Both the JWT filter and Spring Security must let the docs through.** The `JwtAuthenticationFilter` short-circuits every request without a bearer token via `shouldNotFilter`, so it now also skips the `/v3/api-docs` and `/swagger-ui` prefixes; `SecurityConfig` `permitAll`s the same paths (including the bare `/v3/api-docs`, which `/v3/api-docs/**` alone does not match). Both layers are needed — the filter runs first and would 401 before the authorization rules apply.

### Alternatives Considered
- **Hand-write an OpenAPI YAML file**: rejected — it would drift from the code the moment a controller changes; generation stays in sync by construction.
- **Per-endpoint `@SecurityRequirement` on every authenticated operation** instead of one global requirement with opt-outs on the two public ones: rejected — far more annotations, and the default-secure posture is safer (a new endpoint is documented as requiring auth unless explicitly opted out).
- **Leave docs enabled in prod**: rejected — the surface and DTO shapes are internal detail; no reason to expose them publicly. Cheap to flip back on per-environment if wanted.
- **Only `permitAll` in SecurityConfig, without touching the filter**: rejected — doesn't work; the filter rejects tokenless requests before the security authorization rules are consulted.

### Consequences
- New endpoints appear in the docs automatically; only a `@Operation` summary and (if it's public) a `@SecurityRequirements` opt-out need remembering.
- The docs-reachability contract is asserted by `OpenApiDocsTest`: `/v3/api-docs` returns 200 without a token, every controller path is present, the bearer scheme is declared, and the two public endpoints carry an empty security array. If a route stops being scanned, a named path assertion fails.
- The permit rules live in two places (filter + security config) that must stay in sync — a mild duplication, flagged here as the revisit trigger if a third public-prefix category ever appears.
- Swagger UI is reachable at `/swagger-ui.html` in local/dev; hitting it in prod returns 404 by configuration.

## ADR-0074: Multi-stage Dockerfile; prod profile fails fast on missing env vars

Status: Accepted (revisit)
Date: 2026-07-12

### Context
The API needs to ship as a deployable container (AWS ECS/App Runner later). Two questions: how to build the image so incremental builds are fast and the runtime is lean, and how the `prod` profile should source deployment-specific config (DB, JWT secret, S3) so a misconfigured deploy is caught early rather than silently running with dev defaults.

### Decision
**Multi-stage Dockerfile.** A `gradle:8.8-jdk21` build stage (matching the wrapper's pinned toolchain) copies the build files first and resolves dependencies as a separate cached layer, then copies `src` and runs `bootJar`. The runtime stage is a slim `eclipse-temurin:21-jre` that copies only the boot jar, runs as a non-root `spring` user, and defaults `SPRING_PROFILES_ACTIVE=prod`.

**Tests are skipped in the image build (`-x test`).** The suite is Testcontainers-based and needs a Docker daemon that isn't available inside the build stage; tests run via `./gradlew build` in local/CI before the image is built. The Dockerfile builds a jar, it does not gate on tests.

**The `prod` profile pulls every deployment value from an env var with no default** — `DB_URL`/`DB_USERNAME`/`DB_PASSWORD`, `JWT_SECRET`, `S3_BUCKET`/`S3_ENDPOINT`/`S3_REGION`, `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`. Spring's placeholder resolution throws at startup if any is absent, so a misconfigured container crashes immediately instead of falling back to the dev secret and localhost endpoints baked into `application.yml`. The dev fallbacks stay in `application.yml` for the default/local profiles only.

**Health check on `/actuator/health`.** Actuator was already a dependency and the endpoint is already public in both the JWT filter and `SecurityConfig`. The `prod` profile narrows actuator's web exposure to `health` only (`show-details: never`), and the Dockerfile adds a `HEALTHCHECK` that curls it with a 40s start-period grace so the container reports `healthy` only once the DB connection is live.

### Alternatives Considered
- **Single-stage build shipping the whole Gradle image**: rejected — hundreds of MB of build tooling in the runtime image for no benefit; the JRE-only runtime is far smaller and has less attack surface.
- **Run tests inside the image build**: rejected — Testcontainers needs a Docker daemon (docker-in-docker) that isn't present in the build stage; tests belong in the CI step that precedes `docker build`.
- **Give prod config the same `${VAR:default}` fallbacks as `application.yml`**: rejected — that's exactly the silent-misconfiguration trap; a prod container missing `JWT_SECRET` would sign tokens with the well-known dev secret. No-default placeholders make the failure loud and immediate.
- **Run as root**: rejected — a dedicated non-root user is a cheap, standard hardening step.
- **Copy the whole repo into the build context**: mitigated with `.dockerignore` (excludes `build/`, `.gradle/`, `.env`, compose files) so the context stays small and secrets never enter the image.

### Consequences
- Image builds are incremental: editing source re-runs only the `bootJar` layer, not dependency resolution, because the dependency layer is keyed on the build files alone.
- A prod deploy that forgets any required env var fails at startup with a clear "Could not resolve placeholder" error — verified by running the image without `JWT_SECRET`.
- The `HEALTHCHECK` gives orchestrators (ECS/App Runner) a real readiness signal tied to DB connectivity, not just process liveness.
- Docs are already off in prod (ADR-0073); confirmed the docs routes don't serve a spec under the prod profile.
- Revisit triggers: the dependency-warming layer uses `gradle dependencies` which is approximate; if it proves flaky a `--write-verification-metadata` or explicit resolve task could replace it. If CI moves to building the image as the test artifact, the `-x test` decision and the "tests run before build" assumption need revisiting.

---

## ADR-0075: Keep empty feature folders with `.gitkeep`, excluded from the build via a sync-group membership exception

Status: Accepted (revisit)
Date: 2026-07-12

### Context
Task 1 establishes the feature-based folder structure (`Core/`, `Features/*`, `Repositories/`, `Utilities/`) up front, before most of those folders have any source files. Git does not track empty directories, so a fresh clone would lose the structure unless each folder holds at least one committed file. Separately, the Xcode project was scaffolded with a modern **file-system-synchronized root group** (`PBXFileSystemSynchronizedRootGroup`, objectVersion 77): target membership is derived from what's on disk, so any file under `PintKing/` is automatically part of the build — including non-source files. Placing a `.gitkeep` in each folder to preserve it in git caused every `.gitkeep` to be picked up as a bundle resource; since they share a basename they all resolved to the same `PintKing.app/.gitkeep` output path, and the build failed with "Multiple commands produce … .gitkeep".

### Decision
Keep a `.gitkeep` in each still-empty folder so git tracks the directory, and attach a **`PBXFileSystemSynchronizedBuildFileExceptionSet`** to the root group that lists every `.gitkeep` under `membershipExceptions` for the `PintKing` target. This is Xcode's native mechanism for keeping a file on disk while excluding it from a target's build. `App/` needs no `.gitkeep` because it already holds the moved `PintKingApp.swift` and `ContentView.swift`. Adding a real source file to a folder later does not require touching the exception set — only the folder's `.gitkeep` may eventually be deleted once the folder has real content.

### Alternatives Considered
- **Delete the `.gitkeep` files:** rejected — the empty folders would not be committed, so the folder structure this task delivers would not survive a fresh clone, defeating the point of the task.
- **Convert each folder to a manually-managed `PBXGroup`:** rejected — abandons the sync-group model and would force `project.pbxproj` edits every time a source file is added in later tasks. The sync group is the whole reason later tasks can drop `.swift` files in without editing the project file.
- **Use a differently-named marker per folder (e.g. `Keychain.keep`):** rejected — unique names would sidestep the output-path clash without an exception set, but `.gitkeep` is the conventional marker and the exception-set approach is the correct, discoverable Xcode idiom; it also keeps non-source files out of the shipped bundle regardless of their names.

### Consequences
- The folder structure is committed and reproducible from a clean clone.
- New Swift files added to any synced folder in later tasks are compiled automatically — no pbxproj edits.
- One maintenance note: if a *non-source* file that should not ship in the bundle is ever committed into a synced folder, it must be added to `membershipExceptions` too, or the build will treat it as a resource.
- Revisit trigger: once every folder has real source files, the `.gitkeep` files and their exception entries can be removed; not urgent, and harmless to leave.

---

## ADR-0076: iOS domain models double as API DTOs, decoded through one shared camelCase/ISO-8601 coder

Status: Accepted (revisit)
Date: 2026-07-12

### Context
Task 2 defines the iOS domain models (`User`, `Group`, `GroupMember`, `PintLog`, `LeaderboardEntry`, `Coordinate`) and shared enums (`DrinkType`, `Period`, `GroupMemberRole`), plus `APIError`. These types have to (a) be used across the app's layers as the in-memory domain representation and (b) decode from the JSON the Kotlin/Spring API emits. Two independent questions arose: whether to introduce a separate DTO layer that maps to distinct domain types, and how to configure JSON coding so the wire format is specified once rather than re-derived at every call site. The API serialises with Jackson defaults — **camelCase** field names (confirmed against existing ADRs: `inviteCode` in ADR-0047/0051, `isFormerMember` in ADR-0069, `displayName`/`activeGroupId` in ADR-0036) — and all timestamps are ISO 8601 UTC with no fractional seconds (ADR-0013).

### Decision
Use the Codable domain structs **directly as the API DTOs** — no separate DTO-to-domain mapping layer for MVP. Because the API is camelCase and Swift properties are camelCase, the synthesised `Codable` conformance matches the wire format with **no custom `CodingKeys`**. Enum raw values are set to the exact wire strings (`DrinkType`/`GroupMemberRole` lowercase matching the DB CHECK constraints; `Period` snake_case matching the `?period=` query param). All encoding/decoding goes through a single `enum JSONCoding` that vends a `JSONEncoder`/`JSONDecoder` pair configured with `.iso8601` date strategy, so the date format lives in exactly one place. `APIError` exposes a pure `from(statusCode:)` mapping (400 and 422 both → `.validationFailed`; 2xx → `nil`; unrecognised non-2xx → `.serverError`).

### Alternatives Considered
- **Separate DTO layer with mapping to domain types:** the textbook clean-architecture split. Rejected for MVP — the API response shapes *are* the shapes the UI needs; a mapping layer would be pure boilerplate with no divergence to absorb. Revisit if/when the client needs a field the API doesn't send (or vice versa).
- **`.convertFromSnakeCase` decoding + snake_case-free models:** would be required if the API were snake_case. It isn't (Jackson camelCase), so enabling it would be wrong and would silently mangle already-camelCase keys. Rejected on the facts.
- **Per-call-site `JSONDecoder()` construction:** rejected — every site would have to remember to set `.iso8601`, and a missed one would fail to parse the API's dates. Centralising in `JSONCoding` removes that footgun.
- **Enums keyed off Swift case names with a custom encoder transform:** unnecessary; string raw values are the simplest exact match to the DB/API strings and are self-documenting.

### Consequences
- Minimal code: no mapping layer, no `CodingKeys`, no bespoke coders scattered around. Mock repositories (Task 3) and the real `NetworkClient` (Task 26) both decode identical bytes into these types.
- The models are coupled to the API's serialization conventions. A change on the API side (e.g. switching to snake_case, or adding fractional-second timestamps) requires a coordinated change here — but it's localised to `JSONCoding` (format) and the affected struct (fields).
- Structs are `Equatable` + `Sendable` (Swift 6 concurrency-safe value types) and `Identifiable` where a natural id exists (`LeaderboardEntry.id` is a computed `userId`).
- **Revisit when:** the client's needs diverge from the API payloads enough to justify a real DTO/mapping layer, or the API changes its casing/date conventions.

---

## ADR-0077: Repository protocols are `@MainActor` class-bound with `async throws` methods

Status: Accepted (revisit)
Date: 2026-07-23

### Context
Task 3 defines the six repository protocols (`Auth`, `User`, `Group`, `Pint`, `Leaderboard`, `Map`). Two shapes had to be fixed now because everything downstream (mocks this task, ViewModels from Task 5 on, the real `NetworkClient` in Task 26) depends on them: the actor isolation of the protocol, and the async/error signature of its methods. The repositories are the app's shared-state owners (l3-ios-app.md §1) — SwiftUI reads their observable properties (`isAuthenticated`, `activeGroup`) on the main actor, and every method will eventually perform network I/O that can fail.

### Decision
Every repository protocol is annotated `@MainActor` and constrained to `AnyObject` (class-bound). All data-access methods are `async throws`. Reads return the domain model directly (`getGroups() async throws -> [Group]`); mutations that the UI needs the result of are `@discardableResult` and return the updated model; pure state changes return `Void`. Shared observable state is exposed as `{ get }` protocol properties (`activeGroup`, `pendingPints`, `currentUser`, `isAuthenticated`) so a ViewModel can observe it without knowing the concrete type. Errors are thrown as `APIError` (ADR-0076's typed enum).

### Alternatives Considered
- **`Sendable` protocols with `nonisolated`/`actor` conformers:** the more "concurrency-pure" route. Rejected for MVP — the repositories exist to feed SwiftUI, which is main-actor-bound; forcing everything through an actor hop would add `await` noise and Sendable-boxing for no benefit while all state lives on the main actor anyway. `@MainActor` matches how the state is actually consumed. Revisit if a repository needs to do heavy work off the main actor (then isolate just that work with a detached task, keeping the API main-actor).
- **Synchronous methods returning cached values:** rejected — the real repositories fetch over the network; a synchronous signature would force a later breaking change to every call site. `async` from day one keeps the mock and the real implementation signature-identical.
- **Returning `Result<T, APIError>` instead of `throws`:** rejected — `try await` composes better with Swift concurrency and SwiftUI's `.task`/`do-catch`, and avoids a wrapper type at every call site.
- **Struct-based protocols (value-type repositories):** rejected — repositories hold mutable shared state and must be reference-observed by multiple views; `AnyObject` + `@Observable` class is the right tool.

### Consequences
- Mocks and the real `NetworkClient`-backed repositories are drop-in interchangeable: identical signatures, so swapping them at the composition root (Task 26) touches no ViewModel.
- ViewModels can be written and tested now against the protocols with mocks injected, exactly as the tests in this task do (variables typed as the protocol, not the concrete mock).
- `@MainActor` on the protocol means conformers are implicitly main-actor; the mocks don't need their own annotation for isolation but carry `@MainActor` explicitly for clarity.
- **Revisit when:** a repository needs genuine off-main-actor concurrency, or the error surface needs richer payloads than `APIError`'s cases.

---

## ADR-0078: Mock repositories are stateful `@Observable` classes over one shared `MockData` fixture set

Status: Accepted (revisit)
Date: 2026-07-23

### Context
Task 3 requires mock implementations returning "realistic hardcoded data (2–3 groups, 5–8 members, 10–20 pint logs)" so the entire UI can be built before the backend is wired in. Two questions: where the fixture data lives, and whether the mocks are inert (always return the same constants) or stateful (reflect mutations like joining a group or deleting a pint). The UI flows they must support — switch active group, create/join/leave group, edit/delete pint, promote member — are inherently stateful; an inert mock would make those screens untestable and unusable in previews.

### Decision
A single `enum MockData` namespace holds all fixtures as `static let`s, keyed by shared stable `UUID` constants (`daveId`, `fridayId`, …) so a leaderboard entry's `userId`, a group member's `userId`, and a pint's `userId` all line up for the same person. Every `Mock*Repository` is a `@MainActor @Observable final class` that seeds itself from `MockData` and then keeps its **own mutable copy** of anything the app can change (group list, per-group members, active group, pint store). Mutations persist for the session and are observable. Fixtures are dated relative to a fixed `MockData.now` (2026-07-01T12:00:00Z), not the wall clock, so time-dependent behaviour (the 24h pint-delete window) is deterministic across runs. `MockAuthRepository` exposes a `shouldFailLogin` flag so the Login error path (Task 6) is drivable without a backend. Leaderboards are **curated arrays**, independent of the pint store, mirroring that the real leaderboard is computed server-side rather than from the pints the client holds — and are deliberately seeded with a rank-1 tie (two crowns), a dense-ranked tie lower down, and a former member (unranked, own section) to exercise the leaderboard UI's edge cases.

### Alternatives Considered
- **Inert mocks returning constants:** simplest, but can't represent state changes; the group-switcher, join/leave, and edit/delete screens would have nothing to react to. Rejected — the point of the mocks is to build those flows.
- **Per-repository private fixtures:** rejected — IDs wouldn't line up across domains, so a leaderboard row couldn't navigate to the right member's pints. One shared `MockData` keeps the graph consistent.
- **Deriving the leaderboard from the mock pint store:** rejected — couples two fixtures that are independent in production (the API computes ranks with snapshots/deltas the client never recomputes) and would make it hard to stage specific ranking edge cases. Curated boards are clearer and match reality.
- **Using `Date()` for fixture timestamps:** rejected — the 24h delete-window test would flip behaviour depending on when it runs. A fixed `now` keeps fixtures and tests deterministic (and mirrors the workflow-script rule against wall-clock reads).

### Consequences
- The whole UI can be built and demoed on mock data with realistic, internally-consistent state, and previews/tests can inject a fresh mock per case (fixtures are re-seeded on `init`, so tests don't leak state into each other).
- The mocks encode a little join/leave/fallback logic (e.g. leaving the active group falls back to the most recently created remaining group). This is UI-plausibility logic only; the authoritative rules live server-side, so the mock logic is intentionally shallow and may diverge from the API in edge cases.
- Swapping a mock for the real repository (Task 26) is a one-line change at the composition root; the shared `MockData` and any mock-only flags (`shouldFailLogin`) simply fall away.
- **Revisit when:** the real repositories land — the mocks stay for previews/tests but stop being the app's default wiring.

---

## ADR-0079: `GroupDetail` composite and `MapScope` enum added for the detail and map endpoints

Status: Accepted (revisit)
Date: 2026-07-23

### Context
Task 2 defined the core domain models, but the Task 3 protocols surfaced two shapes the app needs that weren't yet modelled. `GET /groups/{id}` returns a group **with its member list** (the Group Detail screen, Task 22), which is a richer shape than the bare `Group` that `GET /groups` returns for the group list. And the map endpoint takes a `?scope=personal|group` parameter (l3-api.md §1, Map) with no corresponding Swift type.

### Decision
Add `GroupDetail { group: Group; members: [GroupMember] }` (Codable, Identifiable by `group.id`) as the return type of `getGroupDetail`, keeping the bare `Group` as the list shape — two types for the two endpoints rather than one over-fetched type. Add `enum MapScope: String { case personal, group }` with raw values matching the `?scope=` query parameter, alongside the existing `Period` and `DrinkType` wire-string enums in `Enums.swift`.

### Alternatives Considered
- **Put `members` directly on `Group` (optional):** rejected — the group-list response doesn't carry members, so the field would be `nil` there and present only after a detail fetch, an ambiguous shape. Two explicit types make "list vs detail" unmissable and match the two endpoints 1:1 (consistent with ADR-0076's "models mirror the endpoint payloads").
- **A `Bool isPersonal` instead of `MapScope`:** rejected — the enum's raw value *is* the query-parameter string, so the networking layer (Task 26) can serialise it directly, and it reads better at call sites (`scope: .group`).

### Consequences
- `getGroupDetail` returns everything the detail screen needs in one value; the list stays lean.
- `MapScope` follows the same "raw value = wire string" convention as `Period`/`DrinkType`, so the map request builds without a translation step.
- **Revisit when:** the detail endpoint's payload grows fields beyond group + members (e.g. the caller's own role/permissions), at which point `GroupDetail` absorbs them.

## ADR-0080: `ImageValidator` detects format by magic bytes and throws, mirroring the API

Status: Accepted (revisit)
Date: 2026-07-23

### Context
Task 4 needs the client-side image check that runs before an avatar or pint-photo upload (requirements §2.3, §4.7). It must reject anything that isn't a JPEG or PNG and anything over the per-asset limit (5 MB avatar, 10 MB pint photo). The server re-validates independently — the API's `ImageValidation` object sniffs the first few bytes (JPEG `FF D8 FF`, PNG `89 50 4E 47 0D 0A 1A 0A`) and checks size before format. The client check is a UX affordance (fail fast with an inline error), not a security boundary, so the question was how closely to track the server and what shape the result takes.

### Decision
`ImageValidator.validate(_:as:)` is a `throws` function (no return value on success) that reproduces the API's logic exactly: same magic-byte prefixes, same size limits expressed as `5 * 1024 * 1024` / `10 * 1024 * 1024`, and the same order — size first, then format. On failure it throws a typed `ImageValidationError` (`.tooLarge(maxBytes:)` carrying the limit, or `.unsupportedType`). The asset kind is an `ImageAsset` enum (`avatar` / `pintPhoto`) whose `maxBytes` owns the limit, so the limit lives in one place per asset.

### Alternatives Considered
- **Return `Result<Void, ImageValidationError>`:** rejected — `Result<Void, _>` isn't `Equatable` (because `Void` isn't), which made the tests unable to compare outcomes with `==`. A `throws` function composes with Swift Testing's `#expect(throws:)` and reads naturally at call sites (`try validate(...)`), so it was the cleaner choice.
- **Trust the declared MIME/UTType instead of sniffing bytes:** rejected — the file bytes are what actually get uploaded and re-validated server-side; matching the server's byte sniff means the client and server agree on the same evidence, so a file that passes here passes there.
- **A single global size limit:** rejected — avatar (5 MB) and pint photo (10 MB) genuinely differ; encoding the limit on `ImageAsset` keeps the two caps explicit and lets the same bytes be valid as one asset but not the other.

### Consequences
- Client and server apply the identical accept/reject rule, so client-validated uploads won't be surprised by a 422; the client check purely improves latency-to-feedback.
- `.tooLarge` carries `maxBytes`, so the UI can render "must be 5 MB or smaller" without hard-coding the number.
- **Revisit when:** we add HEIC→JPEG conversion (Task 11/16) — validation runs *after* conversion, so the validator's input is always already-converted JPEG data; if conversion ever produces something else, the magic-byte set may need to grow.

## ADR-0081: `InitialsGenerator` splits on whitespace, keeps grapheme clusters whole, and never returns empty

Status: Accepted (revisit)
Date: 2026-07-23

### Context
Design Property 7 requires initials for the no-avatar placeholder (leaderboard rows, map pins — requirements §1.7, §7.5): the first character of the first word plus the first character of the last word (or just the first for a single word), never empty. Display names are free-form user input — they can be single words, multi-word, empty, whitespace-only, or contain emoji/accented glyphs made of multiple Unicode scalars.

### Decision
`InitialsGenerator.initials(from:)` splits the name on whitespace (`split(whereSeparator: \.isWhitespace)`, which discards empty subsequences so runs of spaces collapse), takes `Character` values (whole grapheme clusters) from the first and last words, uppercases the result, and returns a `"?"` placeholder when there are no non-whitespace words. Taking `Character` rather than `UnicodeScalar` keeps flag emoji and combining accents intact.

### Alternatives Considered
- **Index into the string by `UnicodeScalar` / UTF-16 offset:** rejected — that can slice a multi-scalar grapheme (e.g. a flag emoji) into a broken half. Swift's `Character` is already a grapheme cluster, so `word.first` is the correct unit.
- **Return an empty string for empty input and let callers handle it:** rejected — Property 7 says the result is *never* empty, and every call site would otherwise need the same fallback. Centralising the `"?"` placeholder honours the property in one place.

### Consequences
- Every display name — including empty, whitespace-only, or emoji names — yields a renderable 1–2 character string, so placeholder views never show a blank.
- The helper is pure and synchronous, trivially unit-tested, and has no dependency on the rest of the app.
- **Revisit when:** product wants locale-aware casing or right-to-left handling; `uppercased()` uses the default locale, which is fine for the MVP but not necessarily for every script.

## ADR-0082: The "+" tab is a trigger routed through a `RootTabViewModel`, not a selectable tab

Status: Accepted (revisit)
Date: 2026-07-23

### Context
The nav shell (l3-ios-app.md §2) is a three-item bottom bar — Home, "+", Profile — but the "+" is not a destination: tapping it presents the camera as a full-screen modal, and dismissing the modal must return the user to whichever tab they were on. SwiftUI's `TabView` binds its selection to a value, and a naive third tag would make "+" a *selectable* tab (its content would show, and dismissing the modal would strand the user on a blank "+" tab). The "+" must also be disabled (greyed out, not hidden — §5 point 5) when the user has no active group. Task 5 needs all of this branching to be unit-testable without driving the SwiftUI UI on the simulator.

### Decision
Introduce `RootTab { home, add, profile }` and a `@MainActor @Observable RootTabViewModel` that owns `selectedTab` (never `.add`), `isCameraPresented`, and `canLogPint` (derived from `groupRepository.activeGroup != nil`). `ContentView` binds `TabView`'s selection to a **custom `Binding`** whose setter calls `model.select($0)` — so a "+" tap runs `select(.add)`, which sets `isCameraPresented = true` (when `canLogPint`) and leaves `selectedTab` untouched. The getter still returns the real home/profile selection, so the visible tab never becomes "+". The camera is presented via `.fullScreenCover(isPresented:)`; its close button flips `isCameraPresented` back to false, returning to `selectedTab`. All routing lives in the view model and is tested directly (`RootTabViewModelTests`), never through the view.

### Alternatives Considered
- **A plain `@State selectedTab` in the view with an `.onChange` that snaps back:** rejected — the tab briefly becomes `.add`, causing a visible flicker and putting the "did we open the camera?" logic in the view where it can't be unit-tested.
- **A center floating button overlaid on the `TabView` instead of a real tab item:** rejected for now — more layout code, and the design explicitly describes a three-item bar with "+" in the middle. The trigger-binding approach keeps the standard tab-bar look with no custom chrome.
- **Hiding "+" when there's no active group:** rejected per §5 point 5 — the button always exists to avoid "why is the button gone?" confusion; it's disabled instead.

### Consequences
- Dismissing the camera always returns to the prior tab because that tab was never deselected.
- The disabled state is one derived property (`canLogPint`) reading the group repository's shared `activeGroup`, so it stays correct as the active group changes.
- The whole shell's behaviour is covered by fast, view-free unit tests; the SwiftUI layer is a thin declarative binding.
- **Revisit when:** the camera needs the active group threaded into it (Task 11–13), or if we move to a center floating action button design; the view model already knows `canLogPint`, so the modal can read the active group at presentation time.

## ADR-0083: Root view gates Login vs tab bar by observing the auth repository; `LoginViewModel` maps errors and owns no auth state

Status: Accepted (revisit)
Date: 2026-07-23

### Context
Task 6 wires the auth flow: an unauthenticated user sees `LoginView`, and a successful (mock) Sign in with Apple must swap the whole screen for the tab bar (`ContentView`). On failure the Login screen shows a human-readable message with a Retry button (l3-ios-app.md §4, §7). Two questions: (1) where does the "am I signed in?" decision live, and (2) does the login view model hold auth state or delegate it? The `AuthRepository` is already the single source of truth for `isAuthenticated` and `currentUser` (l3-ios-app.md §1, State Ownership), and `MockAuthRepository` is an `@Observable` class with a `shouldFailLogin` switch.

### Decision
Add a `RootView` in `App/` that reads `authRepository.isAuthenticated` and renders `ContentView` when true, `LoginView` when false. Because the repository is `@Observable` and `RootView` reads that property in its `body`, flipping it (login succeeds, or a later logout/delete-account) re-renders `RootView` and swaps the screen — no imperative navigation, no binding threaded down. `PintKingApp` owns both the `authRepository` and `groupRepository` as `@State` and injects them.

`LoginViewModel` (`@MainActor @Observable`) holds only screen-local state — `isLoggingIn` and `errorMessage` — and delegates the actual sign-in to the injected repository. It does **not** expose `isAuthenticated`; the root view observes the repository directly, so duplicating that state in the view model would just risk drift. `login()` clears the prior error, sets the loading flag (with `defer` to reset it), calls `authRepository.login()`, and on `catch` maps the thrown error to a message via a private `message(for:)` helper. `retry()` is a thin alias for `login()` (which already clears the error first) named for readability at the call site.

### Alternatives Considered
- **`LoginViewModel` owns `isAuthenticated` and the app switches on the view model:** rejected — the repository is already the single source of truth for auth state; mirroring it in the view model invites drift and means logout/delete-account (which happen far from the Login screen) can't flip the flag.
- **Passing an `isAuthenticated` `Binding` down from the app:** rejected — `@Observable` makes the binding unnecessary; reading the property in `body` is enough to subscribe, and it keeps the ownership in one place.
- **Surfacing the raw `Error`/`APIError` description on the Login screen:** rejected — the user needs a human-readable line, not `serverError`. The view model maps known cases (e.g. `.networkUnavailable` → an offline hint) and falls back to a generic "Sign in failed. Please try again." for everything else.

### Consequences
- Auth-driven navigation is declarative and centralised: any code path that changes `isAuthenticated` on the repository automatically routes the user, so logout (Task 18) and 401-refresh-failure (Task 26) get correct navigation for free.
- The Login logic is fully unit-testable without SwiftUI (`LoginViewModelTests` drives success, failure, and retry via `shouldFailLogin`); the view is a thin renderer of `isLoggingIn`/`errorMessage`.
- The Sign in with Apple button is styled but not yet wired to `AuthenticationServices`; the real `ASAuthorizationController` flow lands with the backend (Task 26), at which point `message(for:)` gains real Apple-error cases.
- **Revisit when:** the real Apple flow lands (Task 26) — error mapping will need concrete `ASAuthorizationError` cases; and when the deep-link invite flow (Task 28) needs to persist a code through the unauthenticated → authenticated transition, which this root gate is the natural place to coordinate.

## ADR-0084: Location permission behind a `LocationPermissionRequesting` protocol; full location service deferred to Task 14

Status: Accepted (revisit)
Date: 2026-07-23

### Context
Profile Setup's "Continue" must request when-in-use location permission (`CLLocationManager.requestWhenInUseAuthorization()`) before advancing to Home (requirements §1, l3-ios-app.md §4). Two problems for a TDD task: (1) `CLLocationManager` needs a real device/simulator and delivers its answer asynchronously via a delegate callback — it can't be driven from a plain unit test; and (2) the full location capability (reading coordinates at shutter time, with a 10s timeout) belongs to Task 14, not here. Task 7 only needs the *permission request* step, and it needs it to be unit-testable.

### Decision
Introduce a tiny `@MainActor protocol LocationPermissionRequesting` with a single `func request() async -> LocationPermissionDecision` (`.granted` / `.denied`). Two conformers: `CLLocationPermission` (the real one — bridges the `CLLocationManagerDelegate` authorization callback into async/await via a `CheckedContinuation`, and short-circuits when the status is already decided) and `MockLocationPermission` (`@Observable`, returns a preset decision and counts calls). `ProfileSetupViewModel` depends on the protocol, so tests inject the mock and assert both the stored decision and that location was requested exactly once. The app injects `CLLocationPermission`. Added `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription` to the app target so the system prompt doesn't crash at runtime. The decision is deliberately coarse (`granted`/`denied`) — Profile Setup only cares whether it may use location going forward, not the exact `CLAuthorizationStatus`.

### Alternatives Considered
- **Call `CLLocationManager` directly from the view model:** rejected — untestable without a simulator + delegate plumbing, and it would drag the whole location capability into an auth-flow task.
- **Build the full `LocationService` (coordinate reads + timeout) now:** rejected — that's Task 14's scope; Task 7 needs only the permission ask. Building it early would be speculative and untested against its real use.
- **Expose the raw `CLAuthorizationStatus`:** rejected — Profile Setup makes a binary decision (proceed regardless, record whether location is usable). The coarse enum keeps the view model simple; Task 14 can read finer status directly if it needs to.

### Consequences
- The view model's location step is fully unit-tested (granted stored as true, denied stored as false but still completes, not requested when the name is invalid) with no simulator UI.
- A denied/failed permission never blocks setup — location is optional, matching the app's "silently omit location" stance (l3-ios-app.md §7).
- **Revisit when:** Task 14 builds the real `LocationService`; it may absorb `CLLocationPermission` or share the manager, and it will need coordinate reads + the 10s timeout that this permission-only abstraction intentionally omits.

## ADR-0085: Profile Setup is gated in `RootView` by a session-local `didCompleteSetup` flag; the view model owns no persisted profile state

Status: Accepted (revisit)
Date: 2026-07-23

### Context
Profile Setup is shown "on first login only" (tasks-ios.md Task 7, l3-ios-app.md §4 "First Launch"): Login → Profile Setup → Home. `RootView` already gates Login vs the tab bar on `authRepository.isAuthenticated` (ADR-0083). We now need a third state between them, and a way to know when setup is "done." A real backend would persist a "profile complete" flag on the user; the MVP is mock-only, and the mock user is pre-populated, so there's no server signal to key off yet.

### Decision
`RootView` becomes a three-way gate: not authenticated → `LoginView`; authenticated but `!didCompleteSetup` → `ProfileSetupView`; otherwise → `ContentView`. `didCompleteSetup` is a `@State Bool` local to `RootView` for the session. `ProfileSetupView` takes an `onComplete` closure and calls it via `.onChange(of: model.isComplete)`; `RootView`'s callback flips the flag. `ProfileSetupViewModel` (`@MainActor @Observable`) holds only screen-local state (`displayName`, `avatarData`, `isSaving`, `errorMessage`, `isComplete`, `locationPermissionGranted`) and delegates the actual save to the injected `UserRepository` — it does **not** own the persisted profile, consistent with the state-ownership rule (ADR-0083, l3-ios-app.md §1). `continueSetup()` validates the name (1–30 chars, trimmed), saves name + optional avatar through the repository, requests location, then flips `isComplete`; an invalid name aborts before any repository/permission call.

### Alternatives Considered
- **Persist "setup complete" on the user model / repository:** rejected for now — there's no backend, and the mock user is pre-seeded. A session-local flag is the minimal thing that produces the correct first-login → Home flow; the real signal arrives with the backend.
- **Make Profile Setup a pushed screen inside a `NavigationStack` after Login:** rejected — the same declarative-gate approach as ADR-0083 keeps all top-level routing in one `RootView` `body`, with no imperative navigation and no stack to pop.
- **Let the view model expose completion and have the app observe it directly:** rejected — the view model is created *inside* `ProfileSetupView` (like `LoginViewModel` inside `LoginView`), so `RootView` doesn't hold it. A one-shot `onComplete` callback hands the single event up without leaking the model or duplicating its state.

### Consequences
- First-login routing is declarative and lives entirely in `RootView`; adding the step didn't touch Login or the tab bar.
- `PintKingApp` now owns four session objects (`auth`, `group`, `user` repositories + `CLLocationPermission`) and injects them down.
- Because `didCompleteSetup` is session-local, every fresh launch currently re-shows setup (the mock has no persisted "done" flag). That's acceptable for mock-only development and is the natural seam for the backend's real flag.
- **Revisit when:** the backend lands — "profile complete" should come from the user record (e.g. a first-login / onboarding flag), replacing the session-local `@State`; and when the deep-link invite flow (Task 28) needs to run *after* setup for an unauthenticated user, `RootView` is where that ordering is coordinated.

## ADR-0086: The group switcher reads Active_Group live from the repository, caching only the fetched group list

Status: Accepted (revisit)
Date: 2026-07-23

### Context
The Home tab's group switcher (tasks-ios.md Task 8, l3-ios-app.md §"Home Tab") shows the Active_Group's name and, on tap, a menu of every group the user belongs to; picking one switches the active group. Two pieces of data back it: the *list* of the user's groups (an async fetch, `getGroups()`) and the *current* Active_Group. The Active_Group is shared state that already lives on the `GroupRepository` (l3-ios-app.md §1 "State Ownership"): the "+" button reads it (ADR-0082), and create/join/leave elsewhere mutate it. The open question was whether the switcher's view model should cache the active group locally or read it through the repository.

### Decision
`GroupSwitcherViewModel` (`@MainActor @Observable`) caches only `groups` (the fetched list, screen-local) and exposes `activeGroup`/`activeGroupName` as computed properties that read **straight through** `groupRepository.activeGroup`. `load()` fetches the list (failures fall back to empty, surfacing the empty state — no error affordance until the networking layer, Task 26). `select(_:)` delegates to `switchActiveGroup(groupId:)` and is a no-op when the tapped group is already active. Because both the repository and the view model are `@Observable`, a switch from any screen re-renders the label with no manual wiring. The view (`GroupSwitcherView`) is a thin renderer: a `Menu` with a checkmark on the active group, or an empty state ("Join or create a group to get started") with Create/Join buttons wired to `onCreate`/`onJoin` closures (real navigation lands in Tasks 20–21).

### Alternatives Considered
- **Cache the active group in the view model** (mirror it on `load`/`select`): rejected — it would go stale the moment create/join/leave changes the active group from another screen, and duplicates state that already has a single owner. Reading through the repository keeps one source of truth, consistent with `RootTabViewModel.canLogPint` (ADR-0082).
- **A shared `HomeViewModel` owning switcher + leaderboard state:** rejected as premature — the switcher is self-contained; the leaderboard (Task 9) gets its own view model. They coordinate only through the shared Active_Group on the repository.
- **Hide the switcher entirely when the user has no groups:** rejected — the empty state is the intended first-run affordance (create/join), so the switcher renders it in place rather than vanishing.

### Consequences
- The switcher label is always correct without observing anything but the repository; create/join/leave "just work" for free.
- The view model is trivially unit-testable without SwiftUI: `select(_:)` is asserted by reading `repository.activeGroup` back, and the empty state by the `hasGroups`/`activeGroupName` computed properties (6 `GroupSwitcherViewModelTests` cases).
- Create/Join are inert closures for now; the empty-state buttons don't navigate until Tasks 20–21 provide the destinations.
- **Revisit when:** the leaderboard (Task 9) lands next to the switcher on Home and we decide whether they share a container view model or stay separate; and when the networking layer (Task 26) replaces the silent `try?` fetch with a real loading/error path.

---

## ADR-0087: Leaderboard view model derives the active/former split and crown from the fetched board; Home composes switcher + leaderboard

Status: Accepted (revisit)
Date: 2026-07-23

### Context
Task 9 (tasks-ios.md, l3-ios-app.md §"Home Tab", requirements §1) builds the leaderboard: a period filter (All-Time / This Week / This Month), a ranked list of active members (crown on rank 1, movement delta for bounded periods), and a separate greyed "Former Members" section (design Property 23). The board comes from `LeaderboardRepositoryProtocol.getLeaderboard(groupId:period:)`, which returns a flat `[LeaderboardEntry]` — active members already rank-ordered, former members appended with `rank == 0` / `rankDelta == nil`. Several rendering decisions had to live somewhere testable: which rows are "former", which wear the crown (a rank-1 *tie* means several crowns via dense ranking), and whether the delta shows at all. Also open: how the Home tab composes the Task 8 switcher (previously built but unwired) with this leaderboard, and which group the board is fetched for.

### Decision
`LeaderboardViewModel` (`@MainActor @Observable`) owns only screen-local state: the fetched `entries`, the `selectedPeriod` (starts `.allTime`, mutated only via `select(_:)` so it can't drift from `entries`), and an `isLoading` flag. It reads the target group **live** from `groupRepository.activeGroup` rather than taking a group id — same shared-state rule as the switcher (ADR-0086), so switching groups re-fetches the right board for free. It exposes pure derived views the SwiftUI layer renders without any logic of its own: `activeMembers` / `formerMembers` (partition on `isFormerMember`), `showsRankDelta` (`selectedPeriod != .allTime`, ADR-0064), `isCrowned(_:)` (`!isFormerMember && rank == 1`, so every tied rank-1 row is crowned), and `hasEntries` / `hasFormerMembers`. `load()` clears the list when there's no active group, otherwise fetches with a silent `try?` (no error affordance until Task 26); `select(_:)` is a no-op on an unchanged period; `refresh()` (pull-to-refresh) is a `load()` alias. Skeleton rows show only on the *first* load (`isLoading && !hasEntries`) so a period switch or refresh doesn't flash the skeleton over existing content.

The Home tab is composed by a new `HomeView`: it branches on `groupRepository.activeGroup` — nil ⇒ the switcher's full empty-state prompt owns the screen; non-nil ⇒ `LeaderboardView` as content with `GroupSwitcherView` collapsed into the nav-bar principal slot. `leaderboardRepository` is threaded `PintKingApp → RootView → ContentView → HomeView` alongside the existing session repositories, and ContentView's Home tab now renders `HomeView` instead of the placeholder text.

### Alternatives Considered
- **A shared `HomeViewModel` owning switcher + leaderboard state:** rejected (as flagged in ADR-0086) — the two coordinate only through the shared Active_Group on the repository, so two independent view models stay simpler and independently testable. `HomeView` is a thin structural composer with no state of its own.
- **Pass the group id into the leaderboard view model:** rejected — it would need re-injection on every switch and could go stale; reading `activeGroup` through the repository keeps one source of truth.
- **Compute the crown/split in the View:** rejected — ties at rank 1 and the former-member partition are exactly the load-bearing bits worth unit-testing; keeping them on the view model lets the 9 `LeaderboardViewModelTests` cases assert them with no SwiftUI.
- **Show skeletons on every fetch:** rejected — flashing the skeleton over a populated board during a period switch/refresh is jarring; gating on `!hasEntries` limits it to the genuine first load.

### Consequences
- The View is a pure renderer; every branch it takes (crown, delta, former section, empty, skeleton) maps to a named view-model property, so the screen's behaviour is verified without the simulator UI (9 `LeaderboardViewModelTests`).
- The Home tab is finally live end-to-end: switcher in the title, ranked board below, empty state for a groupless user — the composition ADR-0086 deferred.
- Avatars are initials placeholders for now (`InitialsGenerator`); leaderboard rows carry an `avatarUrl` path, but loading remote images needs the networking layer, so real avatars land with Task 26.
- **Revisit when:** the networking layer (Task 26) replaces the silent `try?` with a real loading/error path; and Task 10 (member pint history) adds row navigation off the leaderboard, at which point `HomeView`'s `NavigationStack` gains destinations.

---

## ADR-0088: Leaderboard rows navigate to Member Pint History via a value-based route; the history view model reads the active group live

Status: Accepted (revisit)
Date: 2026-07-30

### Context
Task 10 (tasks-ios.md, l3-ios-app.md §Screens/§Navigation) adds the Member Pint History screen: tapping a member on the leaderboard shows the pints that member logged **in the active group** — photo thumbnail, note, drink type, timestamp inline, no separate detail screen, with a tap-to-view-full-size photo. Two questions had to be settled: how a leaderboard row triggers navigation (ADR-0087 left `HomeView`'s `NavigationStack` without destinations), and which group + member the history fetches for. The pint fetch already exists — `PintRepositoryProtocol.getPintsForMember(userId:groupId:)`.

### Decision
`MemberPintHistoryViewModel` (`@MainActor @Observable`) owns only screen-local state — the fetched `pints` (newest first, as the repository returns them) and an `isLoading` flag — plus two immutable inputs fixed for the screen's lifetime: `userId` (the fetch key) and `memberName` (the title). It reads the Active_Group **live** from `groupRepository.activeGroup` rather than taking a group id, the same shared-state rule as the leaderboard (ADR-0086/0087): the history is always for the group currently on screen. `load()` clears the list with no active group, otherwise fetches with a silent `try?` (no error affordance until Task 26); `hasPints` drives the empty state; `refresh()` is a pull-to-refresh alias. Skeletons show only on the first load (`isLoading && !hasPints`).

Navigation is **value-based**: `LeaderboardView` wraps every row (active *and* former — former members retain pints, Property 23) in a `NavigationLink(value:)` carrying a small private `MemberRoute { userId, name }`, and declares one `.navigationDestination(for: MemberRoute.self)` that builds `MemberPintHistoryView`. `MemberRoute` — not `LeaderboardEntry` — is the nav value, so the route stays a two-field key decoupled from the leaderboard DTO (and the DTO needn't become `Hashable`). `pintRepository` is threaded `PintKingApp → RootView → ContentView → HomeView → LeaderboardView` alongside the existing session repositories. Pint photos are `SF Symbol` placeholders (thumbnail + full-size sheet) until the networking layer loads remote images (Task 26), mirroring the avatar-placeholder convention. The full-size viewer is a `.sheet(item:)` keyed on the tapped `PintLog` (already `Identifiable`).

### Alternatives Considered
- **Use `LeaderboardEntry` as the navigation value:** rejected — it would force `Hashable` onto the wire DTO and couple navigation to a richer type than the destination needs; a two-field `MemberRoute` is the minimal key.
- **Pass the group id into the history view model:** rejected for the same reason as the leaderboard (ADR-0087) — reading `activeGroup` through the repository keeps one source of truth and can't go stale.
- **Only active members tappable:** rejected — former members' pints are retained and shown on the board (Property 23), so their history is just as valid to open.
- **A push/`NavigationDestination` detail screen for a single pint:** rejected — the design specifies inline entries with an in-place full-size photo view, so a `.sheet` over the list suffices; no per-pint detail route.

### Consequences
- The screen is a pure renderer over a testable view model: the fetch key (member + live active group), the content, the empty state, and refresh are all verified without the simulator UI (6 `MemberPintHistoryViewModelTests`).
- The leaderboard is finally interactive — `HomeView`'s `NavigationStack` (dormant since ADR-0087) now has a destination, closing that ADR's revisit note.
- Pint photos are placeholders; real images (thumbnail + full-size) arrive with Task 26.
- **Revisit when:** the networking layer (Task 26) loads real photos and replaces the silent `try?` with a real loading/error path; and if a future task needs a richer per-pint detail, the `.sheet` may become a pushed destination.

---

## ADR-0089: The camera photo pipeline is a pure `PhotoProcessor`; `CameraModel` runs the AVCaptureSession off-main and publishes on the main actor

Status: Accepted (revisit)
Date: 2026-07-30

### Context
Task 11 (tasks-ios.md, l3-ios-app.md §5) builds the `@Observable CameraModel`: it must own an `AVCaptureSession` (rear camera + `AVCapturePhotoOutput`), start/stop it, capture a still, and process that still into an upload-ready photo — HEIC→JPEG conversion, compress down to the 10 MB cap, error if it still doesn't fit (design Property 6, mirrored client-side in ADR-0015/0080). The task is explicit that the capture *session* needs real hardware and can't be unit-tested, so only the *processing logic* should be tested. Two forces: (1) keep the tested logic free of AVFoundation, and (2) `AVCaptureSession`'s `beginConfiguration`/`startRunning`/`stopRunning` are blocking calls Apple forbids on the main thread, yet the model is `@MainActor @Observable` so its published state must mutate on the main actor.

### Decision
Split the stack in two. `PhotoProcessor` (a pure `enum` namespace, like `ImageValidator`) holds `process(_:maxBytes:) throws -> Data`: decode the raw bytes to a `CGImage` (`CGImageSourceCreateWithData`, throwing `.decodeFailed` for non-images), then re-encode to JPEG via `CGImageDestination` walking a fixed quality ladder `[0.9, 0.7, 0.5, 0.3]` best-first, returning the first result within `maxBytes` and throwing `.tooLargeAfterCompression` if even the lowest rung overshoots. It **always** re-encodes to JPEG rather than passing a small input through untouched — collapsing "convert HEIC→JPEG" and "compress" into one pass, and the server stores only JPEG/PNG anyway. `maxBytes` defaults to `ImageAsset.pintPhoto.maxBytes` (the shared 10 MB constant, so the client pre-check and the API agree) and is injectable so the "still too large" path is deterministic in a test.

`CameraModel` (`@MainActor @Observable final class: NSObject`, needed to be an `AVCapturePhotoCaptureDelegate`) is the thin hardware wrapper. `session`, `photoOutput`, and a private serial `sessionQueue` are `nonisolated`; the blocking configure/start/stop calls run on `sessionQueue`, and every mutation of observable state (`capturedPhoto`, `captureError`, `isSessionRunning`) hops back with `Task { @MainActor in … }`. The capture delegate pulls the container bytes off the delegate thread, then on the main actor runs `PhotoProcessor` and publishes a JPEG or a typed `CameraError`. Added `INFOPLIST_KEY_NSCameraUsageDescription` to both build configs (mirrors the location key from Task 7).

### Alternatives Considered
- **Keep all processing inside `CameraModel`:** rejected — it would drag AVFoundation and the `@MainActor` session into the one piece worth testing; a free function tests HEIC→JPEG, the compression ladder, and the size-error path with `ImageIO`-built fixtures and no simulator camera.
- **Pass a small input through untouched, only compress when over-limit:** rejected — a real iPhone capture is HEIC, which must be re-encoded regardless, so a single always-JPEG path is simpler and has no worse output for already-small images.
- **`@preconcurrency import AVFoundation` to silence the non-`Sendable` capture warnings:** rejected — `AVCaptureSession` serialises its own access and the serial-queue pattern is the documented approach; leaving the warnings visible keeps the compromise honest rather than blanket-suppressed.
- **Run the session work on the main actor:** rejected — Apple explicitly warns the blocking session calls must not run on the main thread; the `nonisolated` serial queue is the standard fix.

### Consequences
- The photo pipeline is fully unit-tested (7 `PhotoProcessorTests`, including a real HEIC→JPEG round-trip that skips cleanly where HEIC encoding is unavailable); `CameraModel`'s hardware path is implemented but verified on-device (Task 12/30), consistent with the task's note.
- The 10 MB cap lives in one place (`ImageAsset`), shared by `ImageValidator` (pre-upload check) and `PhotoProcessor` (capture compression).
- Non-`Sendable` capture warnings remain on the session-queue closures — accepted, not suppressed.
- **Revisit when:** Task 12 adds the live preview (`UIViewRepresentable` over the exposed `session`), the shutter UI, and the camera-permission explanation screen; Task 14 attaches GPS at shutter time; and on-device testing (Task 30) exercises the real capture path.

---

## ADR-0090: Camera screen logic lives in a `CameraViewModel` driven through `CameraPermissionRequesting`/`CameraControlling` protocols

Status: Accepted (revisit)
Date: 2026-07-30

### Context
Task 12 (tasks-ios.md) builds the full-screen camera UI: a `UIViewRepresentable` live preview, a circular shutter, a close button, and — when camera access is denied — an explanation screen with a Settings deep-link. Live preview and real capture need a physical device (the simulator has no camera), so the task is explicit that only the *decisions* should be unit-tested: permission gating (granted → show camera; denied → show explanation) and shutter-triggers-capture, against a mocked `CameraModel`. Two forces: (1) `CameraModel` (ADR-0089) owns a real `AVCaptureSession` we can't spin up in a test, and (2) camera authorization goes through `AVCaptureDevice.authorizationStatus`/`requestAccess`, which also needs the device and shows a system alert.

### Decision
Put all the branching in a `@MainActor @Observable CameraViewModel` and inject its two hardware collaborators behind protocols so tests supply fakes:

- **`CameraPermissionRequesting`** (+ `CameraPermissionStatus` enum: `.notDetermined`/`.granted`/`.denied`) mirrors the `LocationPermissionRequesting` pattern from Profile Setup (ADR-0084). `AVCameraPermission` is the real impl (reads `authorizationStatus(for: .video)`, only prompts from `.notDetermined` via the already-async `requestAccess`); `MockCameraPermission` reports a preset status, resolves `.notDetermined` to a configurable outcome, and counts requests.
- **`CameraControlling`** is the slice of `CameraModel` the screen drives (`session`, `capturedPhoto`, `captureError`, `configure`/`start`/`stop`/`capturePhoto`); `CameraModel` conforms via an empty extension. `MockCameraModel` (in the test target) owns an idle `AVCaptureSession` only to satisfy the protocol and tallies calls.

`CameraViewModel.onAppear()` awaits `permission.request()`, then on `.granted` sets `phase = .camera` and does `configure()` + `start()`, else `phase = .denied` (never starting a session it can't use). A `.checking` phase is the initial state so the view never flashes the wrong UI before the first answer. `onDisappear()` stops the session; `capturePhoto()` forwards to the camera. `CameraView` is a thin renderer that branches on `phase`, hosts `CameraPreviewView` (a `UIViewRepresentable` whose `layerClass` *is* `AVCaptureVideoPreviewLayer`, so it resizes for free), and deep-links to `UIApplication.openSettingsURLString` on the denied screen. `ContentView` builds a fresh `CameraModel()` + `AVCameraPermission()` per `fullScreenCover` presentation (session built up on open, torn down on close), replacing the Task 5 placeholder.

### Alternatives Considered
- **Have `CameraView` own the permission checks and session lifecycle directly:** rejected — that leaves the gating decisions (the whole point of the task's tests) trapped in a `View` that needs the simulator UI to drive; a protocol-injected view model tests them with no device.
- **Reuse `CameraModel` directly in tests without `CameraControlling`:** rejected — `CameraModel` constructs a real `AVCaptureSession` and can't verify `start`/`stop`/`capturePhoto` were called; the protocol + counting mock makes the orchestration assertable.
- **A single shared long-lived `CameraModel` on the app:** rejected — the session should only hold the camera while the modal is open; creating it per presentation ties its lifetime to the sheet and needs no explicit teardown beyond `onDisappear`.
- **Fold camera permission into the existing location abstraction:** rejected — different frameworks (AVFoundation vs CoreLocation) and a distinct status set; a parallel-but-separate protocol reads clearer than one union type.

### Consequences
- The screen's decisions are fully unit-tested (9 `CameraViewModelTests`): the checking→camera/denied gate, no-reprompt when already decided, shutter→capture, disappear→stop, and passthrough of `capturedPhoto`/`captureError`. `CameraView`, `CameraPreviewView`, and real capture are verified on-device (Task 12 note / Task 30).
- `CameraModel` gained no test-only surface beyond conforming to `CameraControlling`; the split keeps hardware out of the tested path, consistent with ADR-0089.
- The "+" flow is now real end-to-end up to capture: tap "+" → `CameraView` (permission-gated) → shutter fires `capturePhoto()`. The post-capture sheet and `PintRepository` hand-off land in Task 13; GPS at shutter time in Task 14.
- **Revisit when:** Task 13 adds the post-capture sheet that consumes `capturedPhoto`; Task 14 attaches location; and on-device testing (Task 30) exercises live preview + real capture and the Settings deep-link.

---

## ADR-0091: The post-capture sheet is a `PostCaptureViewModel` owning optional metadata; `CameraView` drives it off `capturedPhoto`

Status: Accepted (revisit)
Date: 2026-07-30

### Context
Task 13 (tasks-ios.md, requirements §3) adds the post-capture bottom sheet: after the shutter fires it shows the captured photo, an optional note (≤280 chars with a live counter), and an optional drink-type picker; "Done" hands photo + metadata to `PintRepository.createPint` and dismisses the whole camera modal. A photo-only pint is valid, so both metadata fields must be able to stay empty. Two forces: (1) keep the metadata rules (note cap, drink-type toggle, blank-note-→-nil, no-active-group guard) and the `createPint` hand-off in a unit-tested view model rather than the SwiftUI view; and (2) present the sheet only in response to a real capture, and let a dismiss (without Done) fall back to the live preview for a retake.

### Decision
A `@MainActor @Observable PostCaptureViewModel` owns the sheet's screen-local state — `note` (a `didSet` truncates to `maxNoteLength = 280` so paste can't exceed the cap), `drinkType` (set via `selectDrinkType(_:)`, which *toggles* — re-tapping the active chip clears it, since drink type is optional), plus `isSaving`/`errorMessage`/`isSaved`. The captured JPEG is a non-optional `let` input (mandatory, not screen state). The target group is *shared* state on the `GroupRepository` (l3-ios-app.md §1), so `save()` reads `activeGroup` live rather than taking a group-id param — consistent with the leaderboard/history view models. `save()` trims the note (blank → nil), calls `createPint(groupId:photoData:note:drinkType:location:)` with `location: nil` (GPS at shutter time lands in Task 14), and flips `isSaved`; no active group surfaces an inline error instead of logging.

`PostCaptureSheetView` is a thin renderer (photo thumbnail from `UIImage(data:)`, note `TextField` + counter, a horizontal row of `DrinkChip`s, a Done button that shows a spinner while saving) that calls `onDone` when `isSaved` flips. `CameraView` presents it via `.sheet(item:)` keyed on a private `CapturedPhoto` (an `Identifiable` wrapper giving each capture a fresh identity), populated from an `.onChange(of: model.capturedPhoto)`. Holding the pending photo in the view's own `@State` (rather than reading it live off the model) means dismissing the sheet to retake clears it locally without the sheet immediately re-presenting. Done wires straight to `onClose`, so logging a pint tears down the camera modal and returns to the previous tab. `ContentView` threads the group + pint repositories into `CameraView`.

### Alternatives Considered
- **Present the sheet directly off `model.capturedPhoto` (no local `@State` copy):** rejected — dismissing to retake would need the model's photo cleared too, coupling the sheet's lifecycle back into `CameraModel`; a local `CapturedPhoto` decouples them and the fresh identity guarantees re-presentation even on an identical reshoot.
- **Enforce the 280-char cap in the view (e.g. `onChange` on the field):** rejected — the cap is a rule worth testing without SwiftUI; a `didSet` on the model's `note` keeps it in the tested surface and covers paste.
- **Pass the active group id into the view model:** rejected — the Active_Group has a single owner (the repository); reading it live matches every other Home/logging view model and avoids a stale-id path.
- **Disable Done until a note or drink type is entered:** rejected — a photo-only pint is explicitly valid (requirements §3), so Done is always enabled once a photo exists.

### Consequences
- The sheet's logic is fully unit-tested (8 `PostCaptureViewModelTests`): the 280 cap + counter, drink-type set/toggle/replace, photo-only Done, metadata Done with note trimming, blank-note→nil, and the no-active-group guard. `PostCaptureSheetView` and the real photo rendering are exercised on-device (Task 30).
- The "+" flow is now complete end-to-end with mock data: tap "+" → camera → shutter → sheet → Done → pint appears in the mock store (and My Pints, Task 17). 
- `location` is passed as nil for now; Task 14 attaches the GPS coordinate captured at shutter time.
- **Revisit when:** Task 14 threads location into `createPint`; Task 29's offline queue changes what `createPint` does with a pint (immediate upload vs local queue), which the sheet is agnostic to; and on-device testing (Task 30) verifies the sheet over a live capture.

---

## ADR-0092: Shutter-time GPS behind a `LocationProviding` protocol; the fetch starts with the sheet and `save()` awaits it, bounded by a 10s timeout

Status: Accepted (revisit)
Date: 2026-07-30

### Context
Task 14 (tasks-ios.md, requirements §3, l3-ios-app.md "Pint Logging Flow": "request GPS location (10s timeout, silent fail)") captures the GPS coordinate at shutter time and attaches it to the pint. A pint with no location is valid, so location must never block or error the log: a timeout, a permission denial, or any CoreLocation error all mean "log without a location." Two forces: (1) keep the post-capture view model unit-testable without `CLLocationManager` (which needs a device and a delegate callback); and (2) fetching a fix can take seconds, so the wait must not stall the Done tap for the common case.

This is distinct from `LocationPermissionRequesting` (Task 7, ADR-0084/0085), which asks *may we use location?* during Profile Setup. Task 14 reads *where are we?* at shutter time. They stay separate protocols with separate implementations.

### Decision
A one-method `@MainActor protocol LocationProviding { func currentLocation() async -> Coordinate? }` — best-effort, **never throws**; nil covers timeout / denied / error uniformly. The real `LocationService` wraps a `CLLocationManager`: it early-returns nil unless authorization is `.authorizedWhenInUse`/`.authorizedAlways`, then bridges the fire-and-forget `requestLocation()` (which reports via the delegate) into an `await`ed value with a `CheckedContinuation` — mirroring `CLLocationPermission`. The twist is the timeout: `currentLocation()` runs a `withTaskGroup` that races the delegate-driven fetch against a `Task.sleep(for: .seconds(10))`; whichever resolves first wins, and a single `finishFetch(with:)` guard resumes the continuation exactly once so the loser is a no-op. `MockLocationProvider` returns a preset `Coordinate?` and counts calls.

In `PostCaptureViewModel`, `startLocationFetch()` kicks off the fetch as a stored `Task<Coordinate?, Never>` when the sheet appears (via `.onAppear`) — i.e. right after the shutter — so it resolves in the background while the user edits note/drink type. It's idempotent (guards on `locationTask == nil`). `save()` calls `startLocationFetch()` defensively, `await`s `locationTask?.value`, and passes the result (coordinate or nil) straight into `createPint(…, location:)`. `CameraView` and `ContentView` thread a `LocationProviding` alongside the existing repositories.

### Alternatives Considered
- **Fetch location inside `save()` only (no eager start):** rejected — the user often taps Done within a second of the shutter, so a cold fetch there would frequently hit the full timeout; starting on sheet-appear overlaps the fetch with metadata entry, so the value is usually ready by Done.
- **Reuse `LocationPermissionRequesting` for reads too:** rejected — permission (a decision) and location (a coordinate) are different concerns with different return types and lifetimes; one method each keeps both trivially mockable.
- **Throw on timeout/denied and catch in the view model:** rejected — a locationless pint is a normal, expected outcome, not an error; modeling it as `Coordinate?` keeps the "silent fail" requirement in the type rather than in a catch block.
- **Implement the timeout with `CLLocationManager` accuracy/timeout config:** rejected — `requestLocation()` has no built-in wall-clock timeout, and a task-group race is explicit, testable in principle, and independent of CoreLocation's internal retry behavior.

### Consequences
- The view model's location behavior is fully unit-tested (4 new `PostCaptureViewModelTests`, 13 total): coordinate received → attached; nil (timeout) → logged without location, no error; nil (denied) → same; and the fetch starts exactly once across repeated `startLocationFetch()` + `save()`. `LocationService`'s CoreLocation path (real delegate callback, real 10s race) is verified on-device (Task 30), like the camera hardware path.
- The "+" flow now logs real GPS when available, feeding the map (Task 18) with coordinates instead of nil.
- The eager fetch means a `LocationService` request may be in flight even if the user immediately dismisses the sheet to retake — harmless (the result is discarded) but it does spin up CoreLocation per sheet appearance.
- **Revisit when:** on-device testing (Task 30) exercises the real timeout race and denied paths; the map feature (Task 18) consumes the coordinates end-to-end; and if we later want a "locating…" indicator on the sheet, the view model would need to expose the in-flight state (currently opaque).

---

## ADR-0093: Profile tab card reads profile from `UserRepository` and total count from `PintRepository.getMyPints(nil)`; sub-screen rows fire inert closures until their destinations exist

Status: Accepted (revisit)
Date: 2026-07-30

### Context
Task 15 (tasks-ios.md, l3-ios-app.md §"Profile Tab") builds the Profile tab root: a user card (avatar or initials, display name, total pints logged) above navigation rows to four sub-screens — Edit Profile, My Pints, My Groups, Settings. Those destinations don't exist yet (Tasks 16–19). Two questions: where does the "total pints" number come from, and how do rows behave before their destinations are built.

### Decision
A `@MainActor @Observable ProfileViewModel` owns only screen-local state — the loaded `user` and `totalPintCount` — mirroring every other view model. `load()` fetches the profile via `UserRepository.getProfile()` and derives the total from `PintRepository.getMyPints(groupId: nil)`.count — the same "all groups" query the My Pints "All Groups" filter uses, so the count is consistent with that screen for free. Both use the silent-`try?`-then-fallback pattern (blank name / zero count on failure) the other view models use; the real error path lands with networking (Task 26). Derived props on the VM: `displayName`, `initials` (via `InitialsGenerator`), `showsInitialsPlaceholder` (`avatarUrl == nil`).

Unlike the Home view models, `ProfileViewModel` reads **nothing** off the GroupRepository — the card is about the person, not the active group, so there's no group context and the pint total spans all groups.

`ProfileView` is a thin renderer: a `List` with a user-card section (redacted on first load) and a section of rows. Each row is a `Button` firing an injected closure (`onEditProfile`/`onMyPints`/`onMyGroups`/`onSettings`), defaulting to `{}` — the same "wire the destination later" convention as the group switcher's Create/Join buttons (Task 8). ContentView threads a `UserRepositoryProtocol` (newly added to its init) into the Profile tab; RootView already held one and passes it through.

### Alternatives Considered
- **Store the total on the User model / fetch a dedicated count endpoint:** rejected — the API has no "my pint count" field; deriving `.count` from the existing all-groups query needs no new repository method and stays truthful to the My Pints screen.
- **`NavigationLink` rows to placeholder destinations now:** rejected — placeholders would need building and then replacing; inert closures keep the surface minimal and make the real destinations a one-line injection in Tasks 16–19 (matching Task 8).
- **Share one `AvatarCircle` across leaderboard + profile:** rejected for now — two small private copies is less coupling than a shared component with a single caller each; promote to `Utilities`/a shared view when a third caller appears (Task 24's map pins are the likely trigger).

### Consequences
- The card's data logic is fully unit-tested (5 `ProfileViewModelTests`): profile loads, total reflects all-groups count, zero-pints case, and the avatar-placeholder toggle both ways.
- The Profile tab is no longer a placeholder; the four sub-screen rows are visible and tappable but do nothing until their tasks land.
- Real avatars are still initials placeholders (networking, Task 26); `showsInitialsPlaceholder` is effectively always true today but becomes meaningful once remote images load.
- **Revisit when:** Tasks 16–19 replace the inert closures with real navigation; Task 26 loads remote avatars; and if a third caller needs `AvatarCircle`, extract it to a shared view.

---

## ADR-0094: Edit Profile is an `EditProfileViewModel` that saves only what changed; Profile navigates to it value-based via a `ProfileRoute` carrying the loaded `User`

Status: Accepted (revisit)
Date: 2026-07-30

### Context
Task 16 (tasks-ios.md, l3-ios-app.md §"Profile Tab") builds the Edit Profile screen: change the display name (1–30 chars) and/or the avatar (PHPicker, 5 MB, HEIC→JPEG). It's reached from the Profile tab's "Edit Profile" row, which ADR-0093 left as an inert closure. Three questions: how much of the ProfileSetup logic to reuse, how to avoid needless writes when only one field changed, and how the Profile tab navigates to the screen.

### Decision
A `@MainActor @Observable EditProfileViewModel` owns only screen-local state (`displayName`, `avatarData`, `isSaving`, `errorMessage`, `isSaved`), mirroring `ProfileSetupViewModel` (Task 7) — the two screens share display-name validation (`nameRange = 1...30`, trim-then-count) and avatar validation (shared `ImageValidator`, `.avatar` 5 MB cap), differing only in that setup also requests location and Edit pre-fills from an existing `User`.

**Save only what changed.** The VM captures `originalDisplayName` at init and exposes `hasChanges` (name differs from original **or** a new avatar was picked). `save()` calls `updateDisplayName` only when the name changed and `uploadAvatar` only when `avatarData` is set, so an avatar-only edit doesn't rename and a no-op save is a harmless dismiss. A nil `avatarData` means "leave the existing avatar untouched", not "remove it" — there's no remove-avatar affordance in the MVP. Save aborts on an invalid name before any repository call.

**Value-based navigation.** `ProfileView` gains a private `ProfileRoute: Hashable` enum (`.editProfile(User)`) and a single `.navigationDestination(for: ProfileRoute.self)`, mirroring the Home tab's `MemberRoute` (Task 10). The "Edit Profile" row is a `NavigationLink(value:)` carrying the already-loaded `User`, so the destination pre-fills without a second fetch; the row is inert (greyed, non-link) until the profile loads. This required making `User` conform to `Hashable` (all stored fields already are). On a successful save the destination's `onSaved` closure calls `model.refresh()` so the card reflects the new name/avatar after the pop.

### Alternatives Considered
- **Reuse `ProfileSetupViewModel` for both screens:** rejected — setup's `continueSetup()` bundles location permission and an `initialDisplayName` string input; Edit takes a `User` and never touches location. A separate VM keeps each screen's responsibilities honest; the shared bits (validation, `message(for:)`) are small enough to duplicate rather than hoist prematurely.
- **Always call both `updateDisplayName` and `uploadAvatar` on save:** rejected — an unconditional rename on an avatar-only edit is a wasted write (and, against the real API, a wasted request); `hasChanges`-gated calls keep the save minimal and match what the user actually did.
- **Keep the inert `onEditProfile` closure and inject the destination from ContentView:** rejected — Edit Profile needs the loaded `User`, which lives in `ProfileViewModel`, not ContentView; owning the route inside `ProfileView` (like `MemberRoute` in `LeaderboardView`) keeps the data where it is. The remaining three rows (My Pints/My Groups/Settings) keep their inert closures until Tasks 17–19.

### Consequences
- Edit Profile's logic is fully unit-tested (17 `EditProfileViewModelTests`): pre-fill, name validation bounds, change tracking (name, avatar, re-entering the original), avatar validation (valid/oversize/wrong-type), and save (writes trimmed name, uploads avatar, avatar-only doesn't rename, invalid name aborts, no-op save still dismisses).
- `User` is now `Hashable` — a harmless widening (it was already `Equatable`) that unlocks value-based navigation carrying the whole model.
- Avatars picked in the session render from in-memory bytes; an existing remote avatar still shows as an initials placeholder until networking (Task 26) can load it — so the screen can't yet show the *current* avatar, only a freshly chosen one.
- **Revisit when:** Task 26 loads remote avatars (the pre-filled avatar becomes a real image, and a remove-avatar affordance may be wanted); Tasks 17–19 wire the remaining three rows.
