//
//  StoreService.swift
//  Sweep

import StoreKit
import Combine

@MainActor
class StoreService: ObservableObject {
    static let shared = StoreService()

    @Published private(set) var isPurchased = false
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let productId = "com.sambender.Sweep.unlock"
    private var product: Product?
    private var updateTask: Task<Void, Never>?

    private init() {
        updateTask = Task { await listenForTransactions() }
        Task { await checkPurchaseStatus() }
    }

    deinit {
        updateTask?.cancel()
    }

    func checkPurchaseStatus() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == productId {
                isPurchased = true
                return
            }
        }
        isPurchased = false
    }

    func purchase() async {
        isLoading = true
        errorMessage = nil

        do {
            if product == nil {
                let products = try await Product.products(for: [productId])
                product = products.first
            }

            guard let product else {
                errorMessage = "Product not available"
                isLoading = false
                return
            }

            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    isPurchased = true
                    await transaction.finish()
                }
            case .userCancelled:
                break
            case .pending:
                errorMessage = "Purchase pending approval"
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func restorePurchases() async {
        isLoading = true
        errorMessage = nil

        do {
            try await AppStore.sync()
            await checkPurchaseStatus()

            if !isPurchased {
                errorMessage = "No purchases to restore"
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result,
               transaction.productID == productId {
                isPurchased = true
                await transaction.finish()
            }
        }
    }
}
