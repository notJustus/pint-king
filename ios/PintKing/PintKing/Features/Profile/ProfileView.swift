//
//  ProfileView.swift
//  PintKing
//
//  The Profile tab root (Task 15). A thin renderer over ProfileViewModel: a user
//  card (initials avatar, display name, total pint count) above navigation rows
//  to the profile sub-screens. The destinations (Edit Profile, My Pints, My
//  Groups, Settings) arrive in Tasks 16–19, so the rows call inert closures for
//  now — the same "wire the destination later" convention as the group switcher's
//  Create/Join buttons (Task 8).
//
//  Avatars are initials placeholders until the networking layer can load remote
//  images (Task 26), matching the leaderboard and history screens.
//

import SwiftUI

struct ProfileView: View {
    @State private var model: ProfileViewModel

    /// Repositories held so they can be threaded into the push destinations (Edit
    /// Profile, My Pints, Settings). The view model uses its own copies for
    /// loading.
    private let userRepository: any UserRepositoryProtocol
    private let groupRepository: any GroupRepositoryProtocol
    private let pintRepository: any PintRepositoryProtocol
    private let authRepository: any AuthRepositoryProtocol
    private let locationPermission: any LocationPermissionRequesting

    init(
        userRepository: any UserRepositoryProtocol,
        groupRepository: any GroupRepositoryProtocol,
        pintRepository: any PintRepositoryProtocol,
        authRepository: any AuthRepositoryProtocol,
        locationPermission: any LocationPermissionRequesting
    ) {
        _model = State(initialValue: ProfileViewModel(
            userRepository: userRepository,
            pintRepository: pintRepository
        ))
        self.userRepository = userRepository
        self.groupRepository = groupRepository
        self.pintRepository = pintRepository
        self.authRepository = authRepository
        self.locationPermission = locationPermission
    }

    var body: some View {
        List {
            Section {
                userCard
                    .redacted(reason: model.isLoading && model.user == nil ? .placeholder : [])
            }

            Section {
                editProfileRow
                NavigationLink(value: ProfileRoute.myPints) {
                    Label("My Pints", systemImage: "mug")
                }
                NavigationLink(value: ProfileRoute.groupList) {
                    Label("My Groups", systemImage: "person.3")
                }
                NavigationLink(value: ProfileRoute.settings) {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .navigationTitle("Profile")
        .navigationDestination(for: ProfileRoute.self) { route in
            switch route {
            case .editProfile(let user):
                EditProfileView(user: user, userRepository: userRepository) {
                    // A save may have renamed / re-avatared the profile — re-fetch
                    // so the card reflects it after we pop back.
                    Task { await model.refresh() }
                }
            case .myPints:
                MyPintsView(groupRepository: groupRepository, pintRepository: pintRepository)
            case .groupList:
                GroupListView(
                    groupRepository: groupRepository,
                    userRepository: userRepository
                )
            case .settings:
                SettingsView(authRepository: authRepository, locationPermission: locationPermission)
            }
        }
        .task { await model.load() }
        .refreshable { await model.refresh() }
    }

    /// Edit Profile pushes onto the Profile tab's stack, carrying the loaded user
    /// as the nav value. The row is inert until the profile has loaded — there's
    /// no user to edit before then.
    @ViewBuilder private var editProfileRow: some View {
        if let user = model.user {
            NavigationLink(value: ProfileRoute.editProfile(user)) {
                Label("Edit Profile", systemImage: "pencil")
            }
        } else {
            Label("Edit Profile", systemImage: "pencil")
                .foregroundStyle(.secondary)
        }
    }

    /// Avatar + name + total pint count.
    private var userCard: some View {
        HStack(spacing: 16) {
            AvatarCircle(name: model.displayName)
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                Text(model.displayName)
                    .font(.title2.weight(.semibold))
                Text("^[\(model.totalPintCount) pint](inflect: true) logged")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

/// The Profile tab's push destinations, used as value-based navigation values
/// (mirrors the Home tab's `MemberRoute`). Edit Profile carries the loaded user
/// so the destination pre-fills without another fetch. `User` is `Hashable` via
/// its `id`, so the enum is `Hashable` for free.
private enum ProfileRoute: Hashable {
    case editProfile(User)
    case myPints
    case groupList
    case settings
}

/// Circular initials placeholder (real avatars arrive with networking, Task 26).
/// Mirrors the leaderboard's private AvatarCircle; kept local to the Profile
/// feature rather than shared until a second caller genuinely needs it.
private struct AvatarCircle: View {
    let name: String

    var body: some View {
        ZStack {
            Circle().fill(.tint.opacity(0.2))
            Text(InitialsGenerator.initials(from: name))
                .font(.title3.weight(.semibold))
                .foregroundStyle(.tint)
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView(
            userRepository: MockUserRepository(),
            groupRepository: MockGroupRepository(),
            pintRepository: MockPintRepository(),
            authRepository: MockAuthRepository(authenticated: true),
            locationPermission: MockLocationPermission()
        )
    }
}
