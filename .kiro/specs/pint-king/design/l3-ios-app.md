# 03 — iOS App (C4 Level 3)

## Purpose

This document describes the internal structure of the iOS app container: its architecture, components, navigation, screens, key subsystems (camera, networking), client-side error handling, and iOS testing approach.

For the iOS app's place in the broader system, see [`02-containers.md`](./02-containers.md). For the rationale behind specific design choices, see `../adr.md`.

---

## 1. Architecture

The app uses **MVVM with a Repository layer**:

```
SwiftUI View → ViewModel → Repository → NetworkClient → API
```

| Layer | Type | Responsibility |
|-------|------|----------------|
| **View** | SwiftUI `View` | Purely declarative. Observes a ViewModel; renders state; forwards user actions. |
| **ViewModel** | `@Observable` class | Holds screen-local state (form input, loading flags, error messages). One per screen. Calls Repository methods to trigger mutations. |
| **Repository** | `@Observable` class | Single source of truth for a data domain. Decides whether to fetch from network, return cached data, or queue for offline sync. Injected into the SwiftUI environment. |
| **NetworkClient** | Class | Thin URLSession wrapper. Injects JWT, retries on 401 after refresh, maps HTTP responses to typed errors. |

### Repositories

| Repository | Responsibility |
|-----------|----------------|
| `AuthRepository` | Sign in with Apple flow, JWT/refresh token storage (Keychain), silent refresh, logout. |
| `UserRepository` | User profile, display name updates, avatar upload. |
| `GroupRepository` | Group CRUD, active group switching, invite code handling, member management. |
| `PintRepository` | Pint creation (including any offline queue), deletion, history fetching. |
| `LeaderboardRepository` | Fetches ranked leaderboard data for a group + time period. |
| `MapRepository` | Fetches pint locations within a bounding box for map rendering. |

### State Ownership

- **Screen-local state** → ViewModel (form input, loading indicators, error messages)
- **Shared/global state** → Repository (current user, active group, auth state)
- ViewModels **observe** repositories for shared data and **call** repository methods to trigger mutations.

---

## 2. Navigation Structure

Three-tab layout with a centre "+" trigger that opens the camera as a full-screen modal:

```
Tab Bar: [ Home ]  [ + ]  [ Profile ]
```

| Tab | Behaviour |
|-----|-----------|
| Home | `NavigationStack` — leaderboard/map with group switcher. |
| + (centre) | Not a real tab. Tapping presents the camera as a `.fullScreenCover`. Dismissing returns to the previously active tab. **Disabled** (greyed out, non-interactive) when the user has no Active_Group set. |
| Profile | `NavigationStack` — user profile, group list, settings. |

### Home Tab

```
Home
├── Group Switcher (dropdown at top — selects Active_Group)
├── Segmented Control: [Leaderboard | Map]
├── Leaderboard View (default)
│   ├── Time Period Filter: [All-Time | This Week | This Month]
│   ├── Pull-to-refresh gesture refreshes leaderboard data
│   ├── Ranked member rows (avatar, name, pint count, rank delta, crown badge for top-ranked)
│   ├── Rank delta hidden when filter is "All-Time"
│   ├── "Former Members" section (greyed out, below active members)
│   ├── Empty state: "No pints logged yet" when no pints exist for the selected period
│   └── Tap member row → Member Pint History (scrollable list of their pint photos)
└── Map View (toggle)
    ├── Avatar pins for pint locations
    ├── Former members' pins rendered greyed-out, visually distinct from active members
    ├── Personal / Group toggle
    └── Tap pin → Pint callout (photo thumbnail, drink type, note, timestamp)
```

### Profile Tab

```
Profile
├── User card (avatar, display name, total pints)
├── Edit Profile (change name, upload avatar)
├── My Pints (user's own pint logs across all groups, group filter dropdown)
│   ├── Each entry: photo, note, drink type, timestamp, group name
│   ├── Pending pints: "pending" badge (uploading in background)
│   ├── Failed pints: "failed" badge with retry/discard options
│   ├── Edit action → bottom sheet (edit note, drink type)
│   └── Delete action (swipe-to-delete, enforces 24h window)
├── My Groups (list of all groups user belongs to)
│   └── Tap group → Group Detail
│       ├── Members list
│       ├── Admin actions (remove, promote, edit group name — if admin)
│       ├── Invite screen (code, link, QR, share, regenerate code — if admin)
│       └── Leave group
├── Settings
│   ├── Location permission toggle (deep-links to iOS Settings)
│   └── Delete Account
```

### Why Groups Live in Profile, Not Home

Home is optimised for the primary loop: check leaderboard → log pint → check leaderboard. Group management (inviting, promoting, leaving) is infrequent. The *active* group is always visible on Home via the switcher; management lives in Profile to keep Home focused.

