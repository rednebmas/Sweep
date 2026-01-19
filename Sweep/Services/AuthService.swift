//
//  AuthService.swift
//  Sweep
//

import Foundation
import Combine
import GoogleSignIn

@MainActor
class AuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var userEmail: String?
    @Published var error: Error?

    private var currentUser: GIDGoogleUser?
    private(set) var serverAuthCode: String?

    var accessToken: String? {
        currentUser?.accessToken.tokenString
    }

    var accountId: String {
        guard let email = userEmail else { return UUID().uuidString }
        return email.data(using: .utf8)?.base64EncodedString() ?? email
    }

    init() {}

    func restorePreviousSignIn() async -> Bool {
        await withCheckedContinuation { continuation in
            GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
                Task { @MainActor in
                    if let user = user {
                        self?.handleSignInSuccess(user)
                        self?.isLoading = false
                        continuation.resume(returning: true)
                    } else {
                        if let error = error {
                            self?.error = error
                        }
                        self?.isLoading = false
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }

    func waitForReady() async {
        guard isLoading else { return }
        for await loading in $isLoading.values where !loading {
            return
        }
    }

    func signIn() async throws {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            throw AuthError.noRootViewController
        }

        let scopes = [
            "https://www.googleapis.com/auth/gmail.readonly",
            "https://www.googleapis.com/auth/gmail.modify",
            "https://www.googleapis.com/auth/gmail.settings.basic"
        ]

        return try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(
                withPresenting: rootViewController,
                hint: nil,
                additionalScopes: scopes
            ) { [weak self] result, error in
                Task { @MainActor in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let user = result?.user else {
                        continuation.resume(throwing: AuthError.noUser)
                        return
                    }

                    self?.serverAuthCode = result?.serverAuthCode
                    self?.handleSignInSuccess(user)
                    continuation.resume()
                }
            }
        }
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        isAuthenticated = false
        userEmail = nil
    }

    func refreshTokenIfNeeded() async throws {
        guard let user = currentUser else {
            throw AuthError.notSignedIn
        }

        return try await withCheckedThrowingContinuation { continuation in
            user.refreshTokensIfNeeded { [weak self] user, error in
                Task { @MainActor in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        if let user = user {
                            self?.currentUser = user
                        }
                        continuation.resume()
                    }
                }
            }
        }
    }

    private func handleSignInSuccess(_ user: GIDGoogleUser) {
        currentUser = user
        isAuthenticated = true
        userEmail = user.profile?.email
        Task {
            _ = await NotificationService.shared.requestPermission()
        }
    }
}

enum AuthError: Error, LocalizedError {
    case noRootViewController
    case noUser
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .noRootViewController:
            return "Could not find root view controller"
        case .noUser:
            return "Sign in did not return a user"
        case .notSignedIn:
            return "Not signed in"
        }
    }
}
