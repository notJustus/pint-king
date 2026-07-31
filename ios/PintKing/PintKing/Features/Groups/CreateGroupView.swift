//
//  CreateGroupView.swift
//  PintKing
//
//  The Create Group screen (Task 20): a single-field form to name a new group. A
//  thin renderer over CreateGroupViewModel — all validation and the create hand-off
//  live there. On a successful create the view calls `onCreated` so the presenting
//  screen can dismiss; because the repository sets the new group active, the Home
//  tab re-renders to its leaderboard on its own.
//
//  Presented as a sheet from the group entry points (Group List's Create action and
//  the Home switcher's empty state), so it carries its own Cancel and a nav-bar
//  Create — mirroring the Edit Profile form's toolbar shape (Task 16).
//

import SwiftUI

struct CreateGroupView: View {
    @State private var model: CreateGroupViewModel

    /// Called once creation finishes successfully so the presenter can dismiss. The
    /// view model owns the *decision* (`isCreated`); this hands that one event up.
    private let onCreated: () -> Void

    @Environment(\.dismiss) private var dismiss

    init(
        groupRepository: any GroupRepositoryProtocol,
        onCreated: @escaping () -> Void = {}
    ) {
        _model = State(initialValue: CreateGroupViewModel(groupRepository: groupRepository))
        self.onCreated = onCreated
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Group name") {
                    TextField("Group name", text: $model.name)
                        .textInputAutocapitalization(.words)
                    Text("\(model.trimmedName.count)/50")
                        .font(.caption2)
                        .foregroundStyle(model.isNameValid ? Color.secondary : Color.red)
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
            .navigationTitle("Create Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if model.isCreating {
                        ProgressView()
                    } else {
                        Button("Create") {
                            Task { await model.create() }
                        }
                        .disabled(!model.isNameValid)
                    }
                }
            }
            // Dismiss the moment the view model reports the create finished.
            .onChange(of: model.isCreated) { _, created in
                if created { onCreated() }
            }
        }
    }
}

#Preview {
    CreateGroupView(groupRepository: MockGroupRepository())
}
