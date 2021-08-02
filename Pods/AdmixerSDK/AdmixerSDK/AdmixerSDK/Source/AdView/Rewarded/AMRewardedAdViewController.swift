//
//  AMRewardedAdViewController.swift
//  AdmixerSDK
//
//  Created by Admixer on 10.03.2021.
//  Copyright © 2021 Admixer. All rights reserved.
//

import UIKit
import WebKit

class AMRewardedAdViewController: UIViewController {
    weak var delegate: AMRewardedAdViewControllerDelegate?

    private var _contentView: UIView?
    var contentView: UIView? {
        get {
            _contentView
        }
        set(contentView) {
            if contentView != _contentView {
                if (_contentView is WKWebView) {
                    let webView = _contentView as? WKWebView
                    webView?.stopLoading()
                    webView?.navigationDelegate = nil
                    webView?.uiDelegate = nil
                }

                _contentView?.removeFromSuperview()
                _contentView = contentView

                if let _contentView = _contentView {
                    view.insertSubview(_contentView, at: 0)
                }
                _contentView?.translatesAutoresizingMaskIntoConstraints = false

                if needCloseButton == false {
                    responsiveAd = true
                }

                if (_contentView is AMMRAIDContainerView) {
                    if (_contentView as? AMMRAIDContainerView)?.responsiveAd ?? false {
                        responsiveAd = true
                    }
                }

                if responsiveAd {
                    _contentView?.anConstrainToSizeOfSuperviewApplyingSafeAreaLayoutGuide()
                    _contentView?.anAlignToSuperviewApplyingSafeAreaLayoutGuide(withXAttribute: .left, yAttribute: .top, offsetX: 0, offsetY: 0)
                } else {
                    _contentView?.anConstrainWithFrameSize()
                    _contentView?.anAlignToSuperviewApplyingSafeAreaLayoutGuide(withXAttribute: .centerX, yAttribute: .centerY, offsetX: 0, offsetY: 0)
                }
            }
        }
    }

    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var progressLabel: UILabel!
    
    private var _backgroundColor: UIColor?
    var backgroundColor: UIColor? {
        get {
            _backgroundColor
        }
        set(backgroundColor) {
            _backgroundColor = backgroundColor
            view.backgroundColor = _backgroundColor
        }
    }
    private(set) var orientation: UIInterfaceOrientation!
    
    @IBOutlet weak var buttonTopToSuperviewConstraint: NSLayoutConstraint!
    
    private var _orientationProperties: AMMRAIDOrientationProperties?
    var orientationProperties: AMMRAIDOrientationProperties? {
        get {
            _orientationProperties
        }
        set {
            _orientationProperties = newValue
            if view.anIsViewable {
                if orientationProperties?.allowOrientationChange ?? false && orientationProperties?.forceOrientation == AMMRAIDOrientation.none {
                    UIViewController.attemptRotationToDeviceOrientation()
                } else if UIApplication.shared.statusBarOrientation != preferredInterfaceOrientationForPresentation {
                    delegate?.dismissAndPresentAgainForPreferredInterfaceOrientationChange()
                }
            }
        }
    }

    private var _useCustomClose = false
    var useCustomClose: Bool {
        get {
            _useCustomClose
        }
        set(useCustomClose) {
            if _useCustomClose != useCustomClose {
                _useCustomClose = useCustomClose
                setupCloseButtonImage(withCustomClose: useCustomClose)
            }
            if _useCustomClose {
                closeButton.isHidden = true
                closeButton.isUserInteractionEnabled = false
            }
            needCloseButton = !useCustomClose
        }
    }
    var needCloseButton = false
    var autoDismissAdDelay: TimeInterval = 0.0

    @IBAction func closeAction(_ sender: Any) {
        dismissAd()
    }
    

    func stopCountdownTimer() {
        progressLabel.isHidden = true
        progressTimer?.invalidate()

    }

    private var progressTimer: Timer?
    private var timerStartDate: Date?
    private var viewed = false
    private var originalHiddenState = false
    private var dismissing = false
    private var responsiveAd = false

    init() {
        let nibName = AMPathForAMResource("AMRewardedAdViewController", "nib") ?? ""
        if nibName.isEmpty {
            AMLogError("Could not instantiate interstitial controller because of missing NIB file")
        }
//        super.init(nibName: NSStringFromClass(AMRewardedAdViewController.self), bundle: AMResourcesBundle())
        super.init(nibName: "AMRewardedAdViewController", bundle: resourcesBundle)
        originalHiddenState = false
        orientation = UIApplication.shared.statusBarOrientation
        needCloseButton = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if backgroundColor == nil {
            backgroundColor = UIColor.white // Default white color, clear color background doesn't work with interstitial modal view
        }
        progressLabel.isHidden = true
        closeButton.isHidden = true
        closeButton.isUserInteractionEnabled = false
        if contentView != nil && contentView?.superview == nil {
            if let contentView = contentView {
                view.addSubview(contentView)
            }
            if let contentView = contentView {
                view.insertSubview(contentView, at: 0)
            }
            contentView?.anAlignToSuperview(
                withXAttribute: .centerX,
                yAttribute: .centerY)
        }
        if needCloseButton {
            setupCloseButtonImage(withCustomClose: useCustomClose)
        }
    }

