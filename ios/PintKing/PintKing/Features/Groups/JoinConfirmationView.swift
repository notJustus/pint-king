//
//  JoinConfirmationView.swift
//  PintKing
//
//  The Join Confirmation screen (Task 21): the deliberate "yes, join this group"
//  step before the membership is created. A thin renderer over
//  JoinConfirmationViewModel — the join call and all three failure messages live
//  there.
//
//  It shows the invite code rather than the group's name: the API resolves a code
//  only by attempting the join, so nothing before that call knows the name
//  (ADR-0099). Cancel pops back to the code field; a success calls `onJoined`,
//  which dismisses the whole flow — the joined group is already active, so Home
//  re-renders to its leaderboard on its own.
//

import SwiftUI

struct JoinConfirmationView: View {
    @State private var model: JoinConfirmationViewModel

    /// Called once the join succeeds so the presenter can dismiss the flow.
    private let onJoined: () -> Void

    @Environment(\.dismiss) private var dismiss

    init(
        inviteCode: String,
        groupRepository: any GroupRepositoryProtocol,
        onJoined: @escaping () -> Void = {}
    ) {
        _model = State(initialValue: JoinConfirmationViewModel(
            inviteCode: inviteCode,
            groupRepository: groupRepository
        ))
        self.onJoined = onJoined
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "person.3.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            VStack(spacing: 8) {
                Text("Join this group?")
                    .font(.title2.weight(.semibold))
                Text(model.inviteCode)
                    .font(.title3.monospaced().weight(.medium))
                    .foregroundStyle(.secondary)
                Text("You'll be added as a member and this group becomes your active group.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Task { await model.join() }
                } label: {
                    SwiftUI.Group {
                        if model.isJoining {
                            ProgressView()
                        } else {
                            Text("Join")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(model.isJoining)

                Button("Cancel") { dismiss() }
                    .disabled(model.isJoining)
            }
        }
        .padding(24)
        .navigationTitle("Join Group")
        .navigationBarTitleDisplayMode(.inline)
        // Dismiss the whole flow the moment the join lands.
        .onChange(of: model.joinedGroup) { _, group in
            if group != nil { onJoined() }
        }
    }
}

#Preview("Joinable code") {
    NavigationStack {
        JoinConfirmationView(
            inviteCode: MockData.joinableInviteCode,
            groupRepository: MockGroupRepository()
        )
    }
}

#Preview("Blocked code") {
    NavigationStack {
        JoinConfirmationView(
            inviteCode: MockData.blockedInviteCode,
            groupRepository: MockGroupRepository()
        )
    }
}
