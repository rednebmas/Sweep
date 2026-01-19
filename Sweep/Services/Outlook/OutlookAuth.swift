//
//  OutlookAuth.swift
//  Sweep
//
//  Note: Requires MSAL SDK. Add via Xcode:
//  File > Add Package Dependencies > https://github.com/AzureAD/microsoft-authentication-library-for-objc

import Foundation

#if canImport(MSAL)
import MSAL
#endif

class OutlookAuth {
    private var accessToken: String?
    private var refreshToken: String?
    private var userEmail: String?
    private var userId: String?
    private var authorizationCode: String?

    #if canImport(MSAL)
    private var application: MSALPublicClientApplication?
    private var currentAccount: MSALAccount?
    #endif

    private let clientId: String
    private let redirectUri: String
    private let scopes = ["Mail.Read", "Mail.ReadWrite", "User.Read", "offline_access"]

    var accountId: String {
        userId ?? UUID().uuidString
    }

    var email: String? { userEmail }
    var isAuthenticated: Bool { accessToken != nil }
    var token: String? { accessToken }
    var serverAuthCode: String? { authorizationCode }

    init() {
        self.clientId = Bundle.main.object(forInfoDictionaryKey: "MSALClientID") as? String ?? ""
        self.redirectUri = "msauth.com.sam.sweep://auth"

        #if canImport(MSAL)
        configureMSAL()
        #endif
    }

    #if canImport(MSAL)
    private func configureMSAL() {
        guard let authorityURL = URL(string: "https://login.microsoftonline.com/common") else {
            return
        }

        do {
            let authority = try MSALAADAuthority(url: authorityURL)
            let config = MSALPublicClientApplicationConfig(
                clientId: clientId,
                redirectUri: redirectUri,
                authority: authority
            )
            application = try MSALPublicClientApplication(configuration: config)
        } catch {
            print("Failed to configure MSAL: \(error)")
        }
    }
    #endif

    func signIn() async throws {
        #if canImport(MSAL)
        guard let application = application else {
            throw OutlookError.notConfigured
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = windowScene.windows.first,
                      let viewController = window.rootViewController else {
                    continuation.resume(throwing: OutlookError.noRootViewController)
                    return
                }

                let webParameters = MSALWebviewParameters(authPresentationViewController: viewController)
                let parameters = MSALInteractiveTokenParameters(scopes: self.scopes, webviewParameters: webParameters)

                application.acquireToken(with: parameters) { [weak self] result, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let result = result else {
                        continuation.resume(throwing: OutlookError.noResult)
                        return
                    }

                    self?.handleAuthResult(result)
                    continuation.resume()
                }
            }
        }
        #else
        throw OutlookError.notConfigured
        #endif
    }

    func signOut() {
        #if canImport(MSAL)
        if let application = application, let account = currentAccount {
            do {
                try application.remove(account)
            } catch {
                print("Failed to sign out: \(error)")
            }
        }
        currentAccount = nil
        #endif

        accessToken = nil
        refreshToken = nil
        userEmail = nil
    }

    func refreshTokenIfNeeded() async throws {
        #if canImport(MSAL)
        guard let application = application, let account = currentAccount else {
            throw OutlookError.notAuthenticated
        }

        let parameters = MSALSilentTokenParameters(scopes: scopes, account: account)

        return try await withCheckedThrowingContinuation { continuation in
            application.acquireTokenSilent(with: parameters) { [weak self] result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let result = result else {
                    continuation.resume(throwing: OutlookError.noResult)
                    return
                }

                self?.handleAuthResult(result)
                continuation.resume()
            }
        }
        #else
        throw OutlookError.notConfigured
        #endif
    }

    func restorePreviousSignIn() async -> Bool {
        #if canImport(MSAL)
        guard let application = application else { return false }

        do {
            let accounts = try application.allAccounts()
            guard let account = accounts.first else { return false }

            currentAccount = account
            userEmail = account.username
            userId = account.identifier

            let parameters = MSALSilentTokenParameters(scopes: scopes, account: account)

            return await withCheckedContinuation { continuation in
                application.acquireTokenSilent(with: parameters) { [weak self] result, error in
                    if let result = result {
                        self?.handleAuthResult(result)
                        continuation.resume(returning: true)
                    } else {
                        continuation.resume(returning: false)
                    }
                }
            }
        } catch {
            return false
        }
        #else
        return false
        #endif
    }

    #if canImport(MSAL)
    private func handleAuthResult(_ result: MSALResult) {
        accessToken = result.accessToken
        currentAccount = result.account
        userEmail = result.account.username
        userId = result.account.identifier
    }
    #endif
}
