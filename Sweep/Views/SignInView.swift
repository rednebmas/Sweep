//
//  SignInView.swift
//  Sweep
//

import SwiftUI

struct SignInView: View {
    @ObservedObject private var accountManager = AccountManager.shared
    @State private var isSigningIn = false
    @State private var showIMAPSheet = false
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

                Text("Swipe to keep.\nThe rest will be marked as read. Automatically.")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(spacing: 16) {
                Button {
                    signInWithGmail()
                } label: {
                    HStack {
                        if isSigningIn {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "envelope.fill")
                        }
                        Text("Sign in with Google")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isSigningIn)

                Button {
                    showIMAPSheet = true
                } label: {
                    Text("Other email (IMAP)")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 32)
            .sheet(isPresented: $showIMAPSheet) {
                IMAPSignInSheet()
            }

            Spacer()
        }
    }

    private func signInWithGmail() {
        isSigningIn = true
        errorMessage = nil

        Task {
            do {
                try await accountManager.addGmailAccount()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSigningIn = false
        }
    }
}
