//
//  MockDataProvider.swift
//  Sweep
//

import Foundation

enum MockDataProvider {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-MockData")
    }

    static func mockThreads() -> [EmailThread] {
        let now = Date()
        let calendar = Calendar.current

        return [
            EmailThread(
                id: "mock1",
                subject: "Your flight to Tokyo is confirmed",
                snippet: "Hi Sam, your booking is complete. Flight JL5 departs SFO on March 15 at 11:30 AM...",
                from: "Japan Airlines",
                fromEmail: "reservations@jal.com",
                timestamp: calendar.date(byAdding: .hour, value: -2, to: now)!,
                hasAttachments: true,
                messageCount: 1,
                unsubscribeURL: nil,
                isKept: false
            ),
            EmailThread(
                id: "mock2",
                subject: "Your order has shipped",
                snippet: "Great news! Your order #482-9271834 is on its way. Track your package...",
                from: "Amazon",
                fromEmail: "ship-confirm@amazon.com",
                timestamp: calendar.date(byAdding: .hour, value: -5, to: now)!,
                hasAttachments: false,
                messageCount: 1,
                unsubscribeURL: URL(string: "https://amazon.com/unsubscribe"),
                isKept: false
            ),
            EmailThread(
                id: "mock3",
                subject: "Coffee this week?",
                snippet: "Hey! It's been a while. Want to grab coffee sometime this week? I'm free Thursday or Friday...",
                from: "Alex Chen",
                fromEmail: "alex.chen@gmail.com",
                timestamp: calendar.date(byAdding: .hour, value: -8, to: now)!,
                hasAttachments: false,
                messageCount: 3,
                unsubscribeURL: nil,
                isKept: true
            ),
            EmailThread(
                id: "mock4",
                subject: "Weekly digest: 12 new posts",
                snippet: "The most popular articles this week: How to build better habits, Why sleep matters more than...",
                from: "Medium Daily Digest",
                fromEmail: "noreply@medium.com",
                timestamp: calendar.date(byAdding: .day, value: -1, to: now)!,
                hasAttachments: false,
                messageCount: 1,
                unsubscribeURL: URL(string: "https://medium.com/unsubscribe"),
                isKept: false
            ),
            EmailThread(
                id: "mock5",
                subject: "Your statement is ready",
                snippet: "Your January statement is now available. Log in to view your transactions and account summary...",
                from: "Chase",
                fromEmail: "no-reply@chase.com",
                timestamp: calendar.date(byAdding: .day, value: -1, to: now)!,
                hasAttachments: true,
                messageCount: 1,
                unsubscribeURL: nil,
                isKept: false
            ),
            EmailThread(
                id: "mock6",
                subject: "Invitation: Team sync @ Tue Jan 21",
                snippet: "Sam Bender has invited you to Team sync on Tuesday, January 21 at 10:00am...",
                from: "Google Calendar",
                fromEmail: "calendar-notification@google.com",
                timestamp: calendar.date(byAdding: .day, value: -1, to: now)!,
                hasAttachments: false,
                messageCount: 2,
                unsubscribeURL: nil,
                isKept: true
            ),
            EmailThread(
                id: "mock7",
                subject: "50% off everything this weekend",
                snippet: "Don't miss out on our biggest sale of the year. Use code SAVE50 at checkout...",
                from: "J.Crew",
                fromEmail: "promo@jcrew.com",
                timestamp: calendar.date(byAdding: .day, value: -2, to: now)!,
                hasAttachments: false,
                messageCount: 1,
                unsubscribeURL: URL(string: "https://jcrew.com/unsubscribe"),
                isKept: false
            ),
            EmailThread(
                id: "mock8",
                subject: "Re: Project proposal",
                snippet: "This looks great! I had a few thoughts on the timeline. Can we push the launch to Q2...",
                from: "Sarah Miller",
                fromEmail: "sarah.miller@company.com",
                timestamp: calendar.date(byAdding: .day, value: -2, to: now)!,
                hasAttachments: true,
                messageCount: 5,
                unsubscribeURL: nil,
                isKept: true
            )
        ]
    }
}
