# Task List — iOS Client

## Approach

Each task is a self-contained, testable, committable unit. Tasks follow TDD: write tests first, then implement until tests pass. Each task builds on the previous — no task depends on the backend being live (mock repositories are used throughout).

---

## Phase 1: Project Foundation

### Task 1: Xcode project setup and folder structure

**What:** Create the Xcode project (iOS 17+, SwiftUI lifecycle), configure the folder structure by feature, add a test target.

**Folder structure:**
```
PintKing/
├── App/                    (App entry point, tab bar, root navigation)
├── Core/
│   ├── Networking/         (NetworkClient, Endpoint enum, APIError)
│   ├── Keychain/           (KeychainService wrapper)
│   └── Models/             (Shared domain models: User, Group, PintLog, etc.)
├── Features/
│   ├── Auth/               (Login, ProfileSetup views + viewmodels)
│   ├── Home/               (Leaderboard, Map, GroupSwitcher)
│   ├── Camera/             (CameraModel, CameraView, PostCaptureSheet)
│   ├── Profile/            (Profile, EditProfile, MyPints, Settings)
│   └── Groups/             (GroupList, GroupDetail, InviteScreen, JoinGroup, CreateGroup)
├── Repositories/           (All repository protocols + mock implementations)
└── Utilities/              (Extensions, helpers, InitialsGenerator, ImageValidator)

PintKingTests/              (Unit tests, mirrors feature structure)
```

**Tests:** Verify the project builds and the test target runs (empty test passes).

**Commit point:** Empty project with folder structure, builds and runs on simulator.

---

### Task 2: Domain models and shared types

**What:** Define all Codable domain models and enums used across the app.

**Models:**
- `User` (id, appleId, displayName, avatarUrl, activeGroupId)
- `Group` (id, name, inviteCode, createdBy, createdAt)
- `GroupMember` (id, userId, groupId, role, joinedAt, displayName, avatarUrl)
- `PintLog` (id, userId, groupId, photoUrl, note, drinkType, location, loggedAt)
- `LeaderboardEntry` (userId, displayName, avatarUrl, pintCount, rank, rankDelta, isFormerMember)
- `DrinkType` enum (beer, lager, ale, stout, cider)
- `Period` enum (allTime, thisWeek, thisMonth)
- `GroupMemberRole` enum (admin, member)
- `Coordinate` (latitude, longitude)
- `APIError` enum (unauthorized, forbidden, notFound, conflict, validationFailed, serverError, networkUnavailable)

**Tests:**
- JSON encoding/decoding round-trip tests for each model
- APIError mapping from HTTP status codes

**Commit point:** All models compile, all encoding/decoding tests pass.

---

### Task 3: Repository protocols and mock implementations

**What:** Define protocols for all 6 repositories and create mock implementations that return hardcoded data. This enables all UI development without a backend.

**Protocols:**
- `AuthRepositoryProtocol` (login, logout, isAuthenticated, currentUser)
- `UserRepositoryProtocol` (getProfile, updateDisplayName, uploadAvatar)
- `GroupRepositoryProtocol` (getGroups, createGroup, joinGroup, leaveGroup, getGroupDetail, removeMember, promoteMember, regenerateInviteCode, updateGroupName, activeGroup, switchActiveGroup)
- `PintRepositoryProtocol` (createPint, getMyPints, getPintsForMember, editPint, deletePint, pendingPints)
- `LeaderboardRepositoryProtocol` (getLeaderboard for group + period)
- `MapRepositoryProtocol` (getPintsInBoundingBox)

**Mock implementations:** Return realistic hardcoded data (2–3 groups, 5–8 members, 10–20 pint logs with varied data).

**Tests:**
- Mock repositories return expected data
- Protocol conformance verified

**Commit point:** All protocols defined, mocks return data, tests pass.

---

### Task 4: Utilities — InitialsGenerator and ImageValidator

**What:** Implement the two utility helpers that have clear testable logic.