### Deep-Linking (Invite Links)

Invite links are Universal Links. When tapped:

1. App opens → central deep-link handler intercepts the URL.
2. If authenticated → navigate to Join Confirmation screen.
3. If not authenticated → persist invite code locally → complete auth → then show Join Confirmation.
4. After user confirms "Join" → API adds user to group → app sets the new group as Active_Group → navigates to Home tab showing the new group's leaderboard.

Implemented via SwiftUI's `.onOpenURL` modifier at the app root.

---

## 3. User Flows

Key end-to-end paths through the app. These complement the navigation trees above — they describe multi-step sequences, not individual screen access.

### First Launch (New User)

```
Login → Sign in with Apple → Profile Setup (name, avatar, location permission)
  → Home (empty state: "Join or create a group to get started")
```

### Create First Group

```
Home (empty state) → tap "Create Group" prompt → enter group name → confirm
  → Group created, set as Active_Group → Home (leaderboard, empty: "No pints logged yet")
```

### Log a Pint

```
Any screen → tap "+" centre tab → Camera opens (full-screen modal)
  → tap shutter → photo captured → post-capture bottom sheet appears
  → (optional) add note, select drink type
  → tap "Done" → camera dismisses → return to previous tab
  → Pint appears in My Pints as "pending" (if offline) or on leaderboard once server confirms
```

### Join via Invite Link (Authenticated)

```
External tap on invite link → app opens → Join Confirmation screen
  → tap "Join" → API adds to group → set as Active_Group → Home (new group's leaderboard)
```

### Join via Invite Link (Not Authenticated)

```
External tap on invite link → app opens → Login screen (invite code persisted locally)
  → Sign in with Apple → Profile Setup → Join Confirmation screen
  → tap "Join" → API adds to group → set as Active_Group → Home (new group's leaderboard)
```

### Join via Manual Code Entry

```
Profile tab → Group List → tap "Join Group" → enter 8-character invite code → tap "Join"
  → API validates → Join Confirmation → confirm → set as Active_Group → Home (new group's leaderboard)
```

### View Member's Pints

```
Home (Leaderboard) → tap member row → Member Pint History (scrollable list with photo, note, drink type, timestamp inline per entry; tap photo to view full-size)
```

### Edit Own Pint

```
Profile tab → My Pints → tap edit on a pint entry → bottom sheet (edit note, change drink type) → save → API PATCH → updated
```

### Delete Own Pint

```
Profile tab → My Pints → swipe-to-delete on a pint entry
  → IF within 24h of logged_at → confirmation prompt → API DELETE → pint removed
  → IF older than 24h → message: "This pint can no longer be deleted"
```

### Delete Account

```
Profile tab → Settings → tap "Delete Account" → confirmation dialog (destructive)
  → confirm → API cascade delete → Keychain cleared → Login screen
```

### Leave Group

```
Profile tab → Group List → Group Detail → tap "Leave Group"
  → IF user is sole admin AND other members exist → prompt: "Promote another member to admin before leaving" → navigate to members list for promotion
  → IF user is sole admin AND no other members → confirm: "Leaving will delete this group" → confirm → API deletes group → Group List
  → OTHERWISE → confirmation prompt → API removes membership → Active_Group fallback (see below) → Group List
```

### Regenerate Invite Code (Admin)

```
Profile tab → Group List → Group Detail → Invite Screen → tap "Regenerate"
  → confirmation prompt: "This will invalidate the current code. Anyone with the old code won't be able to join."
  → confirm → API regenerates code → new code, link, and QR displayed immediately
```

### Active_Group Fallback

When a user's Active_Group is removed (they were removed, they left, or the group was deleted):
- If the user belongs to other groups → automatically set the most recently joined group as Active_Group → Home updates to show that group's leaderboard.
- If the user belongs to no groups → set Active_Group to nil → Home shows empty state: "Join or create a group to get started" → "+" button is disabled.

---

## 4. Screen Inventory

