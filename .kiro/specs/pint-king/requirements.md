# Requirements Document

## Introduction

Pint King is an iOS-only social beer tracking app where friends compete to see who has consumed the most pints. Users authenticate via Sign in with Apple, create or join groups, log pints with optional metadata (note, photo, location, drink type), and compete on a group leaderboard. A map view visualises where pints were consumed — both personally and across the group. The app is backed by a Kotlin/Spring Boot REST API with a PostgreSQL/PostGIS database hosted on AWS.

## Glossary

- **App**: The Pint King iOS application built with SwiftUI.
- **API**: The Pint King backend REST API built with Kotlin and Spring Boot.
- **User**: An authenticated individual using the App.
- **Group**: A named collection of Users who compete together on a shared leaderboard.
- **Group_Admin**: A User with administrative privileges within a Group (typically the creator).
- **Group_Member**: A User who belongs to a Group.
- **Pint_Log**: A single recorded pint entry created by a User, containing a mandatory photo and optional metadata (note, location, drink type).
- **Leaderboard**: A ranked list of Group_Members ordered by their Pint_Log count within a Group.
- **Pint_King**: The Group_Member(s) currently ranked first on the Leaderboard. Multiple members share this title when tied.
- **Active_Group**: The single Group currently selected by a User as the target for pint logging and the default context for leaderboard and map views. Persisted across sessions.
- **Invite_Code**: A short alphanumeric code associated with a Group that allows new Users to join.
- **Invite_Link**: A deep-link URL derived from the Invite_Code that opens the App and triggers the join flow.
- **QR_Code**: A scannable image encoding the Invite_Link for a Group.
- **JWT**: A JSON Web Token (access token) used to authenticate API requests. Expires after 1 hour.
- **Refresh_Token**: A long-lived, opaque, single-use token used to obtain a new JWT without re-authenticating with Apple. Expires after 30 days. Stored in the iOS Keychain. Rotated on every use.
- **PostGIS**: A PostgreSQL extension providing geospatial data types and queries.
- **S3**: AWS Simple Storage Service used to store pint photos.
- **Heatmap**: (Post-MVP) A colour overlay on the map visualising the geographic density of Pint_Logs. Automatically replaces individual pin rendering when zoom level or pin density exceeds defined thresholds.
- **Pint_Trail**: (Post-MVP) A chronological polyline on the map connecting a User's Pint_Log locations in ascending logged_at order.

---

## Requirements

### Requirement 1: User Authentication

**User Story:** As a new or returning User, I want to sign in with my Apple ID, so that I can access the app securely without creating a separate password.

#### Acceptance Criteria

1. THE App SHALL present a "Sign in with Apple" button as the sole authentication method on the login screen.
2. WHEN a User completes Sign in with Apple for the first time, THE API SHALL create a new User record identified by the Apple-provided `apple_id`.
3. WHEN a User completes Sign in with Apple for the first time, THE App SHALL present a profile setup screen pre-filled with the name provided by Apple, allowing the User to edit their `display_name` (1–30 characters) before proceeding. The User SHALL also be able to upload a profile avatar on this screen.
4. WHEN a User completes Sign in with Apple for a subsequent session, THE API SHALL identify the existing User by `apple_id` and issue a new JWT and Refresh_Token without creating a duplicate record.
5. WHEN the API authenticates a User, THE API SHALL issue a JWT with an expiry of 1 hour and a Refresh_Token with an expiry of 30 days.
6. WHEN a User is authenticated, THE App SHALL store the JWT and Refresh_Token securely in the iOS Keychain.
7. WHEN the App detects that the JWT has expired or is about to expire (within 5 minutes), THE App SHALL silently call `POST /auth/refresh` with the Refresh_Token to obtain a new JWT and Refresh_Token, without any user interaction.
8. WHEN the API receives a valid `POST /auth/refresh` request, THE API SHALL invalidate the submitted Refresh_Token, issue a new JWT and a new Refresh_Token (single-use rotation), and return both to the App.
9. IF the Refresh_Token has expired or is invalid, THEN THE API SHALL return a 401 response and THE App SHALL clear the Keychain and present the login screen.
10. WHEN the API receives a `POST /auth/refresh` request with a Refresh_Token that has already been used, THE API SHALL treat this as a token reuse attack, invalidate all Refresh_Tokens for that User, return a 401 response, and THE App SHALL present the login screen.
11. IF Sign in with Apple returns an error, THEN THE App SHALL display a human-readable error message and allow the User to retry.
12. WHEN a User completes the profile setup screen for the first time, THE App SHALL request iOS location permission ("Allow While Using App") with a clear explanation that location is used to show where pints were consumed on the map.
13. IF a User denies location permission during onboarding, THE App SHALL store this decision and SHALL NOT request location permission again automatically.
14. THE App SHALL provide a setting on the profile screen labelled "Enable Location for Pint Logs" that, when tapped, displays a single in-app explanation prompt and a button that deep-links directly to the App's iOS Settings page where the User can grant location permission.
15. THE App SHALL NOT display the in-app location explanation prompt (criterion 14) more than once. After it has been shown, the setting SHALL only deep-link directly to iOS Settings without showing the prompt again.

