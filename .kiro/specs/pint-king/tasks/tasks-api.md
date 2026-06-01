# Task List — API Server (Kotlin / Spring Boot)

## Approach

Each task is a self-contained, testable, committable unit. Tasks follow TDD: write tests first, then implement until tests pass. The local development environment uses Docker Compose with PostgreSQL + PostGIS and LocalStack (fake S3). No AWS account needed during development.

---

## Phase 1: Project Foundation

### Task 1: Spring Boot project setup

**What:** Initialize a Kotlin + Spring Boot project with Gradle, configure dependencies, and set up the package structure.

**Dependencies:**
- Spring Boot 3.x (Web, Validation, Security, Data JPA)
- PostgreSQL driver + Hibernate Spatial (for PostGIS)
- AWS SDK for Kotlin (S3)
- Kotest (testing) + kotest-property (PBT)
- Testcontainers (integration tests)
- Flyway (migrations)
- jjwt (JWT generation/verification)

**Package structure:**
```
com.pintking.api/
├── config/          (Security config, S3 config, CORS)
├── auth/            (Controller, Service, Apple token verification)
├── user/            (Controller, Service, Repository, Entity)
├── group/           (Controller, Service, Repository, Entity)
├── pint/            (Controller, Service, Repository, Entity)
├── leaderboard/     (Controller, Service, Repository)
├── map/             (Controller, Service)
├── storage/         (S3Service — upload, delete, pre-sign)
├── common/          (Exceptions, ErrorResponse, Pagination, BaseEntity)
└── cleanup/         (OrphanCleanupJob)
```

**Tests:** Project compiles, empty test passes, application context loads.

**Commit point:** Empty Spring Boot app starts, connects to nothing yet.

---

### Task 2: Docker Compose for local development

**What:** Create a `docker-compose.yml` that runs PostgreSQL (with PostGIS) and LocalStack (S3) locally.

**Services:**
- `postgres`: PostgreSQL 16 with PostGIS extension, port 5432, user/password/db configured
- `localstack`: LocalStack (S3 only), port 4566, auto-creates the `pint-king-photos` bucket on startup

**Spring Boot config:**
- `application-local.yml` profile pointing to `localhost:5432` (DB) and `localhost:4566` (S3 endpoint override)

**Tests:** `docker compose up` starts both services. Spring Boot app starts with `--spring.profiles.active=local` and connects to both.

**Commit point:** `docker compose up` → Spring Boot starts → logs show successful DB connection and S3 bucket access.

---

### Task 3: Flyway migrations — initial schema

**What:** Create Flyway migration files that set up the full database schema from `l3-database.md`.

**Migrations:**
- `V1__enable_extensions.sql` — enable `postgis` and `pgcrypto`
- `V2__create_users.sql` — `users` table
- `V3__create_groups.sql` — `groups` table
- `V4__create_group_members.sql` — `group_members` table with unique constraint
- `V5__create_group_blocks.sql` — `group_blocks` table with unique constraint and index
- `V6__create_pint_logs.sql` — `pint_logs` table with indexes (including GIST on location)
- `V7__create_refresh_tokens.sql` — `refresh_tokens` table with index
- `V8__create_leaderboard_snapshots.sql` — `leaderboard_snapshots` table with unique constraint and index

**Tests (integration, Testcontainers):**
- Migrations run successfully against a fresh PostgreSQL + PostGIS container
- All tables exist with correct columns and constraints
- Indexes exist

**Commit point:** App starts, Flyway runs, schema is created. Integration test verifies.

---

### Task 4: JPA entities and base repository interfaces

**What:** Define Kotlin JPA entities for all tables and Spring Data JPA repository interfaces.

**Entities:** `UserEntity`, `GroupEntity`, `GroupMemberEntity`, `GroupBlockEntity`, `PintLogEntity`, `RefreshTokenEntity`, `LeaderboardSnapshotEntity`

**Repositories:** Spring Data `JpaRepository` interfaces with custom query methods where needed (e.g. `findByAppleId`, `findByGroupIdAndUserId`, `findByInviteCode`).

**Tests (integration, Testcontainers):**
- Save and retrieve each entity type
- Unique constraints enforced (duplicate insert throws)
- FK constraints enforced

**Commit point:** All entities persist and retrieve correctly. Constraint tests pass.

---

### Task 5: S3Service — upload, delete, pre-sign

**What:** Build the `S3Service` that wraps the AWS SDK for S3 operations.