**InitialsGenerator:**
- Input: display name string
- Output: 1–2 character initials (first char of first word + first char of last word; single char if one word)
- Never returns empty string

**ImageValidator:**
- Validates file type (JPEG/PNG only after conversion)
- Validates file size (5 MB for avatars, 10 MB for pint photos)
- Returns success or typed validation error

**Tests (TDD — write these first):**
- InitialsGenerator: single word ("Dave" → "D"), two words ("Dave Smith" → "DS"), multiple words ("Dave van Smith" → "DS"), empty string handling, unicode characters
- ImageValidator: JPEG under limit passes, PNG under limit passes, over-limit rejects, wrong type rejects, boundary cases (exactly 5 MB, exactly 10 MB)

**Commit point:** Both utilities implemented, all tests green.

---

## Phase 2: Navigation Shell and Auth

### Task 5: Tab bar skeleton with navigation stacks

**What:** Build the 3-tab layout (Home, +, Profile) with empty placeholder views. The "+" tab opens a placeholder full-screen modal and dismisses back to the previous tab.

**Implementation:**
- `ContentView` with `TabView`
- Home tab with `NavigationStack` and placeholder "Leaderboard" text
- Centre "+" tab that triggers `.fullScreenCover` (placeholder camera view)
- Profile tab with `NavigationStack` and placeholder "Profile" text
- "+" button disabled state when no active group (controlled by mock GroupRepository)

**Tests:**
- Tab selection state management
- "+" triggers modal presentation
- "+" disabled when activeGroup is nil

**Commit point:** App launches with 3 tabs, "+" opens/dismisses modal, disabled state works.

---

### Task 6: Auth flow — Login screen and mock auth

**What:** Build the Login screen with a "Sign in with Apple" button that triggers mock authentication. On success, navigate to the main tab bar. On error, show error message with retry.

**Implementation:**
- `LoginView` + `LoginViewModel`
- Mock auth: tapping the button calls `MockAuthRepository.login()` which sets `isAuthenticated = true` and populates `currentUser`
- Error state: simulated error shows inline message with retry button
- Root view switches between LoginView and ContentView based on `AuthRepository.isAuthenticated`

**Tests (TDD):**
- LoginViewModel: successful login sets isAuthenticated
- LoginViewModel: failed login sets error message
- LoginViewModel: retry clears error and re-attempts

**Commit point:** App shows login → tap → navigates to tab bar. Error state works.

---

### Task 7: Profile Setup screen

**What:** Build the profile setup screen shown on first login. Pre-filled display name (editable), avatar upload placeholder, location permission request.

**Implementation:**
- `ProfileSetupView` + `ProfileSetupViewModel`
- Text field for display name (1–30 chars, validation)
- Avatar placeholder (tap to select — uses PHPicker, no permission needed)
- "Continue" button that requests location permission then navigates to Home
- Location permission: calls `CLLocationManager.requestWhenInUseAuthorization()`

**Tests (TDD):**
- ViewModel validates display name length (empty rejected, 31+ chars rejected, 1–30 accepted)
- ViewModel tracks whether setup is complete
- ViewModel handles location permission granted/denied (stores decision)

**Commit point:** Profile setup screen works end-to-end with mock data. Location permission requested.

---

## Phase 3: Home Tab — Leaderboard

### Task 8: Group switcher dropdown

**What:** Build the group switcher at the top of the Home tab. Shows active group name, tapping opens a picker/menu of all groups.

**Implementation:**
- `GroupSwitcherView` — displays active group name, tap opens a `Menu` or picker
- Reads groups from `MockGroupRepository`
- Switching calls `GroupRepository.switchActiveGroup()`
- Empty state: "Join or create a group to get started" with action buttons

**Tests (TDD):**
- Switching active group updates the repository
- Empty state shown when user has no groups
- Active group name displayed correctly

**Commit point:** Group switcher works, switching updates state, empty state renders.

---

### Task 9: Leaderboard view with time period filter

