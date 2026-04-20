//
//  NewerSourceBadgeView.swift
//  Aidoku (iOS)
//
//  A compact badge view displayed in the top-right corner of manga cells
//  to indicate that another installed source has a newer chapter available.
//

import UIKit

class NewerSourceBadgeView: UIView {

    var isIndicatorVisible: Bool = false {
        didSet {
            guard isIndicatorVisible != oldValue else { return }
            updateVisibility()
        }
    }

    private let iconView: UIImageView = {
        let imageView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 10, weight: .bold)
        imageView.image = UIImage(systemName: "arrow.up.circle.fill", withConfiguration: config)
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let backgroundShape: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGreen
        view.layer.cornerRadius = 10
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
        constrain()
        updateVisibility()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: 20, height: 20)
    }

    private func configure() {
        isUserInteractionEnabled = false
        addSubview(backgroundShape)
        backgroundShape.addSubview(iconView)
    }

    private func constrain() {
        backgroundShape.translatesAutoresizingMaskIntoConstraints = false
        iconView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            backgroundShape.topAnchor.constraint(equalTo: topAnchor),
            backgroundShape.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundShape.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundShape.bottomAnchor.constraint(equalTo: bottomAnchor),
            backgroundShape.widthAnchor.constraint(equalToConstant: 20),
            backgroundShape.heightAnchor.constraint(equalToConstant: 20),

            iconView.centerXAnchor.constraint(equalTo: backgroundShape.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: backgroundShape.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 14),
            iconView.heightAnchor.constraint(equalToConstant: 14)
        ])
    }

    private func updateVisibility() {
        isHidden = !isIndicatorVisible
    }

    override func tintColorDidChange() {
        super.tintColorDidChange()
        if tintAdjustmentMode == .dimmed {
            backgroundShape.backgroundColor = .systemGreen.withAlphaComponent(0.5)
        } else {
            backgroundShape.backgroundColor = .systemGreen
        }
    }
}
