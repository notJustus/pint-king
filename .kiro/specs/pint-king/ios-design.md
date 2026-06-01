# iOS Client Design — Pint King

## Overview

This document details the design decisions for the Pint King iOS client — a SwiftUI app targeting iOS 17+ that communicates with the Kotlin/Spring Boot backend via REST. The app handles authentication, camera capture, group management, leaderboard display, and map rendering.

---

## 1. Architecture Pattern

**Decision: MVVM + Repository Pattern**

```
View → ViewModel → Repository → NetworkClient → API
```

- **Views** — SwiftUI views, purely declarative, observe ViewModels
- **ViewModels** — `@Observable` classes that hold screen-local state and expose actions. One ViewModel per screen.
- **Repositories** — `@Observable` classes that serve as the single source of truth for a data domain. They decide whether to fetch from network, return cached data, or queue for offline sync. Injected into the SwiftUI environment.
- **NetworkClient** — a thin URLSession wrapper that handles JWT injection, refresh retry, and error mapping.

### Repositories

| Repository | Responsibility |
|-----------|---------------|
| `AuthRepository` | Sign in with Apple flow, JWT/Refresh Token storage (Keychain), silent refresh, logout |
| `GroupRepository` | Group CRUD, active group switching, invite code handling, member management |
| `PintRepository` | Pint creation (including offline queue), deletion, history fetching |
| `LeaderboardRepository` | Fetches ranked leaderboard data for a group + time period |
| `MapRepository` | Fetches pint locations within a bounding box for map rendering |
| `UserRepository` | User profile, display name updates, avatar upload |

### State ownership

- **Screen-local state** → lives in the ViewModel (e.g. form input, loading indicators, error messages)
- **Shared/global state** → lives in repositories (e.g. current user, active group, auth state)
- ViewModels observe repositories for shared data and call repository methods to trigger mutations

---

## 2. Navigation Structure

**Decision: 3-tab layout with center "+" camera trigger (TikTok-style)**

```
Tab Bar: [ Home ]  [ + ]  [ Profile ]
```

### Tab behavior

| Tab | Behavior |
|-----|----------|
| Home | NavigationStack — leaderboard/map with group switcher |
| + (center) | Not a real tab. Tapping opens camera as full-screen modal (`.fullScreenCover`). Dismissing returns to the previously active tab. |
| Profile | NavigationStack — user profile, group list, settings |

### Home Tab structure

```
Home
├── Group Switcher (dropdown at top — selects Active_Group)
├── Segmented Control: [Leaderboard | Map]
├── Leaderboard View (default)
│   ├── Ranked member rows (avatar, name, pint count, rank delta)
│   └── Tap member row → Member Pint History (scrollable list of their pint photos)
└── Map View (toggle)
    ├── Avatar pins for pint locations
    ├── Personal / Group toggle
    └── Tap pin → Pint callout (photo thumbnail, drink type, timestamp)
```

### Profile Tab structure

```
Profile
├── User card (avatar, display name, total pints)
├── Edit Profile (change name, upload avatar)
├── My Groups (list of all groups user belongs to)
│   └── Tap group → Group Detail
│       ├── Members list
│       ├── Admin actions (remove, promote — if admin)
│       ├── Invite screen (code, link, QR, share)
│       └── Leave group
├── Settings
│   ├── Location permission toggle (deep-links to iOS Settings)
│   └── Delete Account
```

### Why groups live in Profile, not Home

Home is optimized for the primary loop: check leaderboard → log pint → check leaderboard. Group management (inviting, promoting, leaving) is infrequent. The *active* group is always visible on Home via the switcher — management lives in Profile to keep Home focused.

### Deep-linking (Invite Links)

When a user taps an Invite_Link (Universal Link):
1. App opens → central deep-link handler intercepts the URL
2. If authenticated → navigate to Join Confirmation screen
3. If not authenticated → persist invite code locally → complete auth → then show Join Confirmation

Implemented via SwiftUI's `.onOpenURL` modifier at the app root level.

---

## 3. Screen Inventory

| Screen | Description | Accessed From |
|--------|-------------|---------------|
| Login | "Sign in with Apple" button | App launch (unauthenticated) |
| Profile Setup | Display name + avatar + location permission | First login only |
| Home — Leaderboard | Active group leaderboard with time filter (All-Time / Week / Month) | Home tab (default) |
| Home — Map | MapKit with avatar pins, Personal/Group toggle | Home tab (segmented control) |
| Member Pint History | Scrollable list of a member's pint photos for the active group | Tap member row on leaderboard |
| Pint Callout | Overlay showing drink type, note, photo, timestamp | Tap map pin |
| Camera (Add Pint) | Full-screen camera with custom shutter button | Center "+" tab |
| Profile | User card, edit profile, groups, settings | Profile tab |
| Edit Profile | Change display name, upload avatar | Profile screen |
| Group List | All groups the user belongs to | Profile screen |
| Group Detail | Members, admin actions, invite, leave | Tap group in Group List |
| Invite Screen | Invite code, link, QR code, share sheet | Group Detail |
| Join Confirmation | "Join [Group Name]?" with confirm/cancel | Deep-link or manual code entry |
| Join Group (Manual) | Text field to enter invite code | Group List screen |
| Settings | Location toggle, account deletion | Profile screen |
| Delete Account Confirmation | Destructive confirmation dialog | Settings |