**What:** Build the leaderboard list with ranked member rows and the time period segmented control.

**Implementation:**
- `LeaderboardView` + `LeaderboardViewModel`
- Segmented control: All-Time / This Week / This Month
- Each row: avatar (or initials placeholder), display name, pint count, rank number, rank delta (hidden for All-Time), crown badge for rank 1
- "Former Members" section below, greyed out
- Pull-to-refresh gesture
- Empty state: "No pints logged yet"
- Loading state: skeleton rows

**Tests (TDD):**
- ViewModel fetches leaderboard for active group + selected period
- Period switch triggers re-fetch
- Rank delta hidden when period is allTime
- Crown badge shown for all entries with rank == 1
- Former members separated from active members
- Empty state shown when no entries
- Pull-to-refresh triggers re-fetch

**Commit point:** Leaderboard renders with mock data, all states work, tests pass.

---

### Task 10: Member Pint History screen

**What:** Tapping a member row on the leaderboard navigates to their pint history.

**Implementation:**
- `MemberPintHistoryView` + `MemberPintHistoryViewModel`
- Scrollable list of pint entries (photo thumbnail, note, drink type, timestamp)
- Tap photo → full-size image viewer (simple overlay or sheet)
- Loading and empty states

**Tests (TDD):**
- ViewModel fetches pints for the selected member + active group
- Entries display correct data
- Empty state when member has no pints

**Commit point:** Tap member → see their pint history. Photo tap shows full-size.

---

## Phase 4: Camera and Pint Logging

### Task 11: CameraModel with AVFoundation

**What:** Build the `@Observable CameraModel` that manages the capture session.

**Implementation:**
- `CameraModel`: configures `AVCaptureSession` with rear camera + `AVCapturePhotoOutput`
- Start/stop session methods
- `capturePhoto()` method that triggers capture
- Delegate receives photo data
- HEIC → JPEG conversion via `CGImageDestination`
- Size validation (compress if >10 MB, error if still >10 MB after compression)

**Tests (TDD):**
- HEIC → JPEG conversion produces valid JPEG data
- Size validation: under 10 MB passes, over 10 MB triggers compression, still over after compression returns error
- Note: camera session tests require mocking AVFoundation — test the processing logic, not the hardware

**Commit point:** CameraModel compiles, photo processing logic tested, conversion works.

---

### Task 12: Camera view with shutter button

**What:** Build the full-screen camera UI with the `UIViewRepresentable` preview layer and shutter button.

**Implementation:**
- `CameraPreviewView` (UIViewRepresentable, ~10 lines, hosts AVCaptureVideoPreviewLayer)
- `CameraView`: full-screen, shows preview, large circular shutter button at bottom, close button at top
- Tapping shutter calls `CameraModel.capturePhoto()`
- Camera permission check: if denied, show explanation screen with Settings deep-link

**Tests:**
- Permission state handling (granted → show camera, denied → show explanation)
- Shutter tap triggers capture on the model

**Commit point:** Camera opens full-screen, shows live preview on device, shutter captures. Permission denied state works.

---

### Task 13: Post-capture bottom sheet

**What:** After photo capture, show the bottom sheet with optional metadata fields.

**Implementation:**
- `PostCaptureSheetView` + `PostCaptureViewModel`
- Photo thumbnail at top
- Optional text note field (max 280 chars, character counter)
- Optional drink type picker (horizontal chips: Beer, Lager, Ale, Stout, Cider)
- "Done" button dismisses the entire camera modal
- On "Done": hand off photo + metadata to `PintRepository.createPint()`

**Tests (TDD):**
- Note field enforces 280 char limit
- Drink type selection updates state
- "Done" with no metadata still calls createPint (photo-only is valid)
- "Done" with metadata passes note + drinkType to repository

**Commit point:** Full pint logging flow works: tap "+" → camera → shutter → bottom sheet → Done → back to previous tab.

---

### Task 14: Location capture during pint logging

**What:** Integrate CoreLocation to capture GPS coordinates at shutter time.