---

### Requirement 2: User Profile and Avatar

**User Story:** As a User, I want to manage my display name and profile avatar, so that my friends can recognise me on the leaderboard.

#### Acceptance Criteria

1. THE App SHALL provide a profile screen where an authenticated User can update their `display_name` at any time.
2. THE App SHALL allow a User to upload a profile avatar image from their photo library or camera.
3. WHEN a User selects an avatar image, THE App SHALL validate the image client-side before uploading: it SHALL convert HEIC/HEIF images to JPEG, reject any file that is not JPEG or PNG after conversion, and reject any file exceeding 5 MB. IF client-side validation fails, THE App SHALL display an inline error message and SHALL NOT initiate an upload.
4. WHEN a User's avatar passes client-side validation, THE App SHALL upload the image to S3 and THE API SHALL store the resulting `avatar_url` on the User record.
5. WHEN the API receives an avatar upload, THE API SHALL independently validate that the file is a JPEG or PNG and does not exceed 5 MB, regardless of any client-side validation. IF server-side validation fails, THE API SHALL return a 422 response and THE App SHALL display an appropriate error message.
6. THE App SHALL display the User's `display_name` and avatar on the leaderboard and map view wherever the User's identity is shown.
7. IF a User has not uploaded an avatar, THE App SHALL display a default placeholder avatar generated from the User's initials.

---

### Requirement 3: Group Management

**User Story:** As a User, I want to create and manage groups, so that I can compete with specific sets of friends separately (e.g. "Work Crew", "Uni Lads").

#### Acceptance Criteria

