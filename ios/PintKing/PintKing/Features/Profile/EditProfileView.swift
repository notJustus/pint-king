//
//  EditProfileView.swift
//  PintKing
//
//  The Edit Profile screen (Task 16): change the display name and/or avatar. A
//  thin renderer over EditProfileViewModel — all validation and the "save only
//  what changed" hand-off live there. Avatar selection uses PhotosUI's
//  PhotosPicker (same as ProfileSetupView: the system picker needs no library
//  permission). On a successful save the view calls `onSaved` so the parent can
//  pop back to the Profile tab.
//
//  Until the networking layer can load remote avatars (Task 26), an existing
//  avatar is shown as an initials placeholder; a freshly picked image renders
//  from its in-memory bytes.
//

import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @State private var model: EditProfileViewModel
    @State private var avatarItem: PhotosPickerItem?

    /// Called once a save finishes successfully so the parent can dismiss the
    /// screen. The view model owns the *decision* (`isSaved`); this hands that one
    /// event up without leaking the model.
    private let onSaved: () -> Void

    init(
        user: User,
        userRepository: any UserRepositoryProtocol,
        onSaved: @escaping () -> Void = {}
    ) {
        _model = State(initialValue: EditProfileViewModel(
            user: user,
            userRepository: userRepository
        ))
        self.onSaved = onSaved
    }

    var body: some View {
        Form {
            Section {
                avatarPicker
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            }

            Section("Display name") {
                TextField("Display name", text: $model.displayName)
                    .textInputAutocapitalization(.words)
                Text("\(model.trimmedDisplayName.count)/30")
                    .font(.caption2)
                    .foregroundStyle(model.isDisplayNameValid ? Color.secondary : Color.red)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            if let errorMessage = model.errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if model.isSaving {
                    ProgressView()
                } else {
                    Button("Save") {
                        Task { await model.save() }
                    }
                    .disabled(!model.hasChanges || !model.isDisplayNameValid)
                }
            }
        }
        // Load the chosen photo's bytes off the picker item and hand them to the
        // view model, which validates before accepting.
        .onChange(of: avatarItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    model.selectAvatar(data)
                }
            }
        }
        // Dismiss the moment the view model reports the save finished.
        .onChange(of: model.isSaved) { _, saved in
            if saved { onSaved() }
        }
    }

    /// Circular avatar: a freshly picked image, or an initials placeholder derived
    /// from the current name (never blank — InitialsGenerator guarantees a
    /// fallback). Existing remote avatars load with the networking layer (Task 26).
    private var avatarPicker: some View {
        PhotosPicker(selection: $avatarItem, matching: .images) {
            // `SwiftUI.Group` — the app's own domain model is also named `Group`.
            SwiftUI.Group {
                if let avatarData = model.avatarData, let uiImage = UIImage(data: avatarData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Circle().fill(.tint.opacity(0.2))
                        Text(InitialsGenerator.initials(from: model.displayName))
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundStyle(.tint)
                    }
                }
            }
            .frame(width: 120, height: 120)
            .clipShape(.circle)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "camera.circle.fill")
                    .font(.title)
                    .foregroundStyle(.tint)
                    .background(.background, in: .circle)
            }
        }
    }
}

#Preview {
    NavigationStack {
        EditProfileView(
            user: MockData.currentUser,
            userRepository: MockUserRepository()
        )
    }
}