**Implementation:**
- `LocationService` (wraps CLLocationManager)
- On shutter tap: request current location with 10s timeout
- If location received → attach to pint metadata
- If timeout or denied → silently omit, pint still logs without location

**Tests (TDD):**
- Location received within timeout → coordinate attached to pint
- Location timeout → pint created without location (no error shown)
- Location permission denied → pint created without location (no error shown)

**Commit point:** Pints capture location when available, silently skip when not.

---

## Phase 5: Profile Tab

### Task 15: Profile screen with user card

**What:** Build the Profile tab root screen showing user info and navigation to sub-screens.

**Implementation:**
- `ProfileView` + `ProfileViewModel`
- User card: avatar (or initials placeholder), display name, total pint count
- Navigation links: Edit Profile, My Pints, My Groups, Settings

**Tests:**
- ViewModel loads user profile from UserRepository
- Initials placeholder shown when avatarUrl is nil
- Total pint count displayed

**Commit point:** Profile tab shows user card with mock data, navigation links work.

---

### Task 16: Edit Profile screen (display name + avatar)

**What:** Build the edit profile screen for changing display name and uploading avatar.

**Implementation:**
- `EditProfileView` + `EditProfileViewModel`
- Text field for display name (1–30 chars, inline validation)
- Avatar: current avatar displayed, tap to change (PHPicker for library selection)
- Save button calls `UserRepository.updateDisplayName()` and/or `UserRepository.uploadAvatar()`
- Client-side avatar validation (HEIC→JPEG, 5 MB limit)

**Tests (TDD):**
- Display name validation (empty rejected, >30 chars rejected, valid accepted)
- Avatar validation (over 5 MB rejected, valid JPEG accepted)
- Save calls repository with correct data

**Commit point:** Edit profile works with mock data. Validation enforced.

---

### Task 17: My Pints screen with edit and delete

**What:** Build the My Pints screen showing the user's own pint history with edit/delete capabilities.

**Implementation:**
- `MyPintsView` + `MyPintsViewModel`
- Group filter dropdown (defaults to active group, "All Groups" option)
- List of pint entries: photo, note, drink type, timestamp, group name
- Pending pints: "pending" badge
- Failed pints: "failed" badge with retry/discard buttons
- Edit: tap edit icon → bottom sheet (edit note, change drink type) → save
- Delete: swipe-to-delete → if within 24h: confirmation → delete; if >24h: show message

**Tests (TDD):**
- Group filter changes displayed pints
- Edit updates note/drinkType via repository
- Delete within 24h succeeds
- Delete after 24h shows rejection message
- Pending pints show badge
- Failed pints show retry/discard

**Commit point:** My Pints fully functional with mock data. Edit, delete, pending/failed states all work.

---

### Task 18: Settings screen (location toggle + account deletion)

**What:** Build the settings screen with location permission management and account deletion.