1. THE App SHALL allow an authenticated User to create a Group by providing a name (1–50 characters).
2. THE API SHALL enforce a maximum of 99 Groups created per User. IF a User attempts to create a Group when they have already created 99 Groups, THE API SHALL return a 422 response and THE App SHALL display a message indicating the limit has been reached.
3. WHEN a Group is created, THE API SHALL generate a unique Invite_Code (8 alphanumeric characters) for that Group and assign the creating User as Group_Admin.
4. THE App SHALL display the Invite_Code, Invite_Link, and QR_Code for a Group to any Group_Member viewing the Group's invite screen.
5. WHEN a User submits a valid Invite_Code, THE API SHALL add that User as a Group_Member with the role of `member`.
6. WHEN a User opens a valid Invite_Link, THE App SHALL deep-link directly to the join confirmation screen for that Group.
7. IF a User submits an Invite_Code that does not correspond to any Group, THEN THE API SHALL return a 404 error and THE App SHALL display a "Group not found" message.
8. IF a User submits an Invite_Code for a Group they already belong to, THEN THE API SHALL return a 409 error and THE App SHALL display an "Already a member" message.
9. IF a removed member attempts to use the Invite_Code for a Group they were previously removed from, THEN THE API SHALL return a 403 response and THE App SHALL display a "You have been removed from this group" message.
10. THE App SHALL allow a Group_Admin to regenerate the Invite_Code at any time, which SHALL invalidate the previous Invite_Code, Invite_Link, and QR_Code immediately.
11. THE App SHALL allow a Group_Admin to remove any Group_Member from the Group.
12. THE App SHALL allow a Group_Admin to promote any Group_Member to Group_Admin.
13. THE App SHALL allow a Group_Admin to update the Group name.
14. WHEN a Group_Admin removes a Group_Member, THE API SHALL delete the corresponding `group_members` record and retain all existing Pint_Logs for that User. The removed member's historical Pint_Logs SHALL remain visible on the Group's leaderboard and map view, attributed to them and displayed in a greyed-out style labelled "Former Member". Former members SHALL NOT be included in the active rank calculation and SHALL be shown in a separate "Former Members" section below the ranked leaderboard.
15. WHEN a Group_Admin removes a Group_Member, THE API SHALL immediately reject any subsequent requests from that User to add, edit, or delete Pint_Logs within that Group with a 403 response.
16. THE App SHALL allow a User to belong to multiple Groups simultaneously.
17. THE App SHALL allow a User to leave a Group voluntarily, provided the User is not the sole Group_Admin.
18. IF a User attempts to leave a Group where they are the sole Group_Admin, THEN THE App SHALL prompt the User to promote another member before leaving.
19. THE App SHALL maintain a single Active_Group per User, which is the Group currently selected for pint logging and leaderboard display.
20. THE App SHALL display the Active_Group name prominently on the home screen and allow the User to switch the Active_Group via a dropdown or picker at any time.
21. WHEN a User switches the Active_Group, THE App SHALL immediately update the home screen leaderboard and scope all subsequent pint logs to the newly selected Group.
22. WHEN a User first joins or creates a Group and has no Active_Group set, THE App SHALL automatically set that Group as the Active_Group.
23. WHEN a User's Active_Group is removed (because they were removed from it or left it), THE App SHALL automatically set the Active_Group to another Group the User belongs to, or display a "Join or create a group to get started" empty state if no Groups remain.

---

### Requirement 4: Pint Logging

**User Story:** As a User, I want to log a pint quickly by taking a photo, so that I can record my consumption with minimal friction while providing proof of the drink.

#### Acceptance Criteria

1. THE App SHALL provide a prominent "Add Pint" button accessible from the main screen without requiring navigation deeper than one tap.
2. IF a User has no Active_Group set, THE App SHALL disable the "Add Pint" button and display a prompt to join or create a Group.
3. WHEN a User taps "Add Pint", THE App SHALL immediately open a full-screen camera view with a single large shutter button, defaulting to the rear camera with auto-exposure and auto-focus. No intermediate navigation or options screen SHALL be shown.
4. A photo is mandatory for every Pint_Log. THE App SHALL NOT allow a Pint_Log to be submitted without a photo.
5. WHEN a User taps the shutter button, THE App SHALL capture the photo immediately without displaying a retake/confirmation screen, and proceed to create the Pint_Log.
6. WHEN a Pint_Log is created, THE API SHALL associate it with the User and the Active_Group, recording the `logged_at` timestamp.
7. WHEN a User captures a pint photo, THE App SHALL validate the image client-side before uploading: it SHALL convert HEIC/HEIF images to JPEG, reject any file that is not JPEG or PNG after conversion, and reject any file exceeding 10 MB. IF client-side validation fails, THE App SHALL display an inline error message and SHALL NOT submit the Pint_Log.
8. WHEN a pint photo passes client-side validation, THE App SHALL upload the image to S3 and THE API SHALL store the resulting `photo_url` on the Pint_Log.
9. WHEN the API receives a pint photo upload, THE API SHALL independently validate that the file is a JPEG or PNG and does not exceed 10 MB, regardless of any client-side validation. IF server-side validation fails, THE API SHALL return a 422 response and THE App SHALL display an appropriate error message.
10. THE API SHALL only insert the Pint_Log record into the database after the photo has been successfully uploaded to S3. IF the S3 upload fails for any reason, THE API SHALL NOT create the Pint_Log record and SHALL return a 500 response. THE App SHALL display an error message and return the User to the camera view so they can retry.
11. THE App SHALL allow a User to optionally attach a text note (maximum 280 characters) to a Pint_Log after creation.
12. THE App SHALL allow a User to optionally select a drink type from a predefined list (Beer, Lager, Ale, Stout, Cider) when logging a pint.
13. WHEN a User grants location permission, THE App SHALL automatically capture and attach the GPS location to every Pint_Log without requiring any per-pint user action.
14. WHEN a User grants location permission and logs a pint, THE API SHALL store the location as a PostGIS `GEOMETRY(Point, 4326)` on the Pint_Log.
15. IF the GPS location cannot be determined within 10 seconds of tapping the shutter, THE App SHALL submit the Pint_Log without a location and silently omit the location without interrupting the flow.
16. THE App SHALL allow a User to delete a Pint_Log they created within 24 hours of its `logged_at` timestamp.
17. IF a User attempts to delete a Pint_Log older than 24 hours, THEN THE App SHALL display a message indicating the log can no longer be deleted.
18. WHEN a Pint_Log is deleted, THE API SHALL remove the Pint_Log record and the associated photo from S3 in a single atomic operation.

