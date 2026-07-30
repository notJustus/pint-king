//
//  EditPintViewModel.swift
//  PintKing
//
//  Screen-local state for the edit-pint bottom sheet (Task 17, l3-ios-app.md
//  §"Profile Tab"): from My Pints, change a pint's note and/or drink type — the
//  only two editable fields (the photo, group, and timestamp are fixed). Mirrors
//  PostCaptureViewModel's metadata rules (280-char note cap, toggleable drink
//  chip) but edits an existing pint via `editPint` rather than creating one.
//
//  Pre-fills from the pint passed in, and like the other view models owns only
//  screen-local state — the pint itself lives on the PintRepository. On Save it
//  writes the current note + drink type back and flips `isSaved` so the sheet can
//  dismiss and My Pints can re-fetch.
//

import Foundation

@MainActor
@Observable
final class EditPintViewModel {
    /// Note character cap, mirroring the API and PostCaptureViewModel.
    static let maxNoteLength = 280

    /// The editable note, pre-filled from the pint. The setter truncates to the
    /// cap so the field can't exceed it even on paste (same as PostCapture).
    var note: String {
        didSet {
            if note.count > Self.maxNoteLength {
                note = String(note.prefix(Self.maxNoteLength))
            }
        }
    }

    /// The chosen drink type, or nil. Set via `selectDrinkType(_:)`, which toggles
    /// — re-tapping the active chip clears it (drink type is optional on a pint).
    private(set) var drinkType: DrinkType?

    /// True while the editPint call is in flight; the Save button shows a spinner
    /// and is disabled.
    private(set) var isSaving = false

    /// Human-readable error shown inline when the save fails, else nil.
    private(set) var errorMessage: String?

    /// Flips to true once the edit is saved; the view dismisses the sheet.
    private(set) var isSaved = false

    private let pintId: UUID
    private let pintRepository: any PintRepositoryProtocol

    init(pint: PintLog, pintRepository: any PintRepositoryProtocol) {
        self.pintId = pint.id
        self.note = pint.note ?? ""
        self.drinkType = pint.drinkType
        self.pintRepository = pintRepository
    }

    // MARK: - Derived state

    /// Characters left before the cap — drives the counter under the note field.
    var remainingCharacters: Int {
        Self.maxNoteLength - note.count
    }

    // MARK: - Actions

    /// Select (or, if already selected, clear) a drink type.
    func selectDrinkType(_ type: DrinkType) {
        drinkType = (drinkType == type) ? nil : type
    }

    /// Persist the edited note + drink type. The trimmed note becomes nil when
    /// blank (a note-less pint is valid). On success flips `isSaved`; on failure
    /// shows an inline error and leaves the sheet open to retry.
    func save() async {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }

        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await pintRepository.editPint(
                pintId: pintId,
                note: trimmed.isEmpty ? nil : trimmed,
                drinkType: drinkType
            )
            isSaved = true
        } catch {
            errorMessage = "Couldn't save your changes. Please try again."
        }
    }
}
