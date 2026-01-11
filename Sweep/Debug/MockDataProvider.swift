//
//  MockDataProvider.swift
//  Sweep
//
//  DEBUG ONLY - Set useMockData = true to test without Gmail API.
//

#if DEBUG
import Foundation

enum MockDataProvider {
    static var useMockData = false

    static var mockThreads: [EmailThread] {
        [
            EmailThread(
                id: "mock_1",
                subject: "Your Amazon order has shipped!",
                snippet: "Your package with Echo Dot (5th Gen) is on its way. Track your package...",
                from: "Amazon.com",
                fromEmail: "ship-confirm@amazon.com",
                timestamp: Date().addingTimeInterval(-1800),
                hasAttachments: false,
                messageCount: 1
            ),
            EmailThread(
                id: "mock_2",
                subject: "Re: Q4 Planning Meeting",
                snippet: "Sounds good, let's sync up tomorrow at 2pm. I'll send a calendar invite...",
                from: "Jennifer Martinez",
                fromEmail: "j.martinez@techcorp.com",
                timestamp: Date().addingTimeInterval(-3600),
                hasAttachments: false,
                messageCount: 4
            ),
            EmailThread(
                id: "mock_3",
                subject: "Your Uber receipt for Tuesday",
                snippet: "Thanks for riding with Uber. Your trip cost $24.50. View your receipt...",
                from: "Uber Receipts",
                fromEmail: "noreply@uber.com",
                timestamp: Date().addingTimeInterval(-7200),
                hasAttachments: true,
                messageCount: 1
            ),
            EmailThread(
                id: "mock_4",
                subject: "[GitHub] Your pull request was merged",
                snippet: "PR #847: Fix memory leak in image loader has been merged into main...",
                from: "GitHub",
                fromEmail: "notifications@github.com",
                timestamp: Date().addingTimeInterval(-10800),
                hasAttachments: false,
                messageCount: 1
            ),
            EmailThread(
                id: "mock_5",
                subject: "Fwd: Hawaii trip photos",
                snippet: "Hey! Here are the photos from our trip. The sunset ones came out great...",
                from: "Mike Chen",
                fromEmail: "mike.chen@gmail.com",
                timestamp: Date().addingTimeInterval(-14400),
                hasAttachments: true,
                messageCount: 2
            ),
            EmailThread(
                id: "mock_6",
                subject: "Your flight to NYC is tomorrow",
                snippet: "Reminder: Your United flight UA 847 departs SFO at 7:45 AM...",
                from: "United Airlines",
                fromEmail: "united@united.com",
                timestamp: Date().addingTimeInterval(-28800),
                hasAttachments: false,
                messageCount: 1
            ),
        ]
    }

    static func mockEmailBody(for threadId: String) -> String {
        switch threadId {
        case "mock_1":
            return """
            <div style="font-family: Arial, sans-serif;">
            <h2>Your package is on its way!</h2>
            <p>Great news! Your order containing <strong>Echo Dot (5th Gen)</strong> has shipped.</p>
            <p><strong>Estimated delivery:</strong> Tuesday, January 14</p>
            <p><strong>Shipping address:</strong><br>123 Main Street<br>San Francisco, CA 94102</p>
            </div>
            """
        case "mock_2":
            return """
            <div>
            <p>Sounds good, let's sync up tomorrow at 2pm. I'll send a calendar invite shortly.</p>
            <p>Can you bring the updated projections? I want to review before the exec meeting.</p>
            <p>Thanks,<br>Jennifer</p>
            <hr>
            <p><em>On Jan 10, 2026, David wrote:</em></p>
            <blockquote>Should we push the planning meeting to next week?</blockquote>
            </div>
            """
        default:
            return """
            <div style="font-family: -apple-system, sans-serif; padding: 16px;">
            <p>This is a mock email body for testing.</p>
            <p>Thread ID: \(threadId)</p>
            </div>
            """
        }
    }
}
#endif
