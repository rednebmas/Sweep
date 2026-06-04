//
//  ReplyMimeTests.swift
//  SweepTests
//

import XCTest
@testable import Sweep

final class ReplyMimeTests: XCTestCase {

    // MARK: - SubjectFormatter

    func testSubjectFormatter_addsRePrefix() {
        XCTAssertEqual(SubjectFormatter.reply("Hello"), "Re: Hello")
    }

    func testSubjectFormatter_keepsExistingRe() {
        XCTAssertEqual(SubjectFormatter.reply("Re: Hello"), "Re: Hello")
        XCTAssertEqual(SubjectFormatter.reply("RE: Hello"), "RE: Hello")
        XCTAssertEqual(SubjectFormatter.reply("re: Hello"), "re: Hello")
    }

    func testSubjectFormatter_stripsWrappingQuotes() {
        XCTAssertEqual(SubjectFormatter.reply("\"Hello\""), "Re: Hello")
    }

    // MARK: - ReplyRecipientResolver

    func testReply_sendsToSenderOnly() {
        let ctx = makeContext(
            from: participant("a@x.com"),
            to: [participant("b@x.com")],
            cc: [],
            selfEmail: "me@x.com"
        )
        let recipients = ReplyRecipientResolver.reply(ctx)
        XCTAssertEqual(recipients.to.map(\.email), ["a@x.com"])
        XCTAssertTrue(recipients.cc.isEmpty)
    }

    func testReplyAll_includesAllExceptSelf() {
        let ctx = makeContext(
            from: participant("a@x.com"),
            to: [participant("me@x.com"), participant("b@x.com")],
            cc: [participant("c@x.com")],
            selfEmail: "ME@X.com"
        )
        let recipients = ReplyRecipientResolver.replyAll(ctx)
        XCTAssertEqual(recipients.to.map(\.email), ["a@x.com", "b@x.com"])
        XCTAssertEqual(recipients.cc.map(\.email), ["c@x.com"])
    }

    func testReplyAll_dedupsToOverCc() {
        let ctx = makeContext(
            from: participant("a@x.com"),
            to: [participant("b@x.com")],
            cc: [participant("B@x.com")],
            selfEmail: nil
        )
        let recipients = ReplyRecipientResolver.replyAll(ctx)
        XCTAssertEqual(recipients.to.map(\.email), ["a@x.com", "b@x.com"])
        XCTAssertTrue(recipients.cc.isEmpty)
    }

    // MARK: - MIMEHeaderEncoder

    func testHeaderEncoder_asciiPassthrough() {
        XCTAssertEqual(MIMEHeaderEncoder.encode("Hello World"), "Hello World")
    }

    func testHeaderEncoder_encodesNonAscii() {
        let encoded = MIMEHeaderEncoder.encode("Café ☕️")
        XCTAssertTrue(encoded.hasPrefix("=?UTF-8?B?"))
        XCTAssertTrue(encoded.hasSuffix("?="))
    }

    // MARK: - Base64URL

    func testBase64URL_isURLSafeAndUnpadded() {
        let encoded = Base64URL.encode(Data([0xfb, 0xff]))
        XCTAssertFalse(encoded.contains("+"))
        XCTAssertFalse(encoded.contains("/"))
        XCTAssertFalse(encoded.contains("="))
    }

    // MARK: - EmailParticipant

    func testParse_nameAndEmail() {
        let participant = EmailParticipant.parse("John Doe <john@x.com>")
        XCTAssertEqual(participant?.name, "John Doe")
        XCTAssertEqual(participant?.email, "john@x.com")
    }

    func testParse_bareEmail() {
        let participant = EmailParticipant.parse("john@x.com")
        XCTAssertEqual(participant?.email, "john@x.com")
        XCTAssertEqual(participant?.displayName, "john@x.com")
    }

    func testParseList_quotedNameWithCommaNotSplit() {
        let list = EmailParticipant.parseList("\"Doe, John\" <john@x.com>, jane@x.com")
        XCTAssertEqual(list.count, 2)
        XCTAssertEqual(list[0].name, "Doe, John")
        XCTAssertEqual(list[0].email, "john@x.com")
        XCTAssertEqual(list[1].email, "jane@x.com")
    }

    // MARK: - MIMEMessageBuilder

    func testMimeBuilder_hasMultipartAndHeaders() {
        let message = String(decoding: MIMEMessageBuilder.build(sampleReply()), as: UTF8.self)
        XCTAssertTrue(message.contains("Content-Type: multipart/alternative"))
        XCTAssertTrue(message.contains("text/plain"))
        XCTAssertTrue(message.contains("text/html"))
        XCTAssertTrue(message.contains("In-Reply-To: <orig@x.com>"))
        XCTAssertTrue(message.contains("References: <root@x.com> <orig@x.com>"))
        XCTAssertTrue(message.contains("Subject: Re: Hi"))
        XCTAssertTrue(message.contains("My reply"))
    }

    // MARK: - Helpers

    private func participant(_ email: String) -> EmailParticipant {
        EmailParticipant(name: "", email: email)
    }

    private func makeContext(
        from: EmailParticipant,
        to: [EmailParticipant],
        cc: [EmailParticipant],
        selfEmail: String?
    ) -> ReplyContext {
        ReplyContext(
            threadId: "t",
            messageIdHeader: nil,
            references: nil,
            subject: "s",
            from: from,
            to: to,
            cc: cc,
            date: Date(),
            selfEmail: selfEmail,
            originalBodyText: ""
        )
    }

    private func sampleReply() -> OutgoingReply {
        OutgoingReply(
            threadId: "t",
            from: participant("me@x.com"),
            to: [participant("a@x.com")],
            cc: [],
            subject: "Re: Hi",
            inReplyTo: "<orig@x.com>",
            references: "<root@x.com> <orig@x.com>",
            bodyPlainText: "My reply",
            quotedOriginal: makeContext(from: participant("a@x.com"), to: [], cc: [], selfEmail: "me@x.com")
        )
    }
}