**Implementation:**
- `SettingsView` + `SettingsViewModel`
- Location toggle: shows current permission status, tapping deep-links to iOS Settings
- "Delete Account" button → `DeleteAccountConfirmationView` (lists what's deleted, destructive confirm)
- On confirm: calls `AuthRepository.deleteAccount()` → clears Keychain → navigates to Login

**Tests (TDD):**
- Delete account calls repository
- After deletion, isAuthenticated is false (triggers login screen)
- Location toggle reflects current permission state

**Commit point:** Settings works. Account deletion flow complete (with mock).

---

## Phase 6: Group Management

### Task 19: Group List screen

**What:** Build the list of all groups the user belongs to, with create/join actions.

**Implementation:**
- `GroupListView` + `GroupListViewModel`
- List of groups (name, member count, role badge for admin)
- "Create Group" button → `CreateGroupView`
- "Join Group" button → `JoinGroupView`
- Tap group → navigates to Group Detail

**Tests (TDD):**
- Groups loaded from GroupRepository
- Admin badge shown for groups where user is admin
- Navigation to create/join/detail works

**Commit point:** Group list renders, navigation to sub-screens works.

---

### Task 20: Create Group screen

**What:** Build the create group form.

**Implementation:**
- `CreateGroupView` + `CreateGroupViewModel`
- Text field for group name (1–50 chars, inline validation)
- "Create" button calls `GroupRepository.createGroup()`
- On success: new group set as Active_Group, navigate to Home
- On error (e.g. 99-group limit): show error message

**Tests (TDD):**
- Name validation (empty rejected, >50 chars rejected, valid accepted)
- Successful creation sets active group
- Error state displayed on failure

**Commit point:** Create group works end-to-end with mock.

---

### Task 21: Join Group screen and Join Confirmation

**What:** Build the manual invite code entry and the join confirmation screen.

**Implementation:**
- `JoinGroupView` + `JoinGroupViewModel`: text field for 8-char code, "Join" button
- `JoinConfirmationView`: shows group name, "Join" / "Cancel" buttons
- On join success: set as Active_Group, navigate to Home
- Error states: 404 (not found), 409 (already member), 403 (removed)

**Tests (TDD):**
- Valid code → shows confirmation
- Confirm → joins group, sets active
- 404 → "Group not found" message
- 409 → "Already a member" message
- 403 → "You have been removed" message

**Commit point:** Join flow works with all error states.

---

### Task 22: Group Detail screen with admin actions

**What:** Build the group detail screen showing members and admin capabilities.

**Implementation:**
- `GroupDetailView` + `GroupDetailViewModel`
- Members list (avatar, name, role badge)
- Admin actions (visible only if user is admin): remove member, promote to admin, edit group name
- "Leave Group" button with sole-admin logic
- Navigation to Invite Screen

**Tests (TDD):**
- Admin actions visible only for admin users
- Remove member calls repository
- Promote member calls repository
- Edit group name validates (1–50 chars) and calls repository
- Leave group: sole admin with members → shows promote prompt
- Leave group: sole admin no members → shows delete confirmation
- Leave group: not sole admin → normal confirmation

**Commit point:** Group detail fully functional with all admin flows.

---

### Task 23: Invite Screen with QR code and regenerate

**What:** Build the invite screen showing code, link, QR, share, and regenerate.

**Implementation:**
- `InviteScreenView` + `InviteScreenViewModel`
- Display invite code (large, copyable)
- Display invite link (copyable)
- QR code generated via CoreImage `CIQRCodeGenerator`
- Share button (iOS share sheet with link)
- "Regenerate" button (admin only) → confirmation → calls repository → updates displayed code

**Tests (TDD):**
- QR code generated from invite link
- Share triggers share sheet data
- Regenerate calls repository and updates displayed code
- Regenerate confirmation shown before action

**Commit point:** Invite screen works. QR generates. Regenerate flow complete.

---

## Phase 7: Map View

### Task 24: Map view with avatar pins

**What:** Build the map view with MapKit showing pint locations as avatar pins.

**Implementation:**
- `MapContentView` + `MapViewModel`
- MapKit `Map` with custom `Annotation`s
- Each pin: user's avatar image (or initials placeholder)
- Former members' pins: greyed-out style
- Personal / Group toggle (segmented control)
- Bounding-box query: when map region changes, fetch pints within viewport from MapRepository

**Tests (TDD):**
- ViewModel fetches pints for current bounding box
- Personal mode filters to current user only
- Group mode shows all members
- Former member pins flagged as greyed-out
- Region change triggers re-fetch

**Commit point:** Map renders with avatar pins from mock data. Toggle and bounding-box work.

---

### Task 25: Map pin callout

**What:** Tapping a pin shows a callout overlay with pint details.

**Implementation:**
- Custom callout view: photo thumbnail, drink type, note, timestamp
- Appears as a popover or overlay anchored to the pin
- Tap outside dismisses

**Tests:**
- Callout displays correct data for tapped pin
- Callout dismisses on outside tap

**Commit point:** Pin tap shows callout with pint details.

---

## Phase 8: Networking Layer (for future backend integration)

### Task 26: NetworkClient with JWT interceptor

**What:** Build the real NetworkClient (URLSession wrapper) with JWT injection and refresh-on-401 logic. Not connected to a live backend yet — tested with URLProtocol stubs.

**Implementation:**
- `NetworkClient` class with `request<T: Decodable>()` and `upload()` methods
- `Endpoint` enum with all API paths, methods, and body encoding
- JWT injection from AuthRepository
- Proactive refresh: check expiry before each request, refresh if within 5 minutes
- Reactive refresh: on 401, attempt refresh, retry once
- Error mapping: HTTP status → `APIError` enum

**Tests (TDD, using URLProtocol stubs):**
- JWT header injected on every request
- 401 triggers refresh → retry with new token
- Refresh failure → logout triggered
- 400/403/404/409/422/500 mapped to correct APIError cases
- Proactive refresh triggered when token near expiry

**Commit point:** NetworkClient fully tested with stubs. Ready to swap mock repositories for real ones when backend is live.

---

### Task 27: KeychainService wrapper

**What:** Build a thin wrapper around the Security framework for storing/retrieving JWT and refresh token.

**Implementation:**
- `KeychainService` with `save(key:data:)`, `load(key:)`, `delete(key:)`, `deleteAll()`
- Keys: `jwt`, `refreshToken`

**Tests (TDD):**
- Save and load round-trip
- Delete removes item
- DeleteAll clears everything
- Load for non-existent key returns nil

**Commit point:** Keychain wrapper tested and working.

---

## Phase 9: Polish and Integration Prep

### Task 28: Deep-link handler for invite links

**What:** Implement the `.onOpenURL` handler at the app root that intercepts invite links and routes to the join flow.

**Implementation:**
- Parse invite code from URL (e.g. `https://pintking.app/join/{code}`)
- If authenticated → navigate to JoinConfirmation with parsed code
- If not authenticated → persist code in memory → after login, show JoinConfirmation

**Tests:**
- Valid URL parsed correctly
- Invalid URL ignored
- Authenticated user routed to confirmation
- Unauthenticated user: code persisted, shown after login

**Commit point:** Deep-links work for both auth states.

---

### Task 29: Offline pint queue

**What:** Implement the offline queue in PintRepository that saves pints locally and uploads in the background.

**Implementation:**
- On `createPint()`: if network available → upload immediately; if not → save photo + metadata to local file storage
- `pendingPints` property exposes queued items (shown in My Pints with "pending" badge)
- Background upload via `URLSessionConfiguration.background`
- Retry logic: 3 attempts over 24 hours; after that, mark as "failed"
- On success: remove from local queue, pint appears in server data on next fetch

**Tests (TDD):**
- No network → pint saved locally, appears in pendingPints
- Network restored → upload triggered
- Upload success → removed from pending
- 3 failures → marked as "failed"
- Discard removes from local storage

**Commit point:** Offline queue works. Pints survive app restart and upload when connectivity returns.

---

### Task 30: Final integration test pass

**What:** Run through all user flows end-to-end with mock data on a physical device. Verify every flow from the User Flows section works as designed.

**Flows to verify:**
- [ ] First launch → login → profile setup → empty home
- [ ] Create group → leaderboard empty state
- [ ] Log pint → camera → shutter → bottom sheet → done → appears in My Pints
- [ ] Leaderboard shows mock data with crown, delta, former members
- [ ] Map shows pins with avatars, callout works
- [ ] Edit pint (note, drink type)
- [ ] Delete pint (within 24h and after 24h)
- [ ] Group management (create, join, leave, invite, regenerate code, admin actions)
- [ ] Edit profile (name, avatar)
- [ ] Settings (location toggle, delete account)
- [ ] "+" disabled when no active group
- [ ] Camera permission denied → explanation screen

**Commit point:** All flows verified on device. App is feature-complete with mock data, ready for backend integration.
