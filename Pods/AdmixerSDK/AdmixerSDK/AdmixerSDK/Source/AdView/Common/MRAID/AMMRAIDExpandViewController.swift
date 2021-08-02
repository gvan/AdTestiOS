//
//  AMMRAIDExpandViewController.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import UIKit

private let kAMMRAIDExpandViewControllerCloseRegionWidth: CGFloat = 50.0
private let kAMMRAIDExpandViewControllerCloseRegionHeight: CGFloat = 50.0

class AMMRAIDExpandViewController: UIViewController {
    init(contentView: UIView?, expandProperties: AMMRAIDExpandProperties?) {
        super.init(nibName: nil, bundle: nil)
        
        self.contentView = contentView
        self.expandProperties = expandProperties
        orientationProperties = AMMRAIDOrientationProperties(
            allowOrientationChange: true,
            force: AMMRAIDOrientation.none
        )
    }

    func detachContentView() -> UIView? {
        let contentView = self.contentView
        if let constraints = contentView?.constraints {
            contentView?.removeConstraints(constraints)
        }
        contentView?.anRemoveSizeConstraintToSuperview()
        contentView?.anRemoveAlignmentConstraintsToSuperview()
        contentView?.removeFromSuperview()
        self.contentView = nil
        return contentView
    }

    weak var delegate: AMMRAIDExpandViewControllerDelegate?

    private var _orientationProperties: AMMRAIDOrientationProperties?
    var orientationProperties: AMMRAIDOrientationProperties? {
        get {
            _orientationProperties
        }
        set(orientationProperties) {
            _orientationProperties = orientationProperties
            if view.anIsViewable {
                let allowOrientationChange = orientationProperties?.allowOrientationChange ?? false
                if allowOrientationChange && orientationProperties?.forceOrientation == AMMRAIDOrientation.none {
                    UIViewController.attemptRotationToDeviceOrientation()
                } else {
                    delegate?.dismissAndPresentAgainForPreferredInterfaceOrientationChange()
                }
            }
        }
    }
    private var originalStatusBarHiddenState = false
    private var contentView: UIView?
    private var expandProperties: AMMRAIDExpandProperties?
    private weak var closeButton: UIButton?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.white
        createCloseButton()
        attachContentView()
    }

    func createCloseButton() {
        let closeButton = UIButton(type: .custom)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(
            self,
            action: #selector(closeButtonWasTapped),
            for: .touchUpInside)
        view.addSubview(closeButton)
        closeButton.anConstrain(with: CGSize(width: kAMMRAIDExpandViewControllerCloseRegionWidth, height: kAMMRAIDExpandViewControllerCloseRegionHeight))
        closeButton.anAlignToSuperviewApplyingSafeAreaLayoutGuide(withXAttribute: .right, yAttribute: .top, offsetX: 0, offsetY: 0)
        if !(expandProperties?.useCustomClose ?? false) {
            let closeboxImageName = "interstitial_flat_closebox"
            let closeboxImage = UIImage(contentsOfFile: AMPathForAMResource(closeboxImageName, "png") ?? "")
            closeButton.setImage(
                closeboxImage,
                for: .normal)
        }
        self.closeButton = closeButton
    }

    @objc func closeButtonWasTapped() {
        delegate?.closeButtonWasTapped(on: self)
    }

    func attachContentView() {
        contentView?.translatesAutoresizingMaskIntoConstraints = false
        if let constraints = contentView?.constraints {
            contentView?.removeConstraints(constraints)
        }
        contentView?.anRemoveSizeConstraintToSuperview()
        contentView?.anRemoveAlignmentConstraintsToSuperview()

        if let contentView = contentView, let closeButton = closeButton {
            view.insertSubview(
                contentView,
                belowSubview: closeButton)
        }
        if expandProperties?.width == -1 && expandProperties?.height == -1 {
            contentView?.anConstrainToSizeOfSuperview()
        } else {
            let orientedScreenBounds = AMAdjustAbsoluteRectInWindowCoordinatesForOrientationGivenRect(AMPortraitScreenBounds())
            var expandedWidth = expandProperties?.width ?? 0.0
            var expandedHeight = expandProperties?.height ?? 0.0

            if expandedWidth == -1 {
                expandedWidth = orientedScreenBounds.size.width
            }
            if expandedHeight == -1 {
                expandedHeight = orientedScreenBounds.size.height
            }
            contentView?.anConstrain(with: CGSize(width: expandedWidth, height: expandedHeight))
        }
        contentView?.anAlignToSuperviewApplyingSafeAreaLayoutGuide(withXAttribute: .left, yAttribute: .top, offsetX: 0, offsetY: 0)
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if orientationProperties?.allowOrientationChange ?? false {
            return .all
        } else {
            switch orientationProperties?.forceOrientation {
                case .portrait:
                    return .portrait
                case .landscape:
                    return .landscape
                default:
                    return .all
            }
        }
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        switch orientationProperties?.forceOrientation {
            case .portrait:
                if UIApplication.shared.statusBarOrientation == .portraitUpsideDown {
                    return .portraitUpsideDown
                }
                return .portrait
            case .landscape:
                if UIApplication.shared.statusBarOrientation == .landscapeRight {
                    return .landscapeRight
                }
                return .landscapeLeft
            default:
                let currentOrientation = UIApplication.shared.statusBarOrientation
                return currentOrientation
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !responds(to: #selector(UIViewController.setNeedsStatusBarAppearanceUpdate)) {
            originalStatusBarHiddenState = UIApplication.shared.isStatusBarHidden
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if orientationProperties?.allowOrientationChange ?? false {
            orientationProperties = AMMRAIDOrientationProperties(
                allowOrientationChange: true,
                force: AMMRAIDOrientation.none)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    // Allow WKWebView to present WKActionSheet
    override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        if presentedViewController != nil {
            presentedViewController?.present(
                viewControllerToPresent,
                animated: flag,
                completion: completion)
        } else {
            super.present(
                viewControllerToPresent,
                animated: flag,
                completion: completion)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}

protocol AMMRAIDExpandViewControllerDelegate: NSObjectProtocol {
    func closeButtonWasTapped(on controller: AMMRAIDExpandViewController?)
    func dismissAndPresentAgainForPreferredInterfaceOrientationChange()
}
