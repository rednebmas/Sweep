//
//  SweepApp.swift
//  Sweep
//
//  Created by Sam Bender on 1/10/26.
//

import SwiftUI
import GoogleSignIn

@main
struct SweepApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = EmailListViewModel()

    init() {
        // Configure Google Sign-In
        let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String
            ?? "270582623086-t6c86nnemdho0qgvfaaau5vb287ur535.apps.googleusercontent.com"
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
    }

    var body: some Scene {
        WindowGroup {
            ContentRouter()
                .environmentObject(viewModel)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .background {
                Task {
                    await viewModel.archiveNonKeptThreads()
                }
            }
        }
    }
}

struct ContentRouter: View {
    @ObservedObject private var authService = AuthService.shared

    var body: some View {
        if authService.isAuthenticated {
            EmailListView()
        } else {
            SignInView()
        }
    }
}
