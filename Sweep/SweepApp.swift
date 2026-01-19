//
//  SweepApp.swift
//  Sweep
//
//  Created by Sam Bender on 1/10/26.
//

import SwiftUI
import SwiftData
import GoogleSignIn

@main
struct SweepApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let modelContainer: ModelContainer
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = EmailListViewModel()

    init() {
        let schema = Schema([KeptThread.self])
        let modelConfig = ModelConfiguration(schema: schema)
        do {
            modelContainer = try ModelContainer(for: schema, configurations: modelConfig)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        KeptThreadsStore.shared.configure(with: modelContainer)

        let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String
            ?? "270582623086-t6c86nnemdho0qgvfaaau5vb287ur535.apps.googleusercontent.com"
        let serverClientID = Bundle.main.object(forInfoDictionaryKey: "GIDServerClientID") as? String
            ?? "270582623086-qru4e2psm743knee9uth9ohlpdbd804t.apps.googleusercontent.com"
        let gidConfig = GIDConfiguration(clientID: clientID, serverClientID: serverClientID)
        GIDSignIn.sharedInstance.configuration = gidConfig
    }

    var body: some Scene {
        WindowGroup {
            ContentRouter()
                .environmentObject(viewModel)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) {
            if scenePhase == .background {
                Task {
                    await viewModel.processNonKeptThreads()
                }
            } else if scenePhase == .active {
                Task {
                    await NotificationService.shared.notifyAppOpened()
                }
            }
        }
    }
}

struct ContentRouter: View {
    @ObservedObject private var accountManager = AccountManager.shared

    var body: some View {
        Group {
            if MockDataProvider.isEnabled || accountManager.isLoading || accountManager.hasAnyAccount {
                EmailListView()
            } else {
                SignInView()
            }
        }
        .onAppear {
            WebViewPool.shared.warmUp()
        }
    }
}

extension Color {
    init(hex: Int) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
