//
//  ContextMenuWrapper.swift
//  Sweep
//

import SwiftUI
import UIKit

struct ContextMenuWrapper<Content: View, Preview: View>: UIViewRepresentable {
    let content: Content
    let preview: () -> Preview
    let menu: () -> UIMenu
    let onPreviewTap: () -> Void

    func makeUIView(context: Context) -> ContextMenuContainerView<Content> {
        let container = ContextMenuContainerView(content: content)
        let interaction = UIContextMenuInteraction(delegate: context.coordinator)
        container.addInteraction(interaction)
        return container
    }

    func updateUIView(_ uiView: ContextMenuContainerView<Content>, context: Context) {
        uiView.updateContent(content)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(preview: preview, menu: menu, onPreviewTap: onPreviewTap)
    }

    class Coordinator: NSObject, UIContextMenuInteractionDelegate {
        let preview: () -> Preview
        let menu: () -> UIMenu
        let onPreviewTap: () -> Void

        init(preview: @escaping () -> Preview, menu: @escaping () -> UIMenu, onPreviewTap: @escaping () -> Void) {
            self.preview = preview
            self.menu = menu
            self.onPreviewTap = onPreviewTap
        }

        func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
            UIContextMenuConfiguration(
                identifier: nil,
                previewProvider: { [weak self] in
                    guard let self = self else { return nil }
                    let hostingController = UIHostingController(rootView: self.preview())
                    hostingController.preferredContentSize = CGSize(
                        width: UIScreen.main.bounds.width - 40,
                        height: UIScreen.main.bounds.height * 0.6
                    )
                    return hostingController
                },
                actionProvider: { [weak self] _ in
                    self?.menu()
                }
            )
        }

        func contextMenuInteraction(_ interaction: UIContextMenuInteraction, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
            animator.addCompletion { [weak self] in
                self?.onPreviewTap()
            }
        }
    }
}

class ContextMenuContainerView<Content: View>: UIView {
    private var hostingController: UIHostingController<Content>?

    init(content: Content) {
        super.init(frame: .zero)
        setupHostingController(content: content)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupHostingController(content: Content) {
        let host = UIHostingController(rootView: content)
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(host.view)

        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: topAnchor),
            host.view.bottomAnchor.constraint(equalTo: bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        hostingController = host
    }

    func updateContent(_ content: Content) {
        hostingController?.rootView = content
        invalidateIntrinsicContentSize()
    }

    override var intrinsicContentSize: CGSize {
        guard let hostingView = hostingController?.view else { return .zero }
        let width = bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width
        let size = hostingView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: UIView.noIntrinsicMetric, height: size.height)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        guard let hostingView = hostingController?.view else { return .zero }
        return hostingView.sizeThatFits(size)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        invalidateIntrinsicContentSize()
    }
}
