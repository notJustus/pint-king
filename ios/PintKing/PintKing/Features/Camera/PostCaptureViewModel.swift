//
//  PostCaptureViewModel.swift
//  PintKing
//
//  Screen-local state for the post-capture bottom sheet (l3-ios-app.md §5,
//  requirements §3). After the shutter fires, the user can attach an optional
//  note (max 280 chars) and an optional drink type, then tap Done — a photo-only
//  pint is valid, so both metadata fields can be empty. Done hands the captured
//  JPEG plus whatever metadata was entered to `PintRepository.createPint`, then
//  flips `isSaved` so the camera modal can dismiss.
//
//  Like the other screen view models this owns only screen-local state; the pint
//  lives on the PintRepository. The target group is *shared* state on the
//  GroupRepository (l3-ios-app.md §1), so it's read live rather than passed in.
//  Location is deliberately omitted here — GPS-at-shutter-time lands in Task 14.
//

import Foundation

@MainActor
@Observable
final class PostCaptureViewModel {
    /// Note character cap, mirroring the API (`pint_logs.note`, requirements §3).
    static let maxNoteLength = 280

    /// The optional note. Bound to the text field; the setter truncates to
    /// `maxNoteLength` so the field can never exceed the cap even on paste.
    var note: String = "" {
        didSet {
            if note.count > Self.maxNoteLength {
                note = String(note.prefix(Self.maxNoteLength))
            }
        }
    }

    /// The chosen drink type, or nil for none. Set only via `selectDrinkType(_:)`,
    /// which toggles — tapping the selected chip again clears it.
    private(set) var drinkType: DrinkType?

    /// True while the createPint call is in flight; the Done button shows a spinner
    /// and is disabled.
    private(set) var isSaving = false

    /// Human-readable error shown inline when the save fails (or there's no active
    /// group to log against), else nil.
    private(set) var errorMessage: String?

    /// Flips to true once the pint is created; the view dismisses the whole camera
    /// modal in response.
    private(set) var isSaved = false

    /// The processed JPEG from the capture — mandatory, so it's a non-optional
    /// input rather than screen state.
    let photoData: Data

    private let groupRepository: any GroupRepositoryProtocol
    private let pintRepository: any PintRepositoryProtocol

    init(
        photoData: Data,
        groupRepository: any GroupRepositoryProtocol,
        pintRepository: any PintRepositoryProtocol
    ) {
        self.photoData = photoData
        self.groupRepository = groupRepository
        self.pintRepository = pintRepository
    }

    /// Characters left before the cap — drives the counter under the note field.
    var remainingCharacters: Int {
        Self.maxNoteLength - note.count
    }

    /// Select (or, if already selected, clear) a drink type. Drink type is optional
    /// on a pint, so tapping the active chip deselects rather than being stuck.
    func selectDrinkType(_ type: DrinkType) {
        drinkType = (drinkType == type) ? nil : type
    }

    /// Log the pint: hand the photo plus the trimmed note (nil when blank) and the
    /// chosen drink type to the repository, then mark saved. With no active group
    /// there's nowhere to log, so it surfaces an error instead. A failed save shows
    /// an inline error and leaves the sheet open to retry.
    func save() async {
        guard let groupId = groupRepository.activeGroup?.id else {
            errorMessage = "Join or create a group before logging a pint."
            return
        }

        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            _ = try await pintRepository.createPint(
                groupId: groupId,
                photoData: photoData,
                note: trimmed.isEmpty ? nil : trimmed,
                drinkType: drinkType,
                location: nil   // GPS at shutter time lands in Task 14
            )
            isSaved = true
        } catch {
            errorMessage = "Couldn't log your pint. Please try again."
        }
    }
}
