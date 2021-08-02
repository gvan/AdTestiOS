//
//  AMMRAIDResizeView.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import UIKit

let kAMResizeViewCloseRegionWidth: CGFloat = 50.0
let kAMResizeViewCloseRegionHeight: CGFloat = 50.0

class AMMRAIDResizeView: UIView {
    func attachContentView(_ contentView: UIView?) {
        if contentView != self.contentView {
            if self.contentView != nil {
                AMLogError("Error: Attempt to attach a second content view to a resize view.")
                return
            }
            self.contentView = contentView
            self.contentView?.removeFromSuperview()
            if let contentView = self.contentView, let closeRegion = closeRegion {
                insertSubview(
                    contentView,
                    belowSubview: closeRegion)
            }
            setupContentViewConstraints()
        }
    }

    func detachContentView() -> UIView? {
        let contentView = self.contentView
        self.contentView = nil
        if contentView?.superview == self {
            contentView?.removeFromSuperview()
            if let constraints = contentView?.constraints {
                contentView?.removeConstraints(constraints)
            }
            return contentView
        }
        if contentView != nil {
            AMLogError("Error: Attempted to detach a content view from a resize view which has already been added to another hierarchy")
        }
        return nil
    }

    private(set) weak var contentView: UIView?

    private var _closePosition: AMMRAIDCustomClosePosition!
    var closePosition: AMMRAIDCustomClosePosition! {
        get {
            _closePosition
        }
        set(closePosition) {
            _closePosition = closePosition
            if let _closePosition = _closePosition {
                setupCloseRegionConstraints(with: _closePosition)
            }
        }
    }
    weak var delegate: AMMRAIDResizeViewDelegate?
    private var closeRegion: UIButton?
    private var supplementaryCloseRegion: UIButton?

    private var _closeRegionDefaultImage: UIImage?
    private var closeRegionDefaultImage: UIImage? {
        if _closeRegionDefaultImage == nil {
            let atLeastiOS7 = responds(to: #selector(UIView.tintColorDidChange))
            var closeboxImageName = "interstitial_flat_closebox"
            if !atLeastiOS7 {
                closeboxImageName = "interstitial_closebox"
            }
            _closeRegionDefaultImage = UIImage(contentsOfFile: AMPathForAMResource(closeboxImageName, "png") ?? "")
        }
        return _closeRegionDefaultImage
    }

// MARK: - AMResizeView Implementation
    init() {
        super.init(frame: CGRect.zero)
        backgroundColor = UIColor.clear
        setupCloseRegion()
        setupSupplementaryCloseRegion()
    }

// MARK: - Close Region

    func setupCloseRegion() {
        let closeButton = UIButton(type: .custom)
        closeButton.addTarget(
            self,
            action: #selector(closeRegionSelectedOnResizeView),
            for: .touchUpInside)
        closeRegion = closeButton
        if let closeRegion = closeRegion {
            addSubview(closeRegion)
        }
    }

    func setupSupplementaryCloseRegion() {
        let closeButton = UIButton(type: .custom)
        closeButton.addTarget(
            self,
            action: #selector(closeRegionSelectedOnResizeView),
            for: .touchUpInside)
        closeButton.setImage(
            closeRegionDefaultImage,
            for: .normal)
        closeButton.isHidden = true
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.anConstrain(with: CGSize(width: kAMResizeViewCloseRegionWidth, height: kAMResizeViewCloseRegionHeight))
        supplementaryCloseRegion = closeButton
        if let supplementaryCloseRegion = supplementaryCloseRegion {
            addSubview(supplementaryCloseRegion)
        }
    }

    func setupCloseRegionConstraints(with position: AMMRAIDCustomClosePosition) {
        if let constraints = closeRegion?.constraints {
            closeRegion?.removeConstraints(constraints)
        }
        closeRegion?.translatesAutoresizingMaskIntoConstraints = false
        var xAttribute: NSLayoutConstraint.Attribute
        var yAttribute: NSLayoutConstraint.Attribute

        switch position {
            case .topLeft:
                yAttribute = .top
                xAttribute = .left
            case .topCenter:
                yAttribute = .top
                xAttribute = .centerX
            case .topRight:
                yAttribute = .top
                xAttribute = .right
            case .center:
                yAttribute = .centerY
                xAttribute = .centerX
            case .bottomLeft:
                yAttribute = .bottom
                xAttribute = .left
            case .bottomCenter:
                yAttribute = .bottom
                xAttribute = .centerX
            case .bottomRight:
                yAttribute = .bottom
                xAttribute = .right
            default:
                AMLogDebug("Invalid custom close position for MRAID resize event")
                yAttribute = .top
                xAttribute = .right
        }

        closeRegion?.anConstrain(with: CGSize(width: kAMResizeViewCloseRegionWidth, height: kAMResizeViewCloseRegionHeight))
        closeRegion?.anAlignToSuperview(
            withXAttribute: xAttribute,
            yAttribute: yAttribute)
    }

// MARK: - Content View

    func setupContentViewConstraints() {
        if let constraints = contentView?.constraints {
            contentView?.removeConstraints(constraints)
        }
        contentView?.translatesAutoresizingMaskIntoConstraints = false
        contentView?.anConstrainToSizeOfSuperview()
        contentView?.anAlignToSuperview(
            withXAttribute: .left,
            yAttribute: .top)
    }

// MARK: - AMResizeViewDelegate
    @objc func closeRegionSelectedOnResizeView() {
        delegate?.closeRegionSelected(on: self)
    }

// MARK: - Layout
    override class var requiresConstraintBasedLayout: Bool {
        return true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        enableSupplementaryCloseRegionIfNecessary()
    }

    func enableSupplementaryCloseRegionIfNecessary() {
        let screenBounds = UIScreen.main.bounds
        let closeRegionBounds = self.closeRegion?.bounds ?? .zero
        let closeRegionBoundsInWindowCoordinates = closeRegion?.convert(closeRegionBounds, to: nil) ?? CGRect(x: -100, y: -100, width: 0, height: 0)
        if screenBounds.contains(closeRegionBoundsInWindowCoordinates) {
            supplementaryCloseRegion?.isHidden = true
        } else {
            supplementaryCloseRegion?.isHidden = false

            let selfBoundsInWindowCoordinates = convert(
                bounds,
                to: nil)
            let intersection = screenBounds.intersection(selfBoundsInWindowCoordinates)
            let intersectionFrameInCloseRegionCoordinates = convert(
                intersection,
                from: nil)
            let updatedCloseRegionOriginX = intersectionFrameInCloseRegionCoordinates.origin.x + intersectionFrameInCloseRegionCoordinates.size.width - (supplementaryCloseRegion?.frame.size.width ?? 0.0)
            let updatedCloseRegionOriginY = intersectionFrameInCloseRegionCoordinates.origin.y

            let updatedCloseRegionFrame = CGRect(x: updatedCloseRegionOriginX, y: updatedCloseRegionOriginY, width: supplementaryCloseRegion?.frame.size.width ?? 0.0, height: supplementaryCloseRegion?.frame.size.height ?? 0.0)

            supplementaryCloseRegion?.frame = updatedCloseRegionFrame
        }
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}

protocol AMMRAIDResizeViewDelegate: NSObjectProtocol {
    func closeRegionSelected(on resizeView: AMMRAIDResizeView?)
}