| Screen | Description | Accessed From |
|--------|-------------|---------------|
| Login | "Sign in with Apple" button. On Apple auth error: displays human-readable error message with retry option. | App launch (unauthenticated) |
| Profile Setup | Display name + avatar + location permission | First login only |
| Home — Leaderboard | Active group leaderboard with time filter (All-Time / Week / Month) | Home tab (default) |
| Home — Map | MapKit with avatar pins, Personal/Group toggle | Home tab (segmented control) |
| Member Pint History | Scrollable list of a member's pints for the active group. Each entry shows photo (tappable for full-size), note, drink type, and timestamp inline. No separate detail screen. | Tap member row on leaderboard |
| Pint Callout | Overlay showing drink type, note, photo thumbnail, timestamp | Tap map pin |
| Camera (Add Pint) | Full-screen camera with custom shutter button | Centre "+" tab |
| Post-Capture Sheet | Bottom sheet over camera: photo thumbnail, optional note field (280 chars), optional drink type picker (chips), "Done" button. Upload starts immediately in background. | Appears after shutter tap |
| Profile | User card, edit profile, my pints, groups, settings | Profile tab |
| Edit Profile | Change display name, upload avatar | Profile screen |
| My Pints | User's own pint logs across all groups, with a group filter dropdown (defaults to active group). Each entry shows photo, note, drink type, timestamp, group name. Supports edit (bottom sheet for note/drink type) and delete (swipe, 24h window enforced). Pending pints shown with "pending" badge; failed pints shown with "failed" badge and retry/discard options. | Profile screen |
| Group List | All groups the user belongs to | Profile screen |
| Group Detail | Members, admin actions, invite, leave | Tap group in Group List |
| Invite Screen | Invite code, link, QR code, share sheet | Group Detail |
| Join Confirmation | "Join [Group Name]?" with confirm/cancel | Deep-link or manual code entry |
| Join Group (Manual) | Text field to enter an 8-character invite code (no group search/discovery — groups are invite-only) | Group List screen |
| Create Group | Text field to enter group name (1–50 chars) + confirm button | Group List screen or Home empty state |
| Settings | Location toggle, account deletion | Profile screen |
| Delete Account Confirmation | Destructive confirmation dialog listing what will be deleted: user profile, all pint logs, and avatar photo. Explains deletion is permanent and irreversible. | Settings |

---

## 5. Camera and Photo Pipeline

The camera is implemented with custom AVFoundation, not `UIImagePickerController`.

Structure:

- An `@Observable CameraModel` class owns the `AVCaptureSession`, configures inputs/outputs, and handles capture via `AVCapturePhotoOutput`.
- A minimal `UIViewRepresentable` (~10 lines) hosts `AVCaptureVideoPreviewLayer` — the one piece with no SwiftUI equivalent.
- All camera logic (start/stop session, capture, format conversion) lives in `CameraModel`, not in a UIViewController.

### Pint Logging Flow

```
User taps "+" tab
  → Camera modal opens (full-screen)
  → CameraModel starts AVCaptureSession
  → User taps shutter button
  → AVCapturePhotoOutput captures photo
  → CameraModel processes:
      1. Check format: if HEIC → convert to JPEG (CGImageDestination)
      2. Check size: if > 10 MB → compress with reduced JPEG quality
      3. If still > 10 MB → show error, stay on camera
  → Simultaneously: request GPS location (10s timeout, silent fail)
  → Post-capture bottom sheet slides up over camera view:
      - Photo thumbnail (confirmation)
      - Optional: text note field (max 280 chars)
      - Optional: drink type picker (horizontal chips: Beer, Lager, Ale, Stout, Cider)
      - "Done" button
  → Upload begins in background immediately (note/drink type sent with or patched after)
  → User taps "Done" (or skips by tapping immediately) → camera modal dismisses → return to previous tab
  → PintRepository uploads to API (or queues if offline)
```

### Client-Side File Validation

Mirrors the requirements (§2.3, §4.7) and the server-side property (Property 6 in `04-api.md`):

| Asset | Allowed types | Max size | On failure |
|-------|---------------|----------|------------|
| Pint photo | JPEG, PNG (after HEIC→JPEG conversion) | 10 MB | Inline error; do not submit |
| Avatar | JPEG, PNG (after HEIC→JPEG conversion) | 5 MB | Inline error; do not upload |

The server independently re-validates. The client check exists for UX, not security.

### Camera Permission Handling

Camera access is mandatory for pint logging. The permission flow:

1. First time the user taps "+": iOS shows the system camera permission prompt (`NSCameraUsageDescription`).
2. If granted → camera opens normally.
3. If denied → the app displays an explanation screen: "Camera access is required to log pints" with a button that deep-links to the app's iOS Settings page.
4. On subsequent "+" taps with permission denied → skip the explanation, deep-link directly to iOS Settings.
5. The "+" button is never fully hidden — it always opens *something* (either the camera or the permission explanation). This avoids confusion about why the button exists but "doesn't work."

### Photo Library Permission Handling

Photo library access is needed for avatar upload (Edit Profile screen). The permission flow:

1. First time the user taps "Choose from Library" on the avatar picker: iOS shows the system photo library permission prompt (`NSPhotoLibraryUsageDescription`).
2. If granted → photo picker opens.
3. If denied → display inline message: "Photo library access is needed to choose an avatar" with a deep-link to iOS Settings.
4. Note: iOS 14+ `PHPickerViewController` (Limited Photos Access) does not require full library permission — it shows a system picker that grants access to selected photos only. This is the preferred approach for avatar selection as it requires no explicit permission prompt.

