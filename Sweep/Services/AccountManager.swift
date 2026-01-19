//
//  AccountManager.swift
//  Sweep

import Foundation

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

@MainActor
class AccountManager: ObservableObject {
    static let shared = AccountManager()

    @Published private(set) var accounts: [EmailAccount] = []
    @Published private(set) var isLoading = true

    private var providers: [String: any EmailProviderProtocol] = [:]
    private let accountsKey = "connectedAccounts"

    var hasAnyAccount: Bool { !accounts.isEmpty }
    var enabledAccounts: [EmailAccount] { accounts.filter(\.isEnabled) }

    private init() {
        loadAccounts()
    }

    func provider(for accountId: String) -> (any EmailProviderProtocol)? {
        providers[accountId]
    }

    func addGmailAccount() async throws {
        let provider = GmailProvider()
        try await provider.signIn()

        guard let email = provider.userEmail else {
            throw AccountError.noEmail
        }

        if accounts.contains(where: { $0.email == email }) {
            throw AccountError.accountAlreadyExists
        }

        let account = EmailAccount(
            id: provider.accountId,
            providerType: .gmail,
            email: email,
            addedAt: Date(),
            isEnabled: true
        )

        accounts.append(account)
        providers[account.id] = provider
        saveAccounts()
    }

    func removeAccount(_ account: EmailAccount) {
        providers[account.id]?.signOut()
        providers.removeValue(forKey: account.id)
        accounts.removeAll { $0.id == account.id }
        saveAccounts()
    }

    func toggleAccount(_ account: EmailAccount) {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else { return }
        accounts[index].isEnabled.toggle()
        saveAccounts()
    }

    func restoreAllAccounts() async {
        isLoading = true

        await migrateExistingGmailAccount()

        for account in accounts {
            await restoreProvider(for: account)
        }

        isLoading = false
    }

    private func restoreProvider(for account: EmailAccount) async {
        switch account.providerType {
        case .gmail:
            let provider = GmailProvider()
            if await provider.restorePreviousSignIn() {
                providers[account.id] = provider
            }
        case .outlook:
            break
        }
    }

    private func migrateExistingGmailAccount() async {
        guard !UserDefaults.standard.bool(forKey: "multiAccountMigrated") else { return }

        let provider = GmailProvider()
        if await provider.restorePreviousSignIn(), let email = provider.userEmail {
            let existingAccount = accounts.first { $0.email == email }
            if existingAccount == nil {
                let account = EmailAccount(
                    id: provider.accountId,
                    providerType: .gmail,
                    email: email,
                    addedAt: Date(),
                    isEnabled: true
                )
                accounts.append(account)
                providers[account.id] = provider
                saveAccounts()

                KeptThreadsStore.shared.migrateExistingThreads(to: account.id)
            }
        }

        UserDefaults.standard.set(true, forKey: "multiAccountMigrated")
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
