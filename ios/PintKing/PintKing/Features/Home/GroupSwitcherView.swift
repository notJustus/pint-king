//
//  GroupSwitcherView.swift
//  PintKing
//
//  The group switcher at the top of the Home tab. Shows the Active_Group name
//  with a chevron; tapping opens a Menu of every group the user belongs to, with
//  a checkmark on the current one. When the user has no groups it shows an empty
//  state with Create/Join buttons.
//
//  A thin renderer over GroupSwitcherViewModel — all the state and the switch
//  side effect live there. Create/Join are handed up as closures; the real
//  navigation targets land in Tasks 19–21.
//

import SwiftUI

struct GroupSwitcherView: View {
    @State private var model: GroupSwitcherViewModel

    /// Invoked from the empty state's "Create" button (Group creation, Task 20).
    private let onCreate: () -> Void
    /// Invoked from the empty state's "Join" button (Group join, Task 21).
    private let onJoin: () -> Void

    init(
        groupRepository: any GroupRepositoryProtocol,
        onCreate: @escaping () -> Void = {},
        onJoin: @escaping () -> Void = {}
    ) {
        _model = State(initialValue: GroupSwitcherViewModel(groupRepository: groupRepository))
        self.onCreate = onCreate
        self.onJoin = onJoin
    }

    var body: some View {
        SwiftUI.Group {
            if model.hasGroups {
                switcherMenu
            } else {
                emptyState
            }
        }
        .task { await model.load() }
    }

    /// The active-group label as a Menu button; the menu lists all groups with a
    /// checkmark next to the active one.
    private var switcherMenu: some View {
        Menu {
            ForEach(model.groups) { group in
                Button {
                    Task { await model.select(group) }
                } label: {
                    if group.id == model.activeGroup?.id {
                        Label(group.name, systemImage: "checkmark")
                    } else {
                        Text(group.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(model.activeGroupName ?? "Select a group")
                    .font(.headline)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.primary)
        }
    }

    /// Shown when the user belongs to no groups: a prompt plus Create/Join actions.
    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("Join or create a group to get started")
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button(action: onCreate) {
                    Text("Create").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(action: onJoin) {
                    Text("Join").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}

#Preview("Has groups") {
    GroupSwitcherView(groupRepository: MockGroupRepository())
}

#Preview("Empty") {
    GroupSwitcherView(groupRepository: MockGroupRepository(groups: [], activeGroupId: nil))
}
