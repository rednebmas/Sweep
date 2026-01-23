//
//  HTMLView.swift
//  Sweep
//

import SwiftUI
import WebKit
import UIKit

struct HTMLView: UIViewRepresentable {
    let html: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WebViewPool.shared.acquire()
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let wrapped = wrapHTML(html)
        webView.loadHTMLString(wrapped, baseURL: nil)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        WebViewPool.shared.release(webView)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var webView: WKWebView?

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
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
                    word-wrap: break-word;
                }
                img { max-width: 100%; height: auto; }
                a { color: #007AFF; }
                pre, code { overflow-x: auto; white-space: pre-wrap; }
                @media (prefers-color-scheme: dark) {
                    body {
                        background: #1c1c1e;
                        color: #ffffff;
                    }
                    a { color: #0a84ff; }
                }
            </style>
        </head>
        <body>\(content)</body>
        <script>
            (function() {
                const urlPattern = /(https?:\\/\\/[^\\s<>"']+)/g;
                function linkify(node) {
                    if (node.nodeType === Node.TEXT_NODE) {
                        const text = node.textContent;
                        if (text.match(urlPattern)) {
                            const span = document.createElement('span');
                            span.innerHTML = text.replace(urlPattern, '<a href="$1">$1</a>');
                            node.parentNode.replaceChild(span, node);
                        }
                    } else if (node.nodeType === Node.ELEMENT_NODE && node.tagName !== 'A' && node.tagName !== 'SCRIPT') {
                        Array.from(node.childNodes).forEach(linkify);
                    }
                }
                linkify(document.body);
            })();
        </script>
        </html>
        """
    }
}