---

## 4. Camera and Photo Pipeline

**Decision: Custom AVFoundation with @Observable camera model + minimal UIViewRepresentable**

The camera is implemented as:
- An `@Observable CameraModel` class that owns the `AVCaptureSession`, configures inputs/outputs, and handles photo capture via `AVCapturePhotoOutput`
- A minimal `UIViewRepresentable` (~10 lines) that hosts `AVCaptureVideoPreviewLayer` — the one piece with no SwiftUI equivalent
- All camera logic (start/stop session, capture, format conversion) lives in the `CameraModel`, not in a UIViewController

### Photo processing pipeline

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
  → Hand off to PintRepository for upload
  → Dismiss camera modal → return to previous tab
  → PintRepository uploads to API (or queues if offline)
```

### Why not UIImagePickerController

Apple's built-in camera UI shows a retake/confirmation screen that cannot be removed. The requirement explicitly states no confirmation step — the photo is accepted immediately on shutter tap. Custom AVFoundation is the only way to achieve this.

---

## 5. Networking Layer

**Decision: URLSession with async/await (Apple native)**

### Architecture

```swift
class NetworkClient {
    private let session: URLSession
    private let authRepository: AuthRepository  // for JWT access
    
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
    func upload(_ endpoint: Endpoint, data: Data, mimeType: String) async throws -> UploadResponse
}
```

### Endpoint modeling

Endpoints defined as an enum with associated values:

```swift
enum Endpoint {
    case createPint(photo: Data, groupId: UUID, drinkType: String?, location: Coordinate?)
    case getLeaderboard(groupId: UUID, period: Period)
    case joinGroup(inviteCode: String)
    // ...
    
    var path: String { ... }
    var method: HTTPMethod { ... }
    var body: Data? { ... }
}
```

### JWT interceptor behavior

1. Every request gets `Authorization: Bearer <jwt>` header injected automatically
2. If response is 401:
   a. Attempt `POST /auth/refresh` with the stored Refresh_Token
   b. If refresh succeeds → store new tokens → retry original request
   c. If refresh fails (401) → clear Keychain → trigger logout → show login screen
3. If response is other error → map to typed error and throw

### Error mapping

API errors are mapped to a typed enum:

```swift
enum APIError: Error {
    case unauthorized          // 401
    case forbidden(String)     // 403 + message
    case notFound              // 404
    case conflict(String)      // 409 + message
    case validationFailed([FieldError])  // 422
    case serverError           // 500
    case networkUnavailable    // no connection
}
```

ViewModels catch these and display appropriate UI (inline errors, banners, alerts).

---

## 6. Offline Behavior

**Decision: TBD — options below**

### Option A: No offline support (online-only)

The app requires connectivity for all actions. If offline, show a banner and disable interactions.

**Pros:** Simplest. No local storage, no sync logic, no conflicts.
**Cons:** Poor UX in bars with bad signal — the most common usage scenario.

### Option B: Offline queue for pint creation only

Capture photo + metadata locally, show "pending" state, upload when connectivity returns. All other features (leaderboard, map, groups) require connectivity.

**Pros:** Solves the real UX problem (logging pints in bars with bad signal). Limited scope.
**Cons:** Need local file storage for pending photos. Pending pints don't appear on leaderboard until synced.

### Option C: Full offline-first with local database

All data cached locally. App works fully offline and syncs when online.

**Pros:** Best UX. **Cons:** Massive complexity, overkill for MVP.

**Leaning: Option B**

**Decision: TBD**

---

## 7. Dependencies

**Decision: Zero third-party dependencies for MVP**

Everything is built with Apple-native frameworks:

| Need | Framework |
|------|-----------|
| UI | SwiftUI |
| Networking | URLSession + async/await |
| Camera | AVFoundation |
| Maps | MapKit |
| Image loading/caching | AsyncImage + URLCache |
| QR Code generation | CoreImage (CIQRCodeGenerator filter) |
| Keychain access | Security framework (thin wrapper) |
| JSON encoding/decoding | Codable |
| Location | CoreLocation |
| Deep-linking | Universal Links + `.onOpenURL` |
| Testing | XCTest |

No Alamofire, no Kingfisher, no third-party navigation libraries. The app is small enough that Apple's frameworks cover everything without friction.

---

## 8. Summary of Decisions

| # | Decision | Choice | Status |
|---|----------|--------|--------|
| 1 | Architecture | MVVM + Repository Pattern | ✅ Confirmed |
| 2 | Navigation | 3 tabs (Home / + / Profile), center tab opens camera modal | ✅ Confirmed |
| 3 | State management | Repositories as shared state, ViewModels for screen-local state | ✅ Confirmed |
| 4 | Camera | Custom AVFoundation with @Observable CameraModel + UIViewRepresentable | ✅ Confirmed |
| 5 | Networking | URLSession + async/await, typed Endpoint enum, JWT interceptor | ✅ Confirmed |
| 6 | Offline behavior | TBD (leaning: offline queue for pint creation only) | ⏳ Pending |
| 7 | Dependencies | Zero third-party for MVP | ✅ Confirmed |
