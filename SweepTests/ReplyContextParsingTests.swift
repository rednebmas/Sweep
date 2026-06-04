//
//  ReplyContextParsingTests.swift
//  SweepTests
//

import XCTest
@testable import Sweep

@MainActor
final class ReplyContextParsingTests: XCTestCase {

    private var gmail: GmailService!

    override func setUp() {
        gmail = GmailService(auth: AuthService())
    }

    func testMakeContext_parsesThreadingAndRecipients() {
        let message = makeMessage(headers: [
            ("From", "Alice <alice@x.com>"),
            ("To", "Me <me@x.com>, Bob <bob@x.com>"),
            ("Cc", "Carol <carol@x.com>"),
            ("Subject", "Hello"),
            ("Message-ID", "<orig@x.com>"),
            ("References", "<root@x.com>"),
            ("Date", "Mon, 17 Feb 2026 14:23:45 -0800")
        ])

        let context = gmail.makeReplyContext(
            from: message, threadId: "t1", selfEmail: "me@x.com", bodyText: "Original body")

        XCTAssertEqual(context.threadId, "t1")
        XCTAssertEqual(context.messageIdHeader, "<orig@x.com>")
        XCTAssertEqual(context.references, "<root@x.com>")
        XCTAssertEqual(context.subject, "Hello")
        XCTAssertEqual(context.from.email, "alice@x.com")
        XCTAssertEqual(context.to.map(\.email), ["me@x.com", "bob@x.com"])
        XCTAssertEqual(context.cc.map(\.email), ["carol@x.com"])
        XCTAssertEqual(context.selfEmail, "me@x.com")
        XCTAssertEqual(context.originalBodyText, "Original body")
    }

    func testMakeContext_missingHeadersAreNil() {
        let message = makeMessage(headers: [("From", "alice@x.com")])
        let context = gmail.makeReplyContext(
            from: message, threadId: "t1", selfEmail: nil, bodyText: "")

        XCTAssertNil(context.messageIdHeader)
        XCTAssertNil(context.references)
        XCTAssertTrue(context.to.isEmpty)
        XCTAssertTrue(context.cc.isEmpty)
    }

    private func makeMessage(headers: [(String, String)]) -> MessageFullResponse {
        let headerResponses = headers.map { HeaderResponse(name: $0.0, value: $0.1) }
        let payload = PayloadFullResponse(
            mimeType: "text/plain", filename: nil, headers: headerResponses, body: nil, parts: nil)
        return MessageFullResponse(id: "m1", snippet: nil, payload: payload)
    }
}
