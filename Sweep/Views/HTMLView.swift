//
//  HTMLView.swift
//  Sweep
//

import SwiftUI
import WebKit

struct HTMLView: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let wrapped = wrapHTML(html)
        webView.loadHTMLString(wrapped, baseURL: nil)
    }

    private func wrapHTML(_ content: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body {
                    font-family: -apple-system, system-ui;
                    font-size: 16px;
                    line-height: 1.5;
                    margin: 0;
                    padding: 0;
                    color: \(UIColor.label.hexString);
                    background: transparent;
                    word-wrap: break-word;
                }
                img { max-width: 100%; height: auto; }
                a { color: #007AFF; }
                pre, code { overflow-x: auto; white-space: pre-wrap; }
            </style>
        </head>
        <body>\(content)</body>
        </html>
        """
    }
}

extension UIColor {
    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
