//
//  AMMRAIDResizeViewManager.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import UIKit

class AMMRAIDResizeViewManager: NSObject, AMMRAIDResizeViewDelegate {
    private(set) var resizeView: AMMRAIDResizeView?
    weak var delegate: AMMRAIDResizeViewManagerDelegate?
    private(set) var resized = false

    init?(contentView: UIView?, anchorView: UIView?) {
        if contentView == anchorView {
            AMLogError("%@ Anchor view cannot be the same as the content view", NSStringFromClass(AMMRAIDResizeViewManager.self))
            return nil
        }
        if contentView == nil || anchorView == nil {
            AMLogError("%@ Content view, anchor view, and root view have to be defined", NSStringFromClass(AMMRAIDResizeViewManager.self))
            return nil
        }

        super.init()
            self.contentView = contentView
            self.anchorView = anchorView
            resizeView = AMMRAIDResizeView()
            resizeView?.delegate = self
            resizeView?.translatesAutoresizingMaskIntoConstraints = false
    }

    func attemptResize(with properties: AMMRAIDResizeProperties?, errorString: inout String?) -> Bool {

        let allowResize = AMMRAIDResizeViewManager.validateMRAIDResize(
            from: anchorView,
            with: properties,
            errorString: &errorString)

        if allowResize {
            lastResizeProperties = properties
            resize(with: properties)
            resized = true
        }

        return allowResize
    }

    func detachResizeView() {
        if resized {
            resizeView?.removeFromSuperview()
            resized = false
            removeRootViewConstraints()
            resizeView = nil
            lastResizeProperties = nil
            unregisterFromDeviceOrientationNotification()
        }
    }

    func didMoveAnchorViewToWindow() {
        if resized {
            if anchorView?.window != nil {
                resize(with: lastResizeProperties)
            } else {
                resizeView?.removeFromSuperview()
                removeRootViewConstraints()
            }
        }
    }

    private var rootViewLeftConstraint: NSLayoutConstraint?
    private var rootViewTopConstraint: NSLayoutConstraint?
    private var lastResizeProperties: AMMRAIDResizeProperties?
    private weak var anchorView: UIView?
    private weak var contentView: UIView?

// MARK: - MRAID Resize Validation
    class func validateMRAIDResize(from view: UIView?, with properties: AMMRAIDResizeProperties?, errorString: inout String?) -> Bool {
        let screenBounds = UIScreen.main.bounds
        let rbX = (view?.bounds.origin.x ?? 0.0) + (properties?.offsetX ?? 0.0)
        let rbY = (view?.bounds.origin.y ?? 0.0) + (properties?.offsetY ?? 0.0)
        let rbW = properties?.width ?? 0.0
        let rbH = properties?.height ?? 0.0
        let resizedBounds = CGRect(x: rbX, y: rbY, width: rbW, height: rbH)

        let resizedBoundsInWindowCoordinates = view?.convert(resizedBounds, to: nil) ?? .zero
        let resizedIntersection = screenBounds.intersection(resizedBoundsInWindowCoordinates)

        if resizedIntersection.size.width < kAMResizeViewCloseRegionWidth || resizedIntersection.size.height < kAMResizeViewCloseRegionHeight {
            errorString = String(format: "Resize call should keep at least %fx%f of the creative on screen", kAMResizeViewCloseRegionWidth, kAMResizeViewCloseRegionHeight)
            return false
        } else if resizedIntersection.size.width > screenBounds.size.width && resizedIntersection.size.height > screenBounds.size.height {
            errorString = "Resize called with resizeProperties larger than the screen."
            return false
        }

        return true
    }

// MARK: - AMResizeViewManager Implementation