**Methods:**
- `uploadPhoto(userId: UUID, groupId: UUID?, fileBytes: ByteArray): String` — uploads to correct key path, returns the object key
- `uploadAvatar(userId: UUID, fileBytes: ByteArray): String` — uploads to avatars path
- `deleteObject(key: String)` — deletes an S3 object
- `generatePresignedUrl(key: String): String` — generates a 15-minute GET URL

**Tests (integration, LocalStack via Testcontainers):**
- Upload succeeds, object exists in bucket
- Delete removes object
- Pre-signed URL is valid and accessible
- Upload to correct key path (avatars/ vs pints/)

**Commit point:** S3Service works against LocalStack. All operations tested.

---

### Task 6: Global error handling and response format

**What:** Set up the `@ControllerAdvice` exception handler that maps exceptions to the standard error response format.

**Implementation:**
- Custom exceptions: `UnauthorizedException`, `ForbiddenException`, `NotFoundException`, `ConflictException`, `ValidationException`, `UnprocessableException`
- `GlobalExceptionHandler` maps each to the correct HTTP status + JSON body with field-level errors
- Standard response envelope for paginated responses: `{ data: [...], page: N, size: N, total: N }`

**Tests (unit):**
- Each exception type maps to correct HTTP status
- Validation errors include field names and messages
- Paginated response envelope structure is correct

**Commit point:** Error handling works. Throwing any custom exception returns the correct JSON response.

---

## Phase 2: Authentication

### Task 7: POST /auth/apple — Apple token verification and user creation

**What:** Build the auth endpoint that verifies an Apple identity token, creates or finds the user, and issues JWT + refresh token.

**Implementation:**
- Verify Apple identity token signature against Apple's JWKS endpoint (mock in tests)
- Extract `apple_id` (subject claim) from the verified token
- UPSERT user by `apple_id` (create if new, find if existing)
- Generate JWT (1h expiry, contains user ID)
- Generate refresh token (random 256-bit, store SHA-256 hash, 30d expiry)
- Return `{ jwt, refreshToken, isNewUser }`

**Tests (TDD):**
- Valid Apple token → user created → JWT + refresh token returned → `isNewUser: true`
- Same Apple token again → same user returned → `isNewUser: false`
- Invalid Apple token → 401
- JWT contains correct user ID and expiry
- Refresh token hash stored in DB

**Properties validated:** 1 (idempotent creation), 2 (token expiry)

**Commit point:** Auth endpoint works end-to-end (with mocked Apple JWKS).

---

### Task 8: POST /auth/refresh — Token rotation

**What:** Build the refresh endpoint with single-use rotation and reuse detection.

**Implementation:**
- Receive plaintext refresh token from client
- Hash it (SHA-256), look up in `refresh_tokens`
- If not found or expired → 401
- If found and `used = true` → token reuse attack: invalidate ALL tokens for that user → 401
- If found and `used = false` → mark as used, generate new JWT + new refresh token, return both

**Tests (TDD):**
- Valid unused token → new pair issued, old marked used
- Expired token → 401
- Non-existent token → 401
- Already-used token → 401 + all user tokens invalidated
- New refresh token works for subsequent refresh

**Properties validated:** 3 (single-use), 4 (expired rejection), 5 (reuse detection)

**Commit point:** Full refresh flow works with all edge cases tested.

---

### Task 9: JWT security filter

**What:** Build the Spring Security filter that validates JWT on every request (except auth endpoints).

**Implementation:**
- `JwtAuthenticationFilter` (extends `OncePerRequestFilter`)
- Extracts `Authorization: Bearer <token>` header
- Verifies signature and expiry
- Sets `SecurityContext` with authenticated user ID
- Excludes `/auth/*` endpoints from filtering

**Tests (TDD):**
- Request with valid JWT → passes through, user ID available in context
- Request with expired JWT → 401
- Request with invalid signature → 401
- Request with no header → 401
- Auth endpoints pass without JWT

**Property validated:** 25 (JWT enforcement)

**Commit point:** All protected endpoints require valid JWT. Auth endpoints are public.

---

### Task 10: POST /auth/logout

**What:** Invalidate all refresh tokens for the authenticated user.

**Implementation:**
- Requires valid JWT
- Deletes all `refresh_tokens` rows for the user

**Tests (TDD):**
- After logout, all existing refresh tokens are invalid
- Subsequent refresh attempts return 401

