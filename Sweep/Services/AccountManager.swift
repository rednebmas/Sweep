//
//  AccountManager.swift
//  Sweep

import Foundation
import Combine

enum AccountError: Error, LocalizedError {
    case noEmail
    case accountAlreadyExists
    case providerNotFound

    var errorDescription: String? {
        switch self {
        case .noEmail: return "Could not get email address"
        case .accountAlreadyExists: return "Account already connected"
        case .providerNotFound: return "Provider not found"
        }
    }
}

class AccountManager: ObservableObject {
    static let shared = AccountManager()

    @Published private(set) var accounts: [EmailAccount] = []
    @Published private(set) var isLoading = true

    private var providers: [String: any EmailProviderProtocol] = [:]
    private let accountsKey = "connectedAccounts"

    var hasAnyAccount: Bool { !accounts.isEmpty }
    var hasMultipleAccounts: Bool { accounts.count > 1 }
    var enabledAccounts: [EmailAccount] { accounts.filter(\.isEnabled) }

    private init() {
        loadAccounts()
    }

    func provider(for accountId: String) -> (any EmailProviderProtocol)? {
        providers[accountId]
    }

    func addGmailAccount() async throws {
        try await addAccount(provider: GmailProvider())
    }

    func addOutlookAccount() async throws {
        try await addAccount(provider: OutlookProvider())
    }

    func addIMAPAccount(credentials: IMAPCredentials) async throws {
        try await addAccount(provider: IMAPProvider(credentials: credentials))
    }

    private func addAccount(provider: any EmailProviderProtocol) async throws {
        try await provider.signIn()

        guard let email = provider.userEmail else {
            throw AccountError.noEmail
        }

        if accounts.contains(where: { $0.email == email }) {
            throw AccountError.accountAlreadyExists
        }

        let account = EmailAccount(
            id: provider.accountId,
            providerType: provider.providerType,
            email: email,
            addedAt: Date(),
            isEnabled: true
        )

        accounts.append(account)
        providers[account.id] = provider
        saveAccounts()
    }

    func removeAccount(_ account: EmailAccount) {
        KeptThreadsStore.shared.removeAll(for: account.id)
        providers[account.id]?.signOut()
        providers.removeValue(forKey: account.id)
        accounts.removeAll { $0.id == account.id }
        saveAccounts()
        if accounts.isEmpty { ThreadDiskCache.clear() }
    }

    func toggleAccount(_ account: EmailAccount) {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else { return }
        accounts[index].isEnabled.toggle()
        saveAccounts()
    }

    func restoreAllAccounts() async {
        isLoading = true

        await clearKeychainOnFreshInstall()

        for account in accounts {
            await restoreProvider(for: account)
        }

        isLoading = false
    }

    private func clearKeychainOnFreshInstall() async {
        let key = "hasLaunchedBefore"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        let gmail = GmailProvider()
        if await gmail.restorePreviousSignIn() { gmail.signOut() }

        let outlook = OutlookProvider()
        if await outlook.restorePreviousSignIn() { outlook.signOut() }

        for email in IMAPKeychain.allEmails() {
            IMAPKeychain.delete(email: email)
        }
    }

    private func restoreProvider(for account: EmailAccount) async {
        let provider: any EmailProviderProtocol
        switch account.providerType {
        case .gmail: provider = GmailProvider()
        case .outlook: provider = OutlookProvider()
        case .imap:
            guard let credentials = IMAPKeychain.load(email: account.email) else { return }
            provider = IMAPProvider(credentials: credentials)
        }
        if await provider.restorePreviousSignIn() {
            providers[account.id] = provider
        }
    }

    private func loadAccounts() {
        guard let data = UserDefaults.standard.data(forKey: accountsKey),
              let decoded = try? JSONDecoder().decode([EmailAccount].self, from: data) else {
            return
        }
        accounts = decoded
    }

    private func saveAccounts() {
        guard let encoded = try? JSONEncoder().encode(accounts) else { return }
        UserDefaults.standard.set(encoded, forKey: accountsKey)
    }
}
