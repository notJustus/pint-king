//
//  ContentView.swift
//  PintKing
//
//  The root tab bar (Home / "+" / Profile). It's a thin declarative shell over
//  RootTabViewModel — all the routing decisions (present the camera, stay on the
//  current tab, disable "+" with no active group) live in the view model so they
//  can be unit-tested without SwiftUI. Screens are placeholders for now; each
//  later task fills one in.
//

import SwiftUI

struct ContentView: View {
    @State private var model: RootTabViewModel

    private let groupRepository: any GroupRepositoryProtocol
    private let userRepository: any UserRepositoryProtocol
    private let leaderboardRepository: any LeaderboardRepositoryProtocol
    private let pintRepository: any PintRepositoryProtocol
    private let mapRepository: any MapRepositoryProtocol
    private let authRepository: any AuthRepositoryProtocol
    private let locationPermission: any LocationPermissionRequesting

    init(
        groupRepository: any GroupRepositoryProtocol,
        userRepository: any UserRepositoryProtocol,
        leaderboardRepository: any LeaderboardRepositoryProtocol,
        pintRepository: any PintRepositoryProtocol,
        mapRepository: any MapRepositoryProtocol,
        authRepository: any AuthRepositoryProtocol,
        locationPermission: any LocationPermissionRequesting
    ) {
        self.groupRepository = groupRepository
        self.userRepository = userRepository
        self.leaderboardRepository = leaderboardRepository
        self.pintRepository = pintRepository
        self.mapRepository = mapRepository
        self.authRepository = authRepository
        self.locationPermission = locationPermission
        _model = State(initialValue: RootTabViewModel(groupRepository: groupRepository))
    }

    var body: some View {
        TabView(selection: tabSelection) {
            HomeView(
                groupRepository: groupRepository,
                leaderboardRepository: leaderboardRepository,
                pintRepository: pintRepository,
                mapRepository: mapRepository
            )
            .tabItem { Label("Home", systemImage: "trophy") }
            .tag(RootTab.home)

            // "+" is a trigger, not a destination. Its content is never shown —
            // tapping it routes through `tabSelection` to open the camera. The
            // placeholder here only exists so the tag has a view to bind to.
            Color.clear
                .tabItem { Label("Add", systemImage: "plus.circle.fill") }
                .tag(RootTab.add)
                .disabled(!model.canLogPint)

            NavigationStack {
                ProfileView(
                    userRepository: userRepository,
                    groupRepository: groupRepository,
                    pintRepository: pintRepository,
                    authRepository: authRepository,
                    locationPermission: locationPermission
                )
            }
            .tabItem { Label("Profile", systemImage: "person.crop.circle") }
            .tag(RootTab.profile)
        }
        .fullScreenCover(isPresented: $model.isCameraPresented) {
            // A fresh camera stack per presentation: the CameraModel owns an
            // AVCaptureSession we want built up on open and torn down on close, so
            // it's created here (not held for the app's lifetime). The group +
            // pint repositories are threaded through for the post-capture sheet's
            // createPint hand-off (Task 13).
            CameraView(
                camera: CameraModel(),
                permission: AVCameraPermission(),
                groupRepository: groupRepository,
                pintRepository: pintRepository,
                locationProvider: LocationService()
            ) {
                model.isCameraPresented = false
            }
        }
    }

    /// A binding whose setter forwards every tap to the view model. This is what
    /// makes "+" a trigger: `select(.add)` opens the camera and *keeps* the old
    /// tab, so the getter still returns the real (home/profile) selection.
    private var tabSelection: Binding<RootTab> {
        Binding(
            get: { model.selectedTab },
            set: { model.select($0) }
        )
    }
}

#Preview {
    ContentView(
        groupRepository: MockGroupRepository(),
        userRepository: MockUserRepository(),
        leaderboardRepository: MockLeaderboardRepository(),
        pintRepository: MockPintRepository(),
        mapRepository: MockMapRepository(),
        authRepository: MockAuthRepository(authenticated: true),
        locationPermission: MockLocationPermission()
    )
}
