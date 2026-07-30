//
//  SettingsView.swift
//  PintKing
//
//  The Settings screen (Task 18), pushed from the Profile tab. A thin renderer
//  over SettingsViewModel: a location-permission row that reflects the current
//  status and deep-links to iOS Settings (the app can't flip the system
//  permission itself), and a destructive "Delete Account" row that presents a
//  confirmation listing everything that will be erased.
//
//  Account deletion has no completion callback: the repository clears the
//  session, and RootView — observing `isAuthenticated` — swaps the whole screen
//  back to Login declaratively. So this view just fires `deleteAccount()` and
//  lets the gate do the navigation.
//

import SwiftUI

struct SettingsView: View {
    @State private var model: SettingsViewModel

    /// Presents the destructive confirmation sheet.
    @State private var isConfirmingDelete = false

    @Environment(\.openURL) private var openURL

    init(
        authRepository: any AuthRepositoryProtocol,
        locationPermission: any LocationPermissionRequesting
    ) {
        _model = State(initialValue: SettingsViewModel(
            authRepository: authRepository,
            locationPermission: locationPermission
        ))
    }

    var body: some View {
        List {
            Section {
                locationRow
            } header: {
                Text("Location")
            } footer: {
                Text("Location is optional — it pins your pints on the map. Manage access in iOS Settings.")
            }

            Section {
                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Text("Delete Account")
                }
            }

            if let errorMessage = model.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $isConfirmingDelete) {
            DeleteAccountConfirmationView(isDeleting: model.isDeleting) {
                await model.deleteAccount()
            }
        }
    }

    /// The location row shows the current permission status and deep-links to
    /// iOS Settings, where the user actually changes it.
    private var locationRow: some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
            }
        } label: {
            HStack {
                Label("Location Access", systemImage: "location")
                Spacer()
                Text(model.locationStatusText)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .foregroundStyle(.primary)
    }
}

/// The destructive account-deletion confirmation (l3-ios-app.md §Delete Account).
/// Lists exactly what will be erased and explains the action is permanent, then
/// requires an explicit red confirm. Presented as a sheet so it can show the
/// full list of consequences (more than a system alert affords cleanly).
struct DeleteAccountConfirmationView: View {
    /// True while the parent's deletion is running — disables Delete and shows a
    /// spinner so the sheet can't be dismissed into a half-finished state.
    let isDeleting: Bool

    /// Runs the actual deletion. Async so the sheet stays up (with its spinner)
    /// until the repository call returns.
    let onConfirm: () async -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Your profile", systemImage: "person.crop.circle")
                    Label("All your pint logs", systemImage: "mug")
                    Label("Your avatar photo", systemImage: "photo")
                } header: {
                    Text("This will permanently delete")
                } footer: {
                    Text("This action is permanent and cannot be undone.")
                }

                Section {
                    Button(role: .destructive) {
                        Task {
                            await onConfirm()
                            // If deletion succeeds, RootView swaps to Login and
                            // this sheet goes away with it; dismissing here keeps
                            // things tidy on the (mock) success path too.
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if isDeleting {
                                ProgressView()
                            } else {
                                Text("Delete Account")
                            }
                            Spacer()
                        }
                    }
                    .disabled(isDeleting)
                }
            }
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isDeleting)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView(
            authRepository: MockAuthRepository(authenticated: true),
            locationPermission: MockLocationPermission(decision: .granted)
        )
    }
}