---

## 6. Networking Layer

URLSession with `async/await`. No third-party HTTP libraries.

### JWT Interceptor Behaviour

1. Every request gets `Authorization: Bearer <jwt>` header injected automatically.
2. The `AuthRepository` monitors JWT expiry and proactively triggers a refresh when the token is within 5 minutes of expiring — before any request fails. This happens silently in the background.
3. If a request returns 401 (e.g. token expired between the proactive check and the request):
   a. Attempt `POST /auth/refresh` with the stored Refresh_Token.
   b. If refresh succeeds → store new tokens → retry original request once.
   c. If refresh fails (401) → clear Keychain → trigger logout → show login screen.
4. If response is any other error → map to typed error and throw.

## 7. Client-Side Error Handling

### Loading States Convention

All screens that fetch data from the API (leaderboard, map, member history, group list, My Pints) display a skeleton/placeholder view while loading. No blank screens — the user always sees either content, a loading state, or an empty state.

### API Response Errors

| HTTP Status | Behaviour |
|-------------|-----------|
| 400 | Display field-level validation errors inline (e.g. "Group name must be 1–50 characters"). |
| 401 | Attempt silent token refresh; if refresh fails, clear Keychain and show login. |
| 403 | Display contextual "access denied" message (e.g. "You have been removed from this group"). |
| 404 | Display "not found" message. |
| 409 | Display "already a member" message. |
| 422 | Display field-level validation errors inline. |
| 500 | Display generic "Something went wrong, please try again" message. |

### Client-Side Errors

| Scenario | Behaviour |
|----------|-----------|
| Network unreachable | Display offline banner; queue pint creation for background upload. Disable network-dependent actions. |
| S3 upload timeout (signalled by API 500) | Retry once automatically; if still failing, show error and return to camera. |
| Location timeout (10s) | Submit pint without location silently. |
| Image validation failure (client-side) | Display inline error before upload attempt. |
| Camera permission denied | Show explanation screen with deep-link to iOS Settings. |
| Sign in with Apple error | Display human-readable error on Login screen with retry option. |

---

## 8. Offline Behaviour

**Decision: Offline queue for pint creation only (Option B).**

- Pint photos and metadata are saved to local file storage immediately on capture.
- A "pending" indicator is shown on the pint in the **My Pints** screen only. Pending pints do NOT appear on the leaderboard or map until the upload is confirmed by the server.
- Upload completes in the background when connectivity returns — even if the user leaves the app or locks their phone. Uses iOS background URL sessions (`URLSessionConfiguration.background`).
- All other features (leaderboard, map, groups, profile) require connectivity. If offline, the app displays an offline banner and disables network-dependent actions.
- If a pending upload fails permanently (e.g. after 3 retries over 24 hours), the pint is marked as "failed" in My Pints and the user is prompted to retry or discard.

See `adr.md` (ADR-0023).

---

## 9. Dependencies

Zero third-party dependencies for MVP. Everything is built with Apple-native frameworks:

| Need | Framework |
|------|-----------|
| UI | SwiftUI |
| Networking | URLSession + async/await |
| Camera | AVFoundation |
| Maps | MapKit |
| Image loading/caching | AsyncImage + URLCache |
| QR Code generation | CoreImage (`CIQRCodeGenerator` filter) |
| Keychain access | Security framework (thin wrapper) |
| JSON encoding/decoding | Codable |
| Location | CoreLocation |
| Deep-linking | Universal Links + `.onOpenURL` |
| Testing | XCTest (+ SwiftCheck where property-based testing applies) |

---

## 10. iOS Testing Strategy

The iOS app is tested in three layers:

### Unit Tests (XCTest)

- **ViewModel logic**: state transitions, validation, calls to repositories (with mocked repositories).
- **Repository logic**: caching behaviour, decision logic (network vs cache vs queue), with mocked `NetworkClient`.
- **NetworkClient**: JWT injection, 401 retry-after-refresh, error mapping. Uses `URLProtocol` stubs for fake responses.
- **Validation helpers**: HEIC→JPEG conversion, size checks, initials generation from display name.

### Property-Based Tests (SwiftCheck, where applicable)

Limited use on iOS — most properties live server-side. The iOS-relevant one:

- **Property 7 (initials generation)** — for any non-empty display name, the generated initials contain the first character of the first word and the first character of the last word (or just the first character if single-word), and are never empty.

### Integration / UI Tests (XCUITest)

End-to-end flows on a simulator with the backend stubbed:

- Sign in with Apple → profile setup → first group creation → first pint logged.
- Deep-link invite flow (cold start and warm start).
- Camera capture → submit → leaderboard update.
- Account deletion → keychain cleared → return to login.