    func setupCloseButtonImage(withCustomClose useCustomClose: Bool) {
        if useCustomClose {
            closeButton.setImage(
                nil,
                for: .normal)
            return
        }
        let closeboxImageName = "interstitial_flat_closebox"
        let closeboxImage = UIImage(contentsOfFile: AMPathForAMResource(closeboxImageName, "png") ?? "")
        closeButton.setImage(
            closeboxImage,
            for: .normal)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        originalHiddenState = UIApplication.shared.isStatusBarHidden

    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if needCloseButton {
            if !viewed && (((delegate?.closeDelayForController?() ?? 0.0) > 0.0) || (autoDismissAdDelay > -1)) {
                startCountdownTimer()
                viewed = true
            } else {
                closeButton.isHidden = false
                closeButton.isUserInteractionEnabled = true
                stopCountdownTimer()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if needCloseButton {
            progressTimer?.invalidate()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        dismissing = false
    }

    func startCountdownTimer() {
        progressLabel.isHidden = false
        closeButton.isHidden = true
        closeButton.isUserInteractionEnabled = false
        timerStartDate = Date()
        progressTimer = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(progressTimerDidFire(_:)), userInfo: nil, repeats: true)
    }

    @objc func progressTimerDidFire(_ timer: Timer?) {


        let timeNow = Date()
        var timeShown: TimeInterval? = nil
        if let timerStartDate = timerStartDate {
            timeShown = timeNow.timeIntervalSince(timerStartDate)
        }
        let closeButtonDelay = delegate?.closeDelayForController?() ?? 0.0
        if autoDismissAdDelay > -1 {
            progressLabel.text = String(Int(timeShown ?? 0.0))
            if (timeShown ?? 0.0) >= autoDismissAdDelay {
                dismissAd()
                stopCountdownTimer()
            }
            if (timeShown ?? 0.0) >= closeButtonDelay && closeButton.isHidden == true {
                closeButton.isHidden = false
                closeButton.isUserInteractionEnabled = true
            }
        } else {
            let timeRemains = closeButtonDelay - Double(timeShown ?? 0.0)
            progressLabel.text = String(Int(timeRemains + 1))
            if (timeShown ?? 0.0) >= closeButtonDelay && closeButton.isHidden == true {
                closeButton.isHidden = false
                closeButton.isUserInteractionEnabled = true
                stopCountdownTimer()
                delegate?.timerFinished()
            }
        }


    }

    func dismissAd() {
        dismissing = true
        delegate?.rewardedAdViewControllerShouldDismiss(self)
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        return .none
    }

    override var shouldAutorotate: Bool {
        return responsiveAd
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if orientationProperties != nil {
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

        if responsiveAd {
            return .all
        }

        switch orientation {
            case .landscapeLeft:
                return .landscapeLeft
            case .landscapeRight:
                return .landscapeRight
            case .portraitUpsideDown:
                return .portraitUpsideDown
            default:
                return .portrait
        }
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        if orientationProperties != nil {
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
                    break
            }
        }
        return orientation
    }

    override func viewWillLayoutSubviews() {
        let statusBarFrameSize = UIApplication.shared.statusBarFrame.size
        var buttonDistanceToSuperview = statusBarFrameSize.height
        
        if statusBarFrameSize.height > statusBarFrameSize.width {
            buttonDistanceToSuperview = statusBarFrameSize.width
        }

        buttonTopToSuperviewConstraint.constant = buttonDistanceToSuperview

        if !dismissing {
            guard let fr = contentView?.frame else { return }
            let normalizedContentViewFrame = CGRect(x: 0, y: 0, width: fr.width, height: fr.height)
            if !view.frame.contains(normalizedContentViewFrame) {
                let rotatedNormalizedContentViewFrame = CGRect(x: 0, y: 0, width: fr.height, height: fr.width)
                if view.frame.contains(rotatedNormalizedContentViewFrame) {
                    contentView?.anConstrain(with: CGSize(width: fr.height, height: fr.width))
                }
            }
        }
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

@objc protocol AMRewardedAdViewControllerDelegate: NSObjectProtocol {
    func rewardedAdViewControllerShouldDismiss(_ controller: AMRewardedAdViewController?)
    func dismissAndPresentAgainForPreferredInterfaceOrientationChange()
    func timerFinished()

    @objc optional func closeDelayForController() -> TimeInterval
}
