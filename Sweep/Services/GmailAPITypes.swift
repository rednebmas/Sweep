//
//  GmailAPITypes.swift
//  Sweep
//

import Foundation

// MARK: - API Response Types

struct ThreadListResponse: Codable {
    let threads: [ThreadRef]?
    let nextPageToken: String?
}

struct ThreadRef: Codable {
    let id: String
    let historyId: String?
}

struct ThreadDetailResponse: Codable {
    let id: String
    let snippet: String?
    let messages: [MessageResponse]?
}

struct MessageResponse: Codable {
    let id: String
    let snippet: String?
    let payload: PayloadResponse?
}

struct PayloadResponse: Codable {
    let headers: [HeaderResponse]?
}

struct HeaderResponse: Codable {
    let name: String
    let value: String
}

struct ModifyRequest: Codable {
    let addLabelIds: [String]
    let removeLabelIds: [String]
}

struct EmptyResponse: Codable {}

struct CreateFilterRequest: Codable {
    let criteria: FilterCriteria
    let action: FilterAction
}

struct FilterCriteria: Codable {
    let from: String
}

struct FilterAction: Codable {
    let removeLabelIds: [String]
    let addLabelIds: [String]
}

struct FilterResponse: Codable {
    let id: String?
}

struct ThreadFullResponse: Codable {
    let id: String
    let messages: [MessageFullResponse]?
}

struct MessageFullResponse: Codable {
    let id: String
    let payload: PayloadFullResponse?
}

struct PayloadFullResponse: Codable {
    let mimeType: String?
    let headers: [HeaderResponse]?
    let body: BodyResponse?
    let parts: [PayloadFullResponse]?
}

struct BodyResponse: Codable {
    let data: String?
    let attachmentId: String?
}

struct AttachmentResponse: Codable {
    let data: String
}


// MARK: - Label Types

struct LabelListResponse: Codable {
    let labels: [GmailLabel]?
}

struct GmailLabel: Codable {
    let id: String
    let name: String
}

struct CreateLabelRequest: Codable {
    let name: String
    let labelListVisibility: String
    let messageListVisibility: String
}

