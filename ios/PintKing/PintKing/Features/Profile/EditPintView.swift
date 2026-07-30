//
//  EditPintView.swift
//  PintKing
//
//  The edit-pint bottom sheet (Task 17): from My Pints, change a pint's note and
//  drink type. A thin renderer over EditPintViewModel — the metadata rules and the
//  editPint hand-off live there. Mirrors the post-capture sheet's note field +
//  drink chips, minus the photo (which isn't editable).
//

import SwiftUI

struct EditPintView: View {
    @State private var model: EditPintViewModel
    @Environment(\.dismiss) private var dismiss

    /// Called once the edit is saved so the parent can re-fetch.
    let onSaved: () -> Void

    init(
        pint: PintLog,
        pintRepository: any PintRepositoryProtocol,
        onSaved: @escaping () -> Void
    ) {
        _model = State(initialValue: EditPintViewModel(pint: pint, pintRepository: pintRepository))
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Note") {
                    TextField("Add a note (optional)", text: $model.note, axis: .vertical)
                        .lineLimit(3...6)
                    Text("\(model.remainingCharacters) characters left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Drink") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(DrinkType.allCases, id: \.self) { type in
                                DrinkChip(
                                    type: type,
                                    isSelected: model.drinkType == type,
                                    action: { model.selectDrinkType(type) }
                                )
                            }
                        }
                    }
                }

                if let errorMessage = model.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Edit Pint")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) { saveButton }
            }
            .onChange(of: model.isSaved) { _, saved in
                if saved {
                    onSaved()
                    dismiss()
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var saveButton: some View {
        SwiftUI.Group {
            if model.isSaving {
                ProgressView()
            } else {
                Button("Save") {
                    Task { await model.save() }
                }
            }
        }
    }
}

/// A selectable drink-type pill (local copy of the post-capture sheet's chip;
/// kept per-feature until a shared one is genuinely warranted).
private struct DrinkChip: View {
    let type: DrinkType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(type.rawValue.capitalized)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary),
                    in: .capsule
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    EditPintView(
        pint: MockData.pints[0],
        pintRepository: MockPintRepository()
    ) {}
}
