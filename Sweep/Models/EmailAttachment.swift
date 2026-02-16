//
//  EmailAttachment.swift
//  Sweep

import Foundation

struct EmailAttachment: Identifiable {
    let id: String
    let messageId: String
    let filename: String
    let mimeType: String
    let size: Int

    var displaySize: String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    var iconName: String {
        if mimeType.hasPrefix("image/") { return "photo" }
        if mimeType == "application/pdf" { return "doc.richtext" }
        if mimeType.contains("spreadsheet") || mimeType.contains("excel") { return "tablecells" }
        if mimeType.contains("presentation") || mimeType.contains("powerpoint") { return "rectangle.on.rectangle" }
        if mimeType.contains("word") || mimeType.contains("document") { return "doc.text" }
        if mimeType.contains("zip") || mimeType.contains("compressed") { return "archivebox" }
        return "paperclip"
    }
}