**Commit point:** Logout works. Tokens invalidated.

---

## Phase 3: User Management

### Task 11: GET /users/me and PATCH /users/me

**What:** Build the profile read and update endpoints.

**Implementation:**
- `GET /users/me` → returns user profile (id, displayName, avatarUrl, activeGroupId)
- `PATCH /users/me` → updates `display_name` (1–30 chars validation) and/or `active_group_id`
- Active group validation: if provided, must reference a group the user is a member of

**Tests (TDD):**
- GET returns correct user data
- PATCH with valid display name updates it
- PATCH with empty or >30 char name → 400
- PATCH with active_group_id for a group user is not in → 400
- PATCH with valid active_group_id updates it

**Properties validated:** 8 (name validation, reused for display_name), 16 (active group invariant)

**Commit point:** Profile read/update works with validation.

---

### Task 12: POST /users/me/avatar — Avatar upload

**What:** Build the avatar upload endpoint with file validation and S3 upload.

**Implementation:**
- Multipart file upload
- Validate: JPEG or PNG, max 5 MB
- Upload to S3 via `S3Service.uploadAvatar()`
- Store resulting key as `avatar_url` on user record
- Return updated user profile with pre-signed avatar URL

**Tests (TDD):**
- Valid JPEG under 5 MB → uploaded, URL stored
- Valid PNG under 5 MB → uploaded, URL stored
- File over 5 MB → 422
- Non-JPEG/PNG file → 422
- Old avatar S3 object deleted on re-upload (cleanup)

**Property validated:** 6 (file upload validation)

**Commit point:** Avatar upload works. Validation enforced. Old avatars cleaned up.

---

### Task 13: DELETE /users/me — Account deletion

**What:** Build the account deletion endpoint with full cascade.

**Implementation:**
- Single DB transaction: delete user, all pint_logs, all refresh_tokens, all group_members, all group_blocks referencing user
- Group admin reassignment: if sole admin with other members → promote longest-standing member
- Group deletion: if sole member → delete group
- After DB commit: dispatch async S3 deletion for avatar + all pint photos
- Return 204

**Tests (TDD):**
- User deleted, all pint_logs gone, all tokens gone
- Sole admin with members → longest-standing promoted
- Sole member → group deleted
- S3 cleanup dispatched (verify via mock/spy)
- Non-sole admin → just removed from group, group persists

**Property validated:** 28 (account deletion cascade)

**Commit point:** Account deletion works with all cascade scenarios tested.

---

## Phase 4: Group Management

### Task 14: POST /groups — Create group

**What:** Build the group creation endpoint.

**Implementation:**
- Validate group name (1–50 chars)
- Check user hasn't created 99 groups already
- Generate 8-char alphanumeric invite code (ensure uniqueness)
- Create group, add user as admin in `group_members`
- If user has no active group → set this as active
- Return created group with invite code

**Tests (TDD):**
- Valid name → group created, user is admin, invite code generated
- Empty name → 400
- Name >50 chars → 400
- 99th group → succeeds; 100th → 422
- Invite code is 8 alphanumeric chars and unique
- Active group auto-set if user had none

**Properties validated:** 8 (name validation), 9 (creation limit), 10 (invite code format), 16 (active group)

**Commit point:** Group creation works with all validations.

---

### Task 15: POST /groups/join — Join group by invite code

**What:** Build the join endpoint with all outcome paths.

**Implementation:**
- Receive `{ inviteCode: "ABCD1234" }`
- Look up group by invite code → 404 if not found
- Check if user already a member → 409
- Check `group_blocks` for user + group → 403
- Add user as member with role 'member'
- If user has no active group → set this as active
- Return group details

**Tests (TDD):**
- Valid code, not member, not blocked → joined as member
- Invalid code → 404
- Already a member → 409
- Blocked user → 403 with "You have been removed" message
- Active group auto-set if user had none

**Properties validated:** 11 (join outcome correctness), 16 (active group)

**Commit point:** Join flow works with all 4 outcome paths tested.

---

### Task 16: GET /groups and GET /groups/{id}

**What:** Build the group listing and detail endpoints.

**Implementation:**
- `GET /groups` → list all groups user is a member of (id, name, inviteCode, role, memberCount)
- `GET /groups/{id}` → group details + members list (with roles, avatars, display names)
- Authorization: user must be a member of the group → 403 otherwise

**Tests (TDD):**
- List returns only groups user belongs to
- Detail returns members with correct roles
- Non-member accessing group → 403

