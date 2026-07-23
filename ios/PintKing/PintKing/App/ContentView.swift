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

    init(groupRepository: any GroupRepositoryProtocol) {
        _model = State(initialValue: RootTabViewModel(groupRepository: groupRepository))
    }

    var body: some View {
        TabView(selection: tabSelection) {
            NavigationStack {
                Text("Leaderboard")
                    .navigationTitle("Home")
            }
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
                Text("Profile")
                    .navigationTitle("Profile")
            }
            .tabItem { Label("Profile", systemImage: "person.crop.circle") }
            .tag(RootTab.profile)
        }
        .fullScreenCover(isPresented: $model.isCameraPresented) {
            CameraPlaceholderView { model.isCameraPresented = false }
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

/// Stand-in for the camera modal (Tasks 11–13). A blank full-screen view with a
/// close button that dismisses back to the previously selected tab.
private struct CameraPlaceholderView: View {
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("Camera")
                .foregroundStyle(.white)
        }
        .overlay(alignment: .topLeading) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding()
            }
        }
    }
}

#Preview {
    ContentView(groupRepository: MockGroupRepository())
}
