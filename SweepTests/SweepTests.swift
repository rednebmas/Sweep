//
//  SweepTests.swift
//  SweepTests
//
//  Created by Sam Bender on 1/10/26.
//

import XCTest
@testable import Sweep

@MainActor
final class SweepTests: XCTestCase {

    private var gmail: GmailService!

    override func setUp() {
        gmail = GmailService(auth: AuthService())
    }

    // MARK: - parseDateHeader

    func testParseDateHeader_standardFormat() {
        let date = gmail.parseDateHeader("Mon, 17 Feb 2026 14:23:45 -0800")
        XCTAssertNotEqual(date.timeIntervalSinceNow, 0, accuracy: 5,
                          "Should parse standard RFC 2822 date, not return current time")
    }

    func testParseDateHeader_withParenthesizedTimezone() {
        let date = gmail.parseDateHeader("Mon, 17 Feb 2026 14:23:45 -0800 (PST)")
        // This is the bug: the (PST) comment causes parsing to fail, returning Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents(in: TimeZone(secondsFromGMT: -28800)!, from: date)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 2)
        XCTAssertEqual(components.day, 17)
        XCTAssertEqual(components.hour, 14)
        XCTAssertEqual(components.minute, 23)
        XCTAssertEqual(components.second, 45)
    }

    func testParseDateHeader_withUTCComment() {
        let date = gmail.parseDateHeader("Tue, 18 Feb 2026 08:00:00 +0000 (UTC)")
        let components = calendar(utc: true).dateComponents(in: .gmt, from: date)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 2)
        XCTAssertEqual(components.day, 18)
        XCTAssertEqual(components.hour, 8)
    }

    func testParseDateHeader_withoutDayName() {
        let date = gmail.parseDateHeader("17 Feb 2026 14:23:45 -0800")
        let components = calendar(utc: false).dateComponents(
            in: TimeZone(secondsFromGMT: -28800)!, from: date)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.day, 17)
    }

    func testParseDateHeader_withoutDayNameAndWithComment() {
        let date = gmail.parseDateHeader("17 Feb 2026 14:23:45 -0800 (PST)")
        let components = calendar(utc: false).dateComponents(
            in: TimeZone(secondsFromGMT: -28800)!, from: date)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.day, 17)
    }

    func testParseDateHeader_nil() {
        let before = Date()
        let date = gmail.parseDateHeader(nil)
        let after = Date()
        XCTAssertGreaterThanOrEqual(date, before)
        XCTAssertLessThanOrEqual(date, after)
    }

    // MARK: - Helpers

    private func calendar(utc: Bool) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        if utc { cal.timeZone = .gmt }
        return cal
    }
}
