//
//  WebViewPool.swift
//  Sweep
//

import WebKit
import UIKit

@MainActor
class WebViewPool {
    static let shared = WebViewPool()

    private var available: [WKWebView] = []
    private let poolSize = 2

    private init() {
        for _ in 0..<poolSize {
            available.append(createWebView())
        }
    }

    func warmUp() {
        for webView in available {
            webView.loadHTMLString("<html></html>", baseURL: nil)
        }
    }

    func acquire() -> WKWebView {
        if let webView = available.popLast() {
            return webView
        }
        return createWebView()
    }

    func release(_ webView: WKWebView) {
        webView.loadHTMLString("", baseURL: nil)
        if available.count < poolSize {
            available.append(webView)
        }
    }

    private func createWebView() -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        return webView
    }
}
