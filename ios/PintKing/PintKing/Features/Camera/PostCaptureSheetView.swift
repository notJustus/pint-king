//
//  PostCaptureSheetView.swift
//  PintKing
//
//  The post-capture bottom sheet (Task 13): after the shutter fires, this slides
//  up over the camera with the captured photo, an optional note field (280-char
//  cap + counter), and a row of drink-type chips. "Done" logs the pint and
//  dismisses the whole camera modal. A thin renderer over PostCaptureViewModel —
//  the metadata rules and the createPint hand-off live there so they're
//  unit-tested without SwiftUI.
//

import SwiftUI

struct PostCaptureSheetView: View {
    @State private var model: PostCaptureViewModel

    /// Called once the pint is logged so the parent can dismiss the camera modal.
    let onDone: () -> Void

    init(
        photoData: Data,
        groupRepository: any GroupRepositoryProtocol,
        pintRepository: any PintRepositoryProtocol,
        onDone: @escaping () -> Void
    ) {
        _model = State(initialValue: PostCaptureViewModel(
            photoData: photoData,
            groupRepository: groupRepository,
            pintRepository: pintRepository
        ))
        self.onDone = onDone
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    photoPreview
                    noteField
                    drinkTypePicker

                    if let errorMessage = model.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
            }
            .navigationTitle("New Pint")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { doneButton }
            }
            // Flip to the parent once the pint is logged.
            .onChange(of: model.isSaved) { _, saved in
                if saved { onDone() }
            }
        }
    }

    // MARK: - Photo

    /// The captured JPEG shown as a square thumbnail. Unlike the history screens
    /// (whose photos are remote placeholders), this is the real in-memory capture.
    private var photoPreview: some View {
        SwiftUI.Group {
            if let image = UIImage(data: model.photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 12).fill(.quaternary)
                    .overlay { Image(systemName: "mug.fill").font(.largeTitle) }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .clipShape(.rect(cornerRadius: 12))
    }

    // MARK: - Note

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Note")
                .font(.subheadline.weight(.medium))
            TextField("Add a note (optional)", text: $model.note, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
            Text("\(model.remainingCharacters) characters left")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Drink type

    private var drinkTypePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Drink")
                .font(.subheadline.weight(.medium))
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
    }

    // MARK: - Done

    private var doneButton: some View {
        SwiftUI.Group {
            if model.isSaving {
                ProgressView()
            } else {
                Button("Done") {
                    Task { await model.save() }
                }
            }
        }
    }
}

// MARK: - Chip

/// A selectable drink-type pill. Tapping toggles selection on the view model.
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
    PostCaptureSheetView(
        photoData: Data(),
        groupRepository: MockGroupRepository(),
        pintRepository: MockPintRepository(),
        onDone: {}
    )
}
