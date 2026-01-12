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
        let gidConfig = GIDConfiguration(clientID: clientID)
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
            }
        }
    }
}

struct ContentRouter: View {
    @ObservedObject private var authService = AuthService.shared

    var body: some View {
        Group {
            if authService.isLoading || authService.isAuthenticated {
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
