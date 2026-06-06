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
