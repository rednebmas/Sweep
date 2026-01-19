//
//  OutlookAPITypes.swift
//  Sweep

import Foundation

struct OutlookMessageListResponse: Decodable {
    let value: [OutlookMessage]?
    let odataNextLink: String?

    enum CodingKeys: String, CodingKey {
        case value
        case odataNextLink = "@odata.nextLink"
    }
}

struct OutlookMessage: Decodable {
    let id: String
    let conversationId: String?
    let subject: String?
    let bodyPreview: String?
    let from: OutlookEmailAddress?
    let receivedDateTime: String?
    let hasAttachments: Bool?
    let isRead: Bool?

    var parsedDate: Date {
        guard let dateString = receivedDateTime else { return Date() }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString) ?? Date()
    }
}

struct OutlookEmailAddress: Decodable {
    let emailAddress: OutlookEmailInfo?
}

struct OutlookEmailInfo: Decodable {
    let name: String?
    let address: String?
}

struct OutlookMessageBody: Decodable {
    let body: OutlookBody?
}

struct OutlookBody: Decodable {
    let contentType: String?
    let content: String?
}

struct OutlookModifyRequest: Encodable {
    let isRead: Bool?

    init(isRead: Bool? = nil) {
        self.isRead = isRead
    }
}

struct OutlookMoveRequest: Encodable {
    let destinationId: String
}
