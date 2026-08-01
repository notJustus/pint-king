//
//  JoinGroupView.swift
//  PintKing
//
//  The Join Group screen (Task 21): a single field for an 8-character invite code.
//  A thin renderer over JoinGroupViewModel — normalisation and format validation
//  live there, so the field just binds to `inviteCode`.
//
//  Presented as a sheet from the group entry points (Group List's Join action and
//  the Home switcher's empty state), so it carries its own Cancel — the same
//  self-presenting shape as Create Group (ADR-0098). Continue pushes the Join
//  Confirmation onto this sheet's own stack; a successful join calls `onJoined`
//  so the presenter can dismiss the whole flow.
//

import SwiftUI

struct JoinGroupView: View {
    @State private var model = JoinGroupViewModel()

    /// The repository, retained so it can be threaded into the confirmation screen.
    private let groupRepository: any GroupRepositoryProtocol

    /// Called once the join succeeds so the presenter can dismiss.
    private let onJoined: () -> Void

    @Environment(\.dismiss) private var dismiss

    init(
        groupRepository: any GroupRepositoryProtocol,
        onJoined: @escaping () -> Void = {}
    ) {
        self.groupRepository = groupRepository
        self.onJoined = onJoined
    }

    /// Drives the push to the confirmation screen. The view model owns the value;
    /// this only lets the navigation stack hand `nil` back when the screen pops —
    /// the same read-through-write-via-method binding as the leaderboard's period
    /// picker.
    private var confirmingCode: Binding<String?> {
        Binding(
            get: { model.confirmingCode },
            set: { if $0 == nil { model.cancelConfirmation() } }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Invite code") {
                    TextField("aB3dE6fH", text: $model.inviteCode)
                        .font(.title2.monospaced())
                        // Codes are case-sensitive on the server, so the keyboard
                        // must not helpfully capitalise the first character.
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("\(model.inviteCode.count)/\(InviteLink.codeLength)")
                        .font(.caption2)
                        .foregroundStyle(model.isCodeValid ? Color.secondary : Color.red)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                Section {
                    Text("Groups are invite-only. Ask a member for the 8-character code from their group's invite screen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Join Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue", action: model.submit)
                        .disabled(!model.isCodeValid)
                }
            }
            .navigationDestination(item: confirmingCode) { code in
                JoinConfirmationView(
                    inviteCode: code,
                    groupRepository: groupRepository,
                    onJoined: onJoined
                )
            }
        }
    }
}

#Preview {
    JoinGroupView(groupRepository: MockGroupRepository())
}