---

### Requirement 5: Leaderboard

**User Story:** As a Group_Member, I want to see a ranked leaderboard of pint counts, so that I know where I stand in the competition.

#### Acceptance Criteria

1. THE App SHALL display a Leaderboard for each Group showing all Group_Members ranked in descending order by Pint_Log count.
2. THE App SHALL allow a User to filter the Leaderboard by time period: All-Time, This Month, and This Week.
3. WHEN the Leaderboard is filtered by "This Week", THE API SHALL count only Pint_Logs with a `logged_at` timestamp within the current ISO calendar week (Monday 00:00 to Sunday 23:59 in the User's local timezone).
4. WHEN the Leaderboard is filtered by "This Month", THE API SHALL count only Pint_Logs with a `logged_at` timestamp within the current calendar month.
5. THE App SHALL display a crown badge next to all Group_Members sharing the top rank on the Leaderboard.
6. WHEN two or more Group_Members have equal pint counts, THE API SHALL assign them the same rank. The next rank position SHALL continue sequentially from the number of members above it (e.g. two members tied at rank 1 means the next member is rank 2).
7. WHEN the Leaderboard is filtered by "This Week", THE App SHALL display the rank movement (delta) for each Group_Member compared to their rank in the previous calendar week's final ranking.
8. WHEN the Leaderboard is filtered by "This Month", THE App SHALL display the rank movement (delta) for each Group_Member compared to their rank in the previous calendar month's final ranking.
9. WHEN the Leaderboard is filtered by "All-Time", THE App SHALL NOT display a rank delta.
10. THE App SHALL refresh the Leaderboard data when the User navigates to the Leaderboard screen or performs a pull-to-refresh gesture.
11. WHEN a Group has no Pint_Logs for the selected time period, THE App SHALL display a "No pints logged yet" empty state.
12. THE App SHALL display former members' pint counts in a separate "Former Members" section below the ranked leaderboard, rendered in a greyed-out style. Former members SHALL NOT be assigned a rank or affect the rank of active members.

---

### Requirement 6: Map View

**User Story:** As a User, I want to see where pints have been consumed on a map, so that I can explore drinking locations and relive nights out.

#### Acceptance Criteria

1. THE App SHALL provide a Map View screen powered by MapKit.
2. THE App SHALL allow a User to toggle the Map View between Personal mode (showing only the authenticated User's Pint_Logs) and Group mode (showing all Group_Members' Pint_Logs).
3. WHEN in Personal mode, THE App SHALL render each Pint_Log that has a location as a map pin at its stored coordinates. Each pin SHALL display the User's avatar image as the pin marker.
4. WHEN in Group mode, THE App SHALL render each Group_Member's Pint_Logs as map pins at their stored coordinates. Each pin SHALL display the respective Group_Member's avatar image as the pin marker.
5. IF a User has no avatar, THE App SHALL render their map pins using a placeholder marker displaying the User's initials.
6. WHEN in Group mode, THE App SHALL render Pint_Logs belonging to former members as greyed-out map pins, visually distinct from active members' pins.
7. WHEN a User taps a map pin, THE App SHALL display a callout showing the drink type (if present), note (if present), photo thumbnail, and `logged_at` timestamp for that Pint_Log.
8. THE API SHALL support a geospatial bounding-box query using PostGIS to return only Pint_Logs within the current map viewport, to limit data transfer.
9. IF a Pint_Log has no location data, THEN THE App SHALL exclude it from all map views.

---

### Requirement 7: API Data Integrity and Security

**User Story:** As a system operator, I want the API to enforce data integrity and access control, so that Users cannot read or modify data belonging to Groups they are not members of.

#### Acceptance Criteria

1. THE API SHALL reject any request that does not include a valid, non-expired JWT with a 401 response.
2. THE API SHALL reject any request where the authenticated User attempts to read or write Pint_Logs for a Group the User is not a member of, with a 403 response.
3. THE API SHALL reject any request where a non-Group_Admin User attempts to perform a Group_Admin action (remove member, promote member, update group name) with a 403 response.
4. THE API SHALL validate all incoming request bodies against defined schemas and return a 400 response with field-level error details for any validation failure.
5. THE API SHALL store all passwords and secrets outside of application code, using environment variables or AWS Secrets Manager.
6. WHEN a pint photo is uploaded, THE API SHALL validate that the file is a JPEG or PNG with a maximum size of 10 MB before storing it to S3. WHEN an avatar is uploaded, THE API SHALL validate that the file is a JPEG or PNG with a maximum size of 5 MB.
7. IF a photo upload exceeds the applicable size limit or is not a JPEG or PNG, THEN THE API SHALL return a 422 response and THE App SHALL display an appropriate error message.

---

### Requirement 8: Account Deletion

**User Story:** As a User, I want to permanently delete my account, so that I can remove all my personal data from the app in compliance with my right to erasure.

#### Acceptance Criteria

1. THE App SHALL provide an account deletion option on the profile screen, clearly labelled "Delete Account".
2. WHEN a User taps "Delete Account", THE App SHALL display a confirmation dialog explaining that deletion is permanent and irreversible, listing what will be deleted: the User's profile, all their Pint_Logs, and their avatar photo.
3. WHEN a User confirms account deletion, THE API SHALL permanently delete the User's record, all associated Pint_Logs, all associated photos from S3, and all Refresh_Tokens for that User.
4. WHEN a User's account is deleted, THE API SHALL remove the User from all Groups they belong to. IF the User was the sole Group_Admin of any Group, THE API SHALL either promote the longest-standing member to Group_Admin, or delete the Group if no other members exist.
5. WHEN account deletion is complete, THE API SHALL revoke the User's active JWT and THE App SHALL clear the Keychain and present the login screen.
6. THE API SHALL complete the full account deletion operation within a single transaction to ensure no partial deletion state is possible.

---

### Requirement 9: Post-MVP — Pint Trail

**User Story:** As a User, I want to see a chronological trail of my pint locations on the map, so that I can relive the route of a night out.

#### Acceptance Criteria

1. WHERE Pint_Trail is enabled, THE App SHALL display a Pint_Trail for a selected User, rendered as a chronological polyline connecting that User's Pint_Log locations in ascending `logged_at` order.
2. WHERE Pint_Trail is enabled, THE App SHALL allow a User to select any Group_Member in Group mode to view their individual Pint_Trail.

---

### Requirement 10: Post-MVP — Heatmap

**User Story:** As a User, I want to see a heatmap of pint density on the map, so that I can understand where the group drinks most without individual pins becoming unreadable.

#### Acceptance Criteria

1. WHERE Heatmap is enabled, THE App SHALL automatically switch from individual avatar pin rendering to a Heatmap overlay when the map zoom level falls below a defined threshold, indicating the user has zoomed out significantly.
2. WHERE Heatmap is enabled, THE App SHALL also automatically switch to Heatmap rendering when the density of visible pins within the current viewport exceeds a defined threshold, regardless of zoom level.
3. WHERE Heatmap is enabled, THE App SHALL automatically switch back to individual avatar pin rendering when the User zooms in sufficiently and pin density falls below the threshold.
4. WHERE Heatmap is enabled, THE Heatmap SHALL reflect the currently selected scope (Personal or Group mode).

---

### Requirement 11: Post-MVP — Push Notifications

**User Story:** As a Group_Member, I want to receive push notifications about leaderboard changes, so that I stay engaged with the competition.

#### Acceptance Criteria

1. WHERE push notifications are enabled, THE App SHALL request iOS notification permission from the User on first launch after authentication.
2. WHERE push notifications are enabled, THE API SHALL send a push notification to a User when another Group_Member overtakes them on the Leaderboard.
3. WHERE push notifications are enabled, THE API SHALL send a push notification to a User when they are added to a new Group.
4. WHEN a User disables push notifications in iOS Settings, THE App SHALL respect the system setting and not display local notification prompts.

---

### Requirement 12: Post-MVP — Achievements and Badges

**User Story:** As a User, I want to earn achievements for drinking milestones, so that I have additional goals beyond the leaderboard.

#### Acceptance Criteria

1. WHERE achievements are enabled, THE API SHALL evaluate achievement criteria each time a Pint_Log is created and award any newly unlocked achievements to the User.
2. WHERE achievements are enabled, THE App SHALL display a notification to the User when a new achievement is unlocked.
3. WHERE achievements are enabled, THE App SHALL display all earned achievements on the User's profile screen.

---

### Requirement 13: Post-MVP — Drink Variety Tracking

**User Story:** As a User, I want to track different drink types beyond pints, so that I can log shots, cocktails, and other beverages.

#### Acceptance Criteria

1. WHERE drink variety tracking is enabled, THE App SHALL allow a User to log a drink with a type selected from an extended list including: Beer, Lager, Ale, Stout, Cider, Shot, Cocktail, Wine, Spirit.
2. WHERE drink variety tracking is enabled, THE Leaderboard SHALL display a breakdown of drink types per Group_Member in addition to the total count.

---

### Requirement 14: Post-MVP — Streaks

**User Story:** As a User, I want to see my consecutive days of pint logging, so that I am motivated to log consistently.

#### Acceptance Criteria

1. WHERE streaks are enabled, THE API SHALL calculate a User's current streak as the number of consecutive calendar days on which the User has at least one Pint_Log.
2. WHERE streaks are enabled, THE App SHALL display the User's current streak on their profile screen.
3. WHERE streaks are enabled, IF a User has no Pint_Log on a given calendar day, THEN THE API SHALL reset that User's streak to zero on the following day.

---

### Requirement 15: Post-MVP — Venue Name Inference

**User Story:** As a User, I want the venue name to be automatically filled in when I log a pint, so that my pint history shows where I was without manual effort.

#### Acceptance Criteria

1. WHERE venue name inference is enabled, WHEN a Pint_Log is created with a GPS location, THE App SHALL perform a Points of Interest (POI) lookup to attempt to resolve a venue name (e.g. "The Crown").
2. WHERE venue name inference is enabled, IF the POI lookup returns a clear match (a named establishment), THE API SHALL store the resolved venue name on the Pint_Log.
3. WHERE venue name inference is enabled, IF the POI lookup returns no clear match, THE API SHALL store an empty venue name on the Pint_Log.
4. WHERE venue name inference is enabled, IF no GPS location is available on the Pint_Log, THE App SHALL skip the POI lookup and leave the venue name empty.
5. WHERE venue name inference is enabled, THE App SHALL allow a User to manually edit the venue name on any of their own Pint_Logs at any time, regardless of whether a venue name was inferred or is empty.
