//
//  SignInView.swift
//  Sweep
//

import SwiftUI

struct SignInView: View {
    @ObservedObject private var authService = AuthService.shared
    @State private var isSigningIn = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "envelope.badge")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)

                Text("Sweep")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Swipe to keep.\nArchive the rest.")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(spacing: 16) {
                Button {
                    signIn()
                } label: {
                    HStack {
                        Image(systemName: "envelope.fill")
                        Text("Sign in with Google")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isSigningIn)

                if isSigningIn {
                    ProgressView()
                }

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    private func signIn() {
        isSigningIn = true
        errorMessage = nil

        Task {
            do {
                try await authService.signIn()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSigningIn = false
        }
    }
}
