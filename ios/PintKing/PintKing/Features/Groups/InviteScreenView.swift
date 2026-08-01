//
//  InviteScreenView.swift
//  PintKing
//
//  The Invite screen (Group Detail → Invite Members, Task 23): QR code, invite
//  code, invite link, share sheet, and — for admins — Regenerate.
//
//  A thin renderer over InviteScreenViewModel. The view's own @State is purely
//  presentational: whether the regenerate confirmation is up, and which value was
//  just copied (so the button can say "Copied" for a moment).
//
//  The QR sits on a white card in both colour schemes: scanners need dark modules
//  on a light background, so it must not invert in dark mode.
//

import SwiftUI

struct InviteScreenView: View {
    @State private var model: InviteScreenViewModel

    /// True while the regenerate confirmation is up (admin only).
    @State private var isConfirmingRegenerate = false

    /// Which value the user just copied, driving the transient "Copied" label.
    @State private var copied: Copyable?

    /// The two copyable values on this screen.
    private enum Copyable { case code, link }

    init(
        groupId: UUID,
        groupName: String,
        inviteCode: String,
        isAdmin: Bool,
        groupRepository: any GroupRepositoryProtocol
    ) {
        _model = State(initialValue: InviteScreenViewModel(
            groupId: groupId,
            groupName: groupName,
            inviteCode: inviteCode,
            isAdmin: isAdmin,
            groupRepository: groupRepository
        ))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                qrCard
                codeSection
                linkRow

                ShareLink(
                    item: model.inviteLink,
                    subject: Text(model.shareTitle),
                    message: Text(model.shareMessage)
                ) {
                    Label("Share Invite", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if let errorMessage = model.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                if model.isAdmin {
                    regenerateButton
                }
            }
            .padding()
        }
        .navigationTitle("Invite")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Regenerate Invite Code?",
            isPresented: $isConfirmingRegenerate,
            titleVisibility: .visible
        ) {
            Button("Regenerate", role: .destructive) {
                Task { await model.regenerate() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(InviteScreenViewModel.regenerateWarning)
        }
    }

    // MARK: - Sections

    /// The QR code on a fixed white card, so it stays scannable in dark mode.
    private var qrCard: some View {
        SwiftUI.Group {
            if let qrCode = model.qrCode {
                Image(uiImage: qrCode)
                    .interpolation(.none)   // keep module edges hard when scaled
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "qrcode")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
                    .padding(24)
            }
        }
        .frame(maxWidth: 260)
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityLabel("QR code for the invite link")
    }

    /// The invite code, large and monospaced, with a copy button.
    private var codeSection: some View {
        VStack(spacing: 8) {
            Text("Invite Code")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text(model.inviteCode)
                .font(.system(.largeTitle, design: .monospaced).weight(.bold))
                .textSelection(.enabled)
                // Character-by-character, so VoiceOver doesn't read "aB3dE6fH"
                // as a word.
                .accessibilityLabel(model.inviteCode.map(String.init).joined(separator: " "))

            copyButton(for: .code, title: "Copy Code", value: model.inviteCode)
        }
    }

    /// The derived invite link, truncated to one line, with a copy button.
    private var linkRow: some View {
        HStack {
            Text(model.inviteLinkText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            copyButton(for: .link, title: "Copy", value: model.inviteLinkText)
        }
        .padding(12)
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    /// Copies `value` to the pasteboard and confirms it for a couple of seconds.
    private func copyButton(for item: Copyable, title: String, value: String) -> some View {
        Button {
            UIPasteboard.general.string = value
            copied = item
            Task {
                try? await Task.sleep(for: .seconds(2))
                if copied == item { copied = nil }
            }
        } label: {
            Label(
                copied == item ? "Copied" : title,
                systemImage: copied == item ? "checkmark" : "doc.on.doc"
            )
            .font(.subheadline)
        }
        .buttonStyle(.bordered)
    }

    /// Admin-only rotation, always behind a confirmation — the old code stops
    /// working the moment this succeeds.
    private var regenerateButton: some View {
        Button(role: .destructive) {
            isConfirmingRegenerate = true
        } label: {
            HStack {
                Text("Regenerate Code")
                if model.isRegenerating {
                    ProgressView()
                        .padding(.leading, 8)
                }
            }
        }
        .disabled(model.isRegenerating)
        .padding(.top, 8)
    }
}

#Preview("Admin") {
    NavigationStack {
        InviteScreenView(
            groupId: MockData.fridayId,
            groupName: "Friday Club",
            inviteCode: "aB3dE6fH",
            isAdmin: true,
            groupRepository: MockGroupRepository()
        )
    }
}

#Preview("Member") {
    NavigationStack {
        InviteScreenView(
            groupId: MockData.sundayId,
            groupName: "Sunday League",
            inviteCode: "kM9nP2qR",
            isAdmin: false,
            groupRepository: MockGroupRepository()
        )
    }
}
