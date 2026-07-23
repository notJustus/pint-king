//
//  ProfileSetupView.swift
//  PintKing
//
//  The first-login setup screen: confirm/edit the pre-filled display name, pick
//  an optional avatar, then Continue (which saves, requests location permission,
//  and advances to Home). A thin renderer over ProfileSetupViewModel — all
//  validation and side effects live there. Avatar selection uses PhotosUI's
//  PhotosPicker (iOS 16+ system picker: no library permission prompt needed —
//  it grants access to just the chosen photo, l3-ios-app.md §"Photo Library").
//

import SwiftUI
import PhotosUI

struct ProfileSetupView: View {
    @State private var model: ProfileSetupViewModel
    @State private var avatarItem: PhotosPickerItem?

    /// Called once setup finishes successfully so the parent (RootView) can
    /// advance to the tab bar. The view model owns the *decision* (`isComplete`);
    /// this hands that one event up without leaking the model.
    private let onComplete: () -> Void

    init(
        initialDisplayName: String,
        userRepository: any UserRepositoryProtocol,
        locationPermission: any LocationPermissionRequesting,
        onComplete: @escaping () -> Void
    ) {
        _model = State(initialValue: ProfileSetupViewModel(
            initialDisplayName: initialDisplayName,
            userRepository: userRepository,
            locationPermission: locationPermission
        ))
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Set up your profile")
                .font(.title2.bold())
            Text("This is how you'll appear on leaderboards and the map.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            avatarPicker
            nameField

            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            continueButton
        }
        .padding(32)
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
        // Advance to Home the moment the view model reports setup finished.
        .onChange(of: model.isComplete) { _, complete in
            if complete { onComplete() }
        }
    }

    /// Circular avatar: the chosen image, or an initials placeholder derived from
    /// the current name (never blank — InitialsGenerator guarantees a fallback).
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

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Display name", text: $model.displayName)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.words)
            Text("\(model.trimmedDisplayName.count)/30")
                .font(.caption2)
                .foregroundStyle(model.isDisplayNameValid ? Color.secondary : Color.red)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var continueButton: some View {
        Button {
            Task { await model.continueSetup() }
        } label: {
            SwiftUI.Group {
                if model.isSaving {
                    ProgressView().tint(.white)
                } else {
                    Text("Continue").fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(.tint, in: .rect(cornerRadius: 12))
            .foregroundStyle(.white)
        }
        .disabled(!model.isDisplayNameValid || model.isSaving)
    }
}

#Preview {
    ProfileSetupView(
        initialDisplayName: "Dave Smith",
        userRepository: MockUserRepository(),
        locationPermission: MockLocationPermission(),
        onComplete: {}
    )
}