**Property validated:** 26 (authorization enforcement)

**Commit point:** Group listing and detail work with authorization.

---

### Task 17: PATCH /groups/{id} — Update group name

**What:** Build the group name update endpoint (admin only).

**Implementation:**
- Validate name (1–50 chars)
- Check user is admin of this group → 403 if not
- Update group name
- Return updated group

**Tests (TDD):**
- Admin updates name → success
- Non-admin attempts → 403
- Invalid name → 400

**Properties validated:** 8 (name validation), 26 (authorization)

**Commit point:** Group name update works with admin check.

---

### Task 18: DELETE /groups/{id}/members/{userId} — Remove member or leave

**What:** Build the member removal endpoint that handles both admin-removing-member and self-leaving.

**Implementation:**
- If `userId` == authenticated user → leave flow
  - Sole admin with other members → 400 "Promote another admin first"
  - Sole admin, no other members → delete group
  - Otherwise → remove membership
- If `userId` != authenticated user → remove flow (admin only)
  - Check caller is admin → 403 if not
  - Delete `group_members` row
  - Insert `group_blocks` row
- Active group fallback: if removed user's active group was this one → set to another group or null

**Tests (TDD):**
- Admin removes member → membership deleted, block created, pint_logs retained
- Non-admin tries to remove → 403
- User leaves (not sole admin) → membership deleted, no block
- Sole admin with members tries to leave → 400
- Sole admin, no members → group deleted
- Active group fallback triggered correctly

**Properties validated:** 13 (removal consequences), 15 (leave validation), 16 (active group fallback)

**Commit point:** Remove/leave works with all scenarios.

---

### Task 19: POST /groups/{id}/members/{userId}/promote

**What:** Build the promote-to-admin endpoint.

**Implementation:**
- Check caller is admin → 403 if not
- Check target is a member of the group → 404 if not
- Update role to 'admin'

**Tests (TDD):**
- Admin promotes member → role changes to admin
- Non-admin tries → 403
- Target not a member → 404
- Target already admin → idempotent (no error)

**Property validated:** 14 (role promotion)

**Commit point:** Promotion works.

---

### Task 20: POST /groups/{id}/invite-code/regenerate

**What:** Build the invite code regeneration endpoint.

**Implementation:**
- Check caller is admin → 403 if not
- Generate new 8-char alphanumeric code (ensure uniqueness)
- Update group's invite_code
- Return new code

**Tests (TDD):**
- Admin regenerates → new code returned, old code no longer works (404 on join)
- Non-admin tries → 403
- New code is valid format (8 alphanumeric)

**Property validated:** 12 (regeneration invalidation)

**Commit point:** Regeneration works. Old code invalidated.

---

## Phase 5: Pint Logging

### Task 21: POST /pints — Create pint log (S3-first)

**What:** Build the pint creation endpoint with multipart photo upload, S3-first ordering, and metadata.

**Implementation:**
- Multipart request: photo file (required) + optional JSON metadata (note, drinkType, latitude, longitude)
- Validate file: JPEG/PNG, max 10 MB → 422 on failure
- Validate metadata: note max 280 chars, drinkType in allowed enum → 400 on failure
- Upload photo to S3 → on failure: return 500, no DB row
- On S3 success: insert `pint_logs` row with photo_url, user_id, active_group_id, location (if provided), logged_at = now()
- On DB failure after S3 success: enqueue orphan cleanup, return 500
- Return 201 with created pint log (photo_url as pre-signed URL)

**Tests (TDD):**
- Valid photo + metadata → pint created, S3 object exists, DB row exists
- No photo → 422
- Photo over 10 MB → 422
- Invalid drink type → 400
- Note over 280 chars → 400
- S3 failure → 500, no DB row
- DB failure after S3 → 500, orphan cleanup enqueued
- Location stored as PostGIS point when provided
- No location → pint created without location

**Properties validated:** 6 (file validation), 17 (creation integrity), 18 (metadata validation)

**Commit point:** Pint creation works end-to-end with S3-first ordering.

---

### Task 22: GET /pints — List pints (paginated)

**What:** Build the pint listing endpoint with group filtering and pagination.

**Implementation:**
- Query params: `group_id` (required), `period` (optional: all_time/this_week/this_month), `page`, `size`
- Authorization: user must be member of the group → 403
- Filter by time period if specified
- Return paginated list with pre-signed photo URLs
- Include user display_name and avatar for each pint

