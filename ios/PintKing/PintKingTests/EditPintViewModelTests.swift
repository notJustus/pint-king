//
//  EditPintViewModelTests.swift
//  PintKingTests
//
//  Task 17: the edit-pint bottom sheet. EditPintViewModel pre-fills from a pint,
//  enforces the 280-char note cap, toggles the drink chip, and on Save writes the
//  note + drink type back via `editPint`. These tests drive that logic directly
//  (no View), using a spy to assert exactly what Save hands the repository.
//

import Foundation
import Testing
@testable import PintKing

@MainActor
struct EditPintViewModelTests {

    /// Records the last `editPint` call so tests can assert what Save persisted.
    private final class SpyPintRepository: PintRepositoryProtocol {
        private(set) var editCount = 0
        private(set) var lastNote: String??
        private(set) var lastDrinkType: DrinkType??
        var editError: Error?
        private(set) var pendingPints: [PendingPint] = []

        func editPint(pintId: UUID, note: String?, drinkType: DrinkType?) async throws -> PintLog {
            editCount += 1
            lastNote = .some(note)
            lastDrinkType = .some(drinkType)
            if let editError { throw editError }
            return PintLog(
                id: pintId, userId: MockData.daveId, groupId: MockData.fridayId,
                photoUrl: "pints/x.jpg", note: note, drinkType: drinkType,
                location: nil, loggedAt: MockData.now
            )
        }

        // Unused by this screen.
        func createPint(groupId: UUID, photoData: Data, note: String?, drinkType: DrinkType?, location: Coordinate?) async throws -> PintLog { fatalError("unused") }
        func getMyPints(groupId: UUID?) async throws -> [PintLog] { [] }
        func getPintsForMember(userId: UUID, groupId: UUID) async throws -> [PintLog] { [] }
        func deletePint(pintId: UUID) async throws {}
        func retryPint(pintId: UUID) async throws {}
        func discardPint(pintId: UUID) async throws {}
    }

    private static func pint(note: String? = "Original", drink: DrinkType? = .lager) -> PintLog {
        PintLog(
            id: UUID(), userId: MockData.daveId, groupId: MockData.fridayId,
            photoUrl: "pints/x.jpg", note: note, drinkType: drink,
            location: nil, loggedAt: MockData.now
        )
    }

    // MARK: - Pre-fill

    @Test func prefillsFromThePint() {
        let vm = EditPintViewModel(pint: Self.pint(note: "Crisp", drink: .stout), pintRepository: SpyPintRepository())
        #expect(vm.note == "Crisp")
        #expect(vm.drinkType == .stout)
    }

    @Test func prefillsBlankNoteWhenNil() {
        let vm = EditPintViewModel(pint: Self.pint(note: nil, drink: nil), pintRepository: SpyPintRepository())
        #expect(vm.note == "")
        #expect(vm.drinkType == nil)
    }

    // MARK: - Note cap

    @Test func noteIsTruncatedToTheCap() {
        let vm = EditPintViewModel(pint: Self.pint(), pintRepository: SpyPintRepository())
        vm.note = String(repeating: "a", count: 400)
        #expect(vm.note.count == EditPintViewModel.maxNoteLength)
        #expect(vm.remainingCharacters == 0)
    }

    // MARK: - Drink chip toggle

    @Test func selectingDrinkTypeSetsThenClears() {
        let vm = EditPintViewModel(pint: Self.pint(drink: nil), pintRepository: SpyPintRepository())
        vm.selectDrinkType(.cider)
        #expect(vm.drinkType == .cider)
        vm.selectDrinkType(.cider)   // re-tap clears
        #expect(vm.drinkType == nil)
    }

    // MARK: - Save

    @Test func saveWritesNoteAndDrinkTypeThenFlipsSaved() async {
        let spy = SpyPintRepository()
        let vm = EditPintViewModel(pint: Self.pint(note: "Original", drink: .lager), pintRepository: spy)
        vm.note = "Updated"
        vm.selectDrinkType(.ale)   // lager → ale is a set (different type)

        await vm.save()

        #expect(spy.editCount == 1)
        #expect(spy.lastNote == .some("Updated"))
        #expect(spy.lastDrinkType == .some(DrinkType.ale))
        #expect(vm.isSaved)
        #expect(vm.errorMessage == nil)
    }

    @Test func saveSendsNilForABlankNote() async {
        let spy = SpyPintRepository()
        let vm = EditPintViewModel(pint: Self.pint(note: "Original"), pintRepository: spy)
        vm.note = "   "   // whitespace only → nil

        await vm.save()

        #expect(spy.lastNote == .some(String?.none))
    }

    @Test func saveFailureShowsErrorAndDoesNotFlipSaved() async {
        let spy = SpyPintRepository()
        spy.editError = APIError.serverError
        let vm = EditPintViewModel(pint: Self.pint(), pintRepository: spy)

        await vm.save()

        #expect(vm.isSaved == false)
        #expect(vm.errorMessage != nil)
    }
}