    func resize(with properties: AMMRAIDResizeProperties?) {
        resizeView?.closePosition = properties?.customClosePosition
        resizeView?.anConstrain(with: CGSize(width: properties?.width ?? 0.0, height: properties?.height ?? 0.0))

        if resizeView?.superview == nil {
            if let resizeView = resizeView {
                anchorView?.window?.addSubview(resizeView)
            }
        }

        if resizeView?.contentView == nil {
            resizeView?.attachContentView(contentView)
        }

        if #available(iOS 12.0, *) {
//        if UIScreen.main.responds(to: #selector(UIFocusItemContainer.coordinateSpace)) {
            if rootViewLeftConstraint != nil {
                rootViewLeftConstraint?.constant = properties?.offsetX ?? 0.0
            } else {
                if let resizeView = resizeView {
                    rootViewLeftConstraint = NSLayoutConstraint(
                        item: resizeView,
                        attribute: .left,
                        relatedBy: .equal,
                        toItem: anchorView,
                        attribute: .left,
                        multiplier: 1.0,
                        constant: properties?.offsetX ?? 0.0)
                }
                if let rootViewLeftConstraint = rootViewLeftConstraint {
                    anchorView?.window?.addConstraint(rootViewLeftConstraint)
                }
            }

            if rootViewTopConstraint != nil {
                rootViewTopConstraint?.constant = properties?.offsetY ?? 0.0
            } else {
                if let resizeView = resizeView {
                    rootViewTopConstraint = NSLayoutConstraint(
                        item: resizeView,
                        attribute: .top,
                        relatedBy: .equal,
                        toItem: anchorView,
                        attribute: .top,
                        multiplier: 1.0,
                        constant: properties?.offsetY ?? 0.0)
                }
                if let rootViewTopConstraint = rootViewTopConstraint {
                    anchorView?.window?.addConstraint(rootViewTopConstraint)
                }
            }
        } else {
            var boundsToResizeTo = anchorView?.bounds
            boundsToResizeTo?.origin.x += properties?.offsetX ?? 0.0
            boundsToResizeTo?.origin.y += properties?.offsetY ?? 0.0
            boundsToResizeTo?.size = CGSize(width: properties?.width ?? 0.0, height: properties?.height ?? 0.0)
            let frameToResizeToInWindowCoordinates = anchorView?.convert(
                boundsToResizeTo ?? CGRect.zero,
                to: nil)
            resizeView?.frame = frameToResizeToInWindowCoordinates ?? CGRect.zero
            resizeView?.transform = transformForOrientation()

            setupRotationListener()
        }
    }

    func removeRootViewConstraints() {
        if let rootViewLeftConstraint = rootViewLeftConstraint {
            anchorView?.window?.removeConstraint(rootViewLeftConstraint)
        }
        if let rootViewTopConstraint = rootViewTopConstraint {
            anchorView?.window?.removeConstraint(rootViewTopConstraint)
        }
        rootViewLeftConstraint = nil
        rootViewTopConstraint = nil
    }

// MARK: - Pre-iOS 8 resize
    func transformForOrientation() -> CGAffineTransform {
        var radians: CGFloat = 0
        let pi = CGFloat(Double.pi)
        let pi2 = pi / 2
        switch UIApplication.shared.statusBarOrientation {
            case .landscapeLeft:
                radians = -pi2
            case .landscapeRight:
                radians = pi2
            case .portraitUpsideDown:
                radians = pi
            default:
                radians = 0.0
        }

        let rotationTransform = CGAffineTransform(rotationAngle: radians)
        return rotationTransform
    }

    func setupRotationListener() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDeviceOrientationDidChange(_:)),
            name: UIDevice.orientationDidChangeNotification,
            object: nil)
    }

    @objc func handleDeviceOrientationDidChange(_ notification: Notification?) {
        resize(with: lastResizeProperties)
    }

    func unregisterFromDeviceOrientationNotification() {
        NotificationCenter.default.removeObserver(
            self,
            name: UIDevice.orientationDidChangeNotification,
            object: nil)
    }

// MARK: - AMResizeViewManagerDelegate
    func closeRegionSelected(on resizeView: AMMRAIDResizeView?) {
        detachResizeView()
        delegate?.resizeViewClosed(by: self)
    }

    deinit {
        detachResizeView()
    }
}

protocol AMMRAIDResizeViewManagerDelegate: NSObjectProtocol {
    func resizeViewClosed(by manager: AMMRAIDResizeViewManager?)
}