**Tests (TDD):**
- Returns pints for the specified group
- Non-member → 403
- Pagination works (page 1 vs page 2)
- Period filter correctly includes/excludes pints by timestamp
- Photo URLs are pre-signed

**Property validated:** 21 (time-period filtering), 26 (authorization)

**Commit point:** Pint listing works with filtering and pagination.

---

### Task 23: PATCH /pints/{id} — Update note or drink type

**What:** Build the pint update endpoint.

**Implementation:**
- Only the pint creator can update → 403 otherwise
- Updatable fields: `note` (max 280 chars), `drinkType` (enum validation)
- Return updated pint

**Tests (TDD):**
- Creator updates note → success
- Creator updates drink type → success
- Non-creator tries → 403
- Invalid note length → 400
- Invalid drink type → 400

**Property validated:** 18 (metadata validation)

**Commit point:** Pint update works with authorization and validation.

---

### Task 24: DELETE /pints/{id} — Delete pint (24h window, DB-first)

**What:** Build the pint deletion endpoint with the 24-hour window and DB-first S3 cleanup.

**Implementation:**
- Only the pint creator can delete → 403 otherwise
- Check `logged_at` is within 24 hours of now → 400 if not
- Delete DB row in transaction
- Dispatch async S3 delete for the photo
- Return 204

**Tests (TDD):**
- Creator deletes within 24h → DB row gone, S3 delete dispatched
- Creator deletes after 24h → 400 "Cannot delete after 24 hours"
- Non-creator tries → 403
- S3 delete failure → DB row still deleted (async cleanup handles it)

**Property validated:** 19 (deletion time window)

**Commit point:** Pint deletion works with time window enforcement.

---

## Phase 6: Leaderboard

### Task 25: GET /groups/{id}/leaderboard — Ranked leaderboard with deltas

**What:** Build the leaderboard endpoint with dense ranking, time filtering, and rank deltas from snapshots.

**Implementation:**
- Query param: `period` (all_time / this_week / this_month)
- Count pint_logs per active member for the specified period
- Apply dense ranking (ties share rank, next rank = tied rank + 1)
- For week/month: look up previous period snapshot, compute delta (snapshot_rank - current_rank)
- For all_time: delta = null
- Separate "former members" section (users with pint_logs but no group_members record)
- Crown badge flag for rank == 1
- Authorization: user must be member → 403

**Tests (TDD):**
- Correct ranking order (descending by count)
- Dense ties: 2 members with same count get same rank, next is +1
- 3-way tie works correctly
- Week filter only counts pints in current ISO week
- Month filter only counts pints in current month
- All-time counts everything
- Delta computed correctly from snapshot
- Delta is null when no snapshot exists
- Delta is null for all_time period
- Former members in separate section, no rank assigned
- Empty group → empty leaderboard
- Non-member → 403

**Properties validated:** 20 (dense ranking), 21 (time filtering), 22 (rank delta), 23 (former members excluded)

**Commit point:** Leaderboard works with all ranking, filtering, and delta logic.

---

### Task 26: Leaderboard snapshot scheduled job

**What:** Build the scheduled job that writes leaderboard snapshots at period boundaries.

**Implementation:**
- `@Scheduled` job (cron expression)
- Weekly: runs Monday 00:05 UTC — snapshots the previous week's final ranking for all groups
- Monthly: runs 1st of month 00:05 UTC — snapshots the previous month's final ranking
- For each group: compute ranking for the completed period, insert into `leaderboard_snapshots`
- Idempotent: if snapshot already exists for that period, skip (unique constraint prevents duplicates)

**Tests (TDD):**
- Job computes correct rankings and stores them
- Running twice for same period → no duplicates (idempotent)
- Groups with no pints → no snapshot rows (nothing to store)
- Snapshot data matches what the leaderboard endpoint would have shown

**Commit point:** Snapshot job works. Deltas in Task 25 now have real data to compare against.

---

## Phase 7: Map

### Task 27: GET /pints/map — Bounding-box spatial query

**What:** Build the map endpoint that returns pints within a geographic viewport.

**Implementation:**
- Query params: `group_id`, `scope` (personal/group), `sw_lat`, `sw_lng`, `ne_lat`, `ne_lng`
- Authorization: user must be member of group → 403
- PostGIS query: `ST_Within(location, ST_MakeEnvelope(sw_lng, sw_lat, ne_lng, ne_lat, 4326))`
- If scope=personal → filter to authenticated user only
- If scope=group → all members (including former, flagged)
- Exclude pints with null location
- Return pint data with pre-signed photo URLs, user info, former-member flag

