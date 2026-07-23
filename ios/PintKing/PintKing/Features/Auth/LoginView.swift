//
//  LoginView.swift
//  PintKing
//
//  The unauthenticated entry point: app branding and a "Sign in with Apple"
//  button. All behaviour lives in LoginViewModel — this view just renders its
//  state (spinner while signing in, inline error + Retry on failure) and
//  forwards taps. On success the repository flips `isAuthenticated` and RootView
//  swaps this screen for the tab bar.
//

import SwiftUI

struct LoginView: View {
    @State private var model: LoginViewModel

    init(authRepository: any AuthRepositoryProtocol) {
        _model = State(initialValue: LoginViewModel(authRepository: authRepository))
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "trophy.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
            Text("Pint King")
                .font(.largeTitle.bold())
            Text("Track your pints. Top the leaderboard.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            if let errorMessage = model.errorMessage {
                errorBanner(errorMessage)
            }

            signInButton

            Spacer().frame(height: 16)
        }
        .padding(.horizontal, 32)
    }

    /// Sign in with Apple. Styled as the Apple button (black pill, Apple logo)
    /// without pulling in AuthenticationServices yet — the real ASAuthorization
    /// flow lands with the backend (Task 26). Disabled with a spinner while a
    /// sign-in is in flight.
    private var signInButton: some View {
        Button {
            Task { await model.login() }
        } label: {
            HStack(spacing: 8) {
                if model.isLoggingIn {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "apple.logo")
                    Text("Sign in with Apple")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(.black, in: .rect(cornerRadius: 12))
            .foregroundStyle(.white)
        }
        .disabled(model.isLoggingIn)
    }

    /// Inline failure message with a Retry action (l3-ios-app.md §7: Sign in with
    /// Apple errors show a human-readable message with retry).
    private func errorBanner(_ message: String) -> some View {
        VStack(spacing: 8) {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await model.retry() }
            }
            .disabled(model.isLoggingIn)
        }
    }
}

#Preview {
    LoginView(authRepository: MockAuthRepository())
}