**Tests (TDD):**
- Pints inside bounding box returned
- Pints outside bounding box excluded
- Pints with null location excluded
- Personal scope → only user's pints
- Group scope → all members' pints
- Former members flagged
- Non-member → 403

**Property validated:** 24 (bounding-box correctness)

**Commit point:** Map query works with PostGIS spatial filtering.

---

## Phase 8: Async Cleanup

### Task 28: Orphan cleanup scheduled job

**What:** Build the scheduled job that finds and deletes orphaned S3 objects.

**Implementation:**
- `@Scheduled` job (runs daily or hourly)
- List all S3 objects in the bucket
- For each object: check if any `pint_logs.photo_url` or `users.avatar_url` references it
- If unreferenced → delete from S3
- Log deletions for audit

**Tests (integration):**
- Upload an S3 object with no DB reference → job deletes it
- Upload an S3 object with a valid DB reference → job leaves it alone
- Multiple orphans → all cleaned up

**Commit point:** Orphan cleanup works. Safety net for all S3/DB ordering edge cases.

---

## Phase 9: Property-Based Tests

### Task 29: Property-based tests with kotest-property

**What:** Implement PBT for all properties marked **(PBT)** in the design doc.

**Properties to implement:**
- Property 6: File upload validation (random sizes, types)
- Property 10: Invite code format (generate many, verify format + uniqueness)
- Property 11: Group join outcomes (random combinations of code validity, membership, blocklist)
- Property 16: Active group invariant (random sequences of join/leave/remove)
- Property 17: Pint creation integrity (random requests with/without photos, mock S3 failures)
- Property 18: Pint metadata validation (random strings, enum values)
- Property 19: Pint deletion time window (random timestamps around 24h boundary)
- Property 20: Leaderboard dense ranking (random pint count distributions)
- Property 21: Time-period filtering (random timestamps across period boundaries)
- Property 22: Rank delta computation (random current/previous rank pairs)
- Property 24: Bounding-box query (random points and boxes)
- Property 26: Authorization (random user/group/role combinations)
- Property 28: Account deletion cascade (random user configurations)

**Configuration:**
- Minimum 100 iterations per property
- Tagged with property number and text

**Commit point:** All PBT tests pass. High confidence in correctness properties.

---

## Phase 10: Integration Tests and Polish

### Task 30: End-to-end integration tests

**What:** Full flow integration tests using Testcontainers (PostgreSQL + PostGIS + LocalStack).

**Flows to test:**
- Auth: Apple token → JWT → refresh → reuse detection → logout
- Pint creation: upload photo → S3 object exists → DB row exists → pre-signed URL works
- Pint deletion: delete → DB row gone → S3 cleanup dispatched
- Account deletion: full cascade → user gone, pints gone, groups reassigned, S3 cleanup dispatched
- Leaderboard: create pints → verify ranking → run snapshot job → verify deltas
- Map: create pints with locations → bounding-box query returns correct results
- Group join: all 4 outcomes (success, 404, 409, 403)
- Member removal: membership deleted, block created, pint_logs retained

**Commit point:** All integration tests pass. API is fully tested against real (containerised) infrastructure.

---

### Task 31: API documentation (OpenAPI/Swagger)

**What:** Add SpringDoc OpenAPI to auto-generate API documentation from the controllers.

**Implementation:**
- Add `springdoc-openapi-starter-webmvc-ui` dependency
- Annotate controllers with `@Operation`, `@ApiResponse`, `@Schema` where needed
- Swagger UI available at `/swagger-ui.html` in local/dev profile
- Disabled in production profile

**Tests:** Swagger UI loads and shows all endpoints.

**Commit point:** API documentation auto-generated and browsable.

---

### Task 32: Dockerize the API for deployment readiness

**What:** Create a `Dockerfile` for the Spring Boot app so it can be deployed as a container.

**Implementation:**
- Multi-stage Dockerfile: build with Gradle → run with JRE
- `application-prod.yml` profile with environment variable placeholders for DB URL, S3 bucket, JWT secret
- Health check endpoint (`/actuator/health`)

**Tests:** `docker build` succeeds. Container starts and responds to health check.

**Commit point:** API is containerised and ready for deployment to AWS (ECS/App Runner) when the time comes.
