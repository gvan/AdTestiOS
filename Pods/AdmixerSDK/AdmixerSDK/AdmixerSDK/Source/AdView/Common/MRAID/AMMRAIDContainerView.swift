//
//  AMMRAIDContainerView.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import UIKit
//#import "AMOMIDImplementation.h"

private let kAMOMIDSessionFinishDelay: CGFloat = 0.08
struct AMMRAIDContainerViewAdInteraction : OptionSet {
    let rawValue: Int

    static let expandedOrResized = AMMRAIDContainerViewAdInteraction(rawValue: 1 << 0)
    static let video = AMMRAIDContainerViewAdInteraction(rawValue: 1 << 1)
    static let browser = AMMRAIDContainerViewAdInteraction(rawValue: 1 << 2)
    static let calendar = AMMRAIDContainerViewAdInteraction(rawValue: 1 << 3)
    static let picture = AMMRAIDContainerViewAdInteraction(rawValue: 1 << 4)
}

class AMMRAIDContainerView: UIView, AMBrowserViewControllerDelegate, AMAdWebViewControllerAMJAMDelegate, AMAdWebViewControllerBrowserDelegate, AMAdWebViewControllerLoadingDelegate, AMAdWebViewControllerMRAIDDelegate, AMAdWebViewControllerVideoDelegate, AMMRAIDCalendarManagerDelegate, AMMRAIDExpandViewControllerDelegate, AMMRAIDResizeViewManagerDelegate {

    convenience init(size: CGSize, html: String?, webViewBaseURL baseURL: URL?) {
        self.init(size: size)
        self.baseURL = baseURL

        webViewController = AMAdWebViewController(
            size: lastKnownCurrentPosition.size,
            html: html,
            webViewBaseURL: baseURL)

        webViewController?.anjamDelegate = self
        webViewController?.browserDelegate = self
        webViewController?.loadingDelegate = self
        webViewController?.mraidDelegate = self
    }

    convenience init(size: CGSize, videoXML: String?, skipOffset: Int?) {
        self.init(size: size)

        webViewController = AMAdWebViewController(
            size: lastKnownCurrentPosition.size,
            videoXML: videoXML)

        self.skipOffset = skipOffset
        webViewController?.anjamDelegate = self
        webViewController?.browserDelegate = self
        webViewController?.loadingDelegate = self
        webViewController?.mraidDelegate = self

        webViewController?.videoDelegate = self
        isBannerVideo = true
    }

    private(set) var size = CGSize.zero
    private(set) var responsiveAd = false
    private(set) var isBannerVideo = false
    private(set) var skipOffset: Int? = -1
    private(set) var webViewController: AMAdWebViewController?
    weak var loadingDelegate: AMAdWebViewControllerLoadingDelegate?

    private weak var _adViewDelegate: AMAdViewInternalDelegate?
    weak var adViewDelegate: AMAdViewInternalDelegate? {
        get {
            _adViewDelegate
        }
        set(adViewDelegate) {
            _adViewDelegate = adViewDelegate
            webViewController?.adViewDelegate = adViewDelegate
            webViewController?.adViewAMJAMDelegate = adViewDelegate
            expandWebViewController?.adViewDelegate = adViewDelegate
            expandWebViewController?.adViewAMJAMDelegate = adViewDelegate

            if let interstitialDelegate = adViewDelegate as? AMInterstitialAdViewInternalDelegate {
                interstitialDelegate.adShouldSetOrientationProperties(orientationProperties)
                interstitialDelegate.adShouldUseCustomClose(useCustomClose)

                if useCustomClose {
                    addSupplementaryCustomCloseRegion()
                }
            } else
            if let rewardedDelegate = adViewDelegate as? AMRewardedAdViewInternalDelegate {
                rewardedDelegate.adShouldSetOrientationProperties(orientationProperties)
                rewardedDelegate.adShouldUseCustomClose(useCustomClose)
                
                if useCustomClose {
                    addSupplementaryCustomCloseRegion()
                }
            }
        }
    }
    var embeddedInModalView = false
    var shouldDismissOnClick = false
    private var baseURL: URL?
    private var browserViewController: AMBrowserViewController?
    private var calendarManager: AMMRAIDCalendarManager?
    private var expandController: AMMRAIDExpandViewController?
    private var orientationProperties: AMMRAIDOrientationProperties?
    private var resizeManager: AMMRAIDResizeViewManager?
    private var vastVideofullScreenController: AMInterstitialAdViewController?
    private var useCustomClose = false
    private var customCloseRegion: UIButton?
    private var clickOverlay: AMClickOverlayView?

    private var _adInteractionInProgress = false
    private var adInteractionInProgress: Bool {
        get {
            _adInteractionInProgress
        }
        set(adInteractionInProgress) {
            let oldValue = _adInteractionInProgress
            _adInteractionInProgress = adInteractionInProgress
            let newValue = _adInteractionInProgress
            if oldValue != newValue {
                if _adInteractionInProgress {
                    adViewDelegate?.adInteractionDidBegin()
                } else {
                    adViewDelegate?.adInteractionDidEnd()
                }
            }
        }
    }
    private var adInteractionValue = 0

    private var expanded: Bool {
        return expandController?.presentingViewController != nil ? true : false
    }

    private var resized: Bool {
        return resizeManager?.resized ?? false
    }
    private var isFullscreen = false
    private var lastKnownDefaultPosition = CGRect.zero
    private var lastKnownCurrentPosition = CGRect.zero
    private var expandWebViewController: AMAdWebViewController?
    private var userInteractedWithContentView = false

// MARK: - Lifecycle.
    init(size: CGSize) {
        var initialSize = size
        var responsiveAd = false

        if initialSize.equalTo(CGSize(width: 1, height: 1)) {
            responsiveAd = true
            initialSize = AMPortraitScreenBounds().size
        }

        let initialRect = CGRect(x: 0, y: 0, width: initialSize.width, height: initialSize.height)

        super.init(frame: initialRect)

        //
        self.size = size
        self.responsiveAd = responsiveAd

        lastKnownCurrentPosition = initialRect
        lastKnownDefaultPosition = initialRect

        isBannerVideo = false

        backgroundColor = UIColor.clear

        isFullscreen = false
    }

    override func willMove(toSuperview newSuperview: UIView?) {

        if newSuperview == nil {
            //        if(self.webViewController.omidAdSession){
            //            [[AMOMIDImplementation sharedInstance] stopOMIDAdSession:self.webViewController.omidAdSession];
            //            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (kAMOMIDSessionFinishDelay * NSEC_PER_SEC));
            //            dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
            //                [super willMoveToSuperview:newSuperview];
            //            });
            //        }
            webViewController = nil
        } else {
            super.willMove(toSuperview: newSuperview)
        }
    }

// MARK: - Getters/setters.

// MARK: - Helper methods.
    func displayController() -> UIViewController? {

        var presentingVC: UIViewController? = nil

        if expanded {
            presentingVC = expandController
        } else if isFullscreen {
            presentingVC = vastVideofullScreenController
        } else {
            presentingVC = adViewDelegate?.displayController()
        }

        if AMCanPresentFromViewController(presentingVC) {
            return presentingVC
        }
        return nil
    }

    func adInteractionBegan(with interaction: AMMRAIDContainerViewAdInteraction) {
        adInteractionValue = adInteractionValue | interaction.rawValue
        adInteractionInProgress = adInteractionValue != 0
    }

    func adInteractionEnded(for interaction: AMMRAIDContainerViewAdInteraction) {
        adInteractionValue = adInteractionValue & ~interaction.rawValue
        adInteractionInProgress = adInteractionValue != 0
    }

// MARK: - User Interaction Testing
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let viewThatWasHit = super.hitTest(point, with: event)
        if let contentView1 = webViewController?.contentView {
            if !userInteractedWithContentView && viewThatWasHit?.isDescendant(of: contentView1) ?? false {
                AMLogDebug("Detected user interaction with ad")
                userInteractedWithContentView = true
            }
        }
        return viewThatWasHit
    }

// MARK: - AMBrowserViewControllerDelegate
    func rootViewController(forDisplaying controller: AMBrowserViewController?) -> UIViewController? {
        return displayController()
    }

    @objc func browserViewController(_ controller: AMBrowserViewController?, browserIsLoading isLoading: Bool) {
        if adViewDelegate?.landingPageLoadsInBackground ?? false {
            if !(controller?.completedInitialLoad ?? false) {
                isLoading ? showClickOverlay() : hideClickOverlay()
            } else {
                hideClickOverlay()
            }
        }
    }

    @objc func browserViewController(_ controller: AMBrowserViewController?, couldNotHandleInitialURL url: URL?) {
        adInteractionEnded(for: .browser)
    }

    func handleBrowserLoadingForMRAIDStateChange() {
        browserViewController?.stopLoading()
        adInteractionEnded(for: .browser)
    }

    @objc func willPresent(_ controller: AMBrowserViewController?) {
        if !embeddedInModalView && !expanded {
            adViewDelegate?.adWillPresent()
        }
        resizeManager?.resizeView?.isHidden = true
        adInteractionBegan(with: .browser)
    }

    @objc func didPresent(_ controller: AMBrowserViewController?) {
        if !embeddedInModalView && !expanded {
            adViewDelegate?.adDidPresent()
        }
    }

    @objc func willDismiss(_ controller: AMBrowserViewController?) {
        if !embeddedInModalView && !expanded {
            adViewDelegate?.adWillClose()
        }

        if shouldDismissOnClick {
            controller?.dismiss(animated: false)
        }

        resizeManager?.resizeView?.isHidden = false
    }

    @objc func didDismiss(_ controller: AMBrowserViewController?) {
        browserViewController = nil

        if !embeddedInModalView && !expanded {
            adViewDelegate?.adDidClose()
        }

        hideClickOverlay()
        adInteractionEnded(for: .browser)
    }

    @objc func willLeaveApplication(from controller: AMBrowserViewController?) {
        adViewDelegate?.adWillLeaveApplication()
    }

// MARK: - Click overlay
    func showClickOverlay() {
        if clickOverlay?.superview == nil {
            clickOverlay = AMClickOverlayView.addOverlay(to: viewToDisplayClickOverlay())
            clickOverlay?.alpha = 0.0
        }

        if !transform.isIdentity {
            // In the case that AMMRAIDContainerView is magnified it is necessary to invert this magnification for the click overlay
            clickOverlay?.transform = transform.inverted()
        }

        clickOverlay?.isHidden = false

        UIView.animate(
            withDuration: 0.5,
            animations: {
                self.clickOverlay?.alpha = 1.0
            })
    }

    func viewToDisplayClickOverlay() -> UIView? {
        if expanded {
            return expandController?.view
        } else if isFullscreen {
            return vastVideofullScreenController?.view
        } else if resized {
            return resizeManager?.resizeView
        } else {
            return self
        }
    }

    func hideClickOverlay() {
        if clickOverlay?.superview != nil {
            UIView.animate(
                withDuration: 0.5,
                animations: {
                    self.clickOverlay?.alpha = 0.0
                }) { finished in
                    self.clickOverlay?.isHidden = true
                }
        }
    }

// MARK: - AMWebViewControllerAMJAMDelegate
    func handleAMJAMURL(_ URL: URL?) {
        AMJAMImplementation.handle(URL, with: webViewController)
    }

// MARK: - AMWebViewControllerBrowserDelegate
    func openDefaultBrowser(with URL: URL?) {
        if adViewDelegate == nil {
            AMLogDebug("Ignoring attempt to trigger browser on ad while not attached to a view.")
            return
        }
        if !userInteractedWithContentView {
            AMLogDebug("Ignoring attempt to trigger browser as no hit was registered on the ad")
            return
        }

        if .returnURL != adViewDelegate?.clickThroughAction {
            adViewDelegate?.adWasClicked()
        }

        switch adViewDelegate?.clickThroughAction {
            case .returnURL:
                webViewController?.updateViewability(isViewable())
                adViewDelegate?.adWasClicked?(withURL: URL?.absoluteString)
                AMLogDebug("ClickThroughURL=\(String(describing: URL))")
            case .openDeviceBrowser:
                if let URL = URL {
                    if UIApplication.shared.canOpenURL(URL) {
                        adViewDelegate?.adWillLeaveApplication()
                        AMGlobal.openURL(URL.absoluteString)
                    } else {
                        AMLogWarn("opening_url_failed \(URL)")
                    }
                }
            case .openSDKBrowser:
                openInAppBrowser(with: URL)
            default:
                let act = adViewDelegate?.clickThroughAction.rawValue ?? -1
                AMLogError("UNKNOWN AMClickThroughAction \(act)")
        }
    }

    func openInAppBrowser(with URL: URL?) {
        if !userInteractedWithContentView {
            AMLogDebug("Ignoring attempt to trigger browser as no hit was registered on the ad")
            return
        }

        adInteractionBegan(with: .browser)
        if browserViewController == nil {
            browserViewController = AMBrowserViewController(
                url: URL,
                delegate: self,
                delayPresentationForLoad: adViewDelegate?.landingPageLoadsInBackground ?? false)
            if browserViewController == nil {
                AMLogError("Browser controller did not instantiate correctly.")
                return
            }
        } else {
            browserViewController?.url = URL
        }
    }

// MARK: - AMAdWebViewControllerLoadingDelegate
    @objc func didCompleteFirstLoad(from controller: AMAdWebViewController?) {
        if controller == webViewController {
            // Attaching WKWebView to screen for an instant to allow it to fully load in the background
            //   before the call to [AMAdDelegate adDidReceiveAd:self].
            //
            // NB  For banner video, this step has already occured in [AMAdViewWebController initWithSize:videoXML:].
            //
            if !isBannerVideo {
                webViewController?.contentView?.isHidden = true
                if let contentView1 = webViewController?.contentView {
                    UIApplication.shared.keyWindow?.insertSubview(
                        contentView1,
                        at: 0)
                }
            }

            weak var weakSelf = self

            DispatchQueue.main.async(
                execute: {
                    let strongSelf = weakSelf
                    if strongSelf == nil {
                        AMLogError("COULD NOT ACQUIRE strongSelf.")
                        return
                    }

                    let contentView = strongSelf?.webViewController?.contentView

                    contentView?.translatesAutoresizingMaskIntoConstraints = false

                    if let contentView = contentView {
                        strongSelf?.addSubview(contentView)
                    }
                    strongSelf?.webViewController?.contentView?.isHidden = false

                    contentView?.anConstrainToSizeOfSuperview()
                    contentView?.anAlignToSuperview(withXAttribute: .left, yAttribute: .top)

                    strongSelf?.loadingDelegate?.didCompleteFirstLoad(from: controller)
                })
        }
    }

    @objc func immediatelyRestartAutoRefreshTimer(from controller: AMAdWebViewController?) {
        if loadingDelegate?.responds(to: #selector(AMUniversalAdFetcher.immediatelyRestartAutoRefreshTimer(from:))) ?? false {
            loadingDelegate?.immediatelyRestartAutoRefreshTimer?(from: controller)
        }
    }

    @objc func stopAutoRefreshTimer(from controller: AMAdWebViewController?) {
        if loadingDelegate?.responds(to: #selector(AMUniversalAdFetcher.stopAutoRefreshTimer(from:))) ?? false {
            loadingDelegate?.stopAutoRefreshTimer?(from: controller)
        }
    }

// MARK: - AMAdWebViewControllerMRAIDDelegate
    func defaultPosition() -> CGRect {
        if window != nil {
            let absoluteContentViewFrame = convert(bounds, to: nil)
            var position = AMAdjustAbsoluteRectInWindowCoordinatesForOrientationGivenRect(absoluteContentViewFrame)
            if !transform.isIdentity {
                // In the case of a magnified webview, need to pass the non-magnified size to the webview
                position.size = anOriginalFrame.size
            }
            lastKnownDefaultPosition = position
            return position
        } else {
            return lastKnownDefaultPosition
        }
    }

    var currentPosition: CGRect {
        var contentView = webViewController?.contentView
        if expandWebViewController?.contentView?.window != nil {
            contentView = expandWebViewController?.contentView
        }

        if contentView != nil {
            let absoluteContentViewFrame = contentView?.convert(contentView?.bounds ?? CGRect.zero, to: nil)
            var position = AMAdjustAbsoluteRectInWindowCoordinatesForOrientationGivenRect(absoluteContentViewFrame ?? CGRect.zero)
            if !transform.isIdentity {
                // In the case of a magnified webview, need to pass the non-magnified size to the webview
                position.size = contentView?.anOriginalFrame.size ?? CGSize.zero
            }
            lastKnownCurrentPosition = position
            return position
        } else {
            return lastKnownCurrentPosition
        }
    }

    @objc func isViewable() -> Bool {
        if isBannerVideo {
            return webViewController?.contentView?.anIsAtLeastHalfViewable ?? false
        }
        guard let expVC = expandWebViewController else {
            return webViewController?.contentView?.anIsViewable ?? false
        }
        return expVC.contentView?.anIsViewable ?? false
    }

    func exposedPercent() -> CGFloat {
        guard let expVC = expandWebViewController else {
            return webViewController?.contentView?.anExposedPercentage ?? 0.0
        }
        return expVC.contentView?.anExposedPercentage ?? 0.0
    }

    var visibleRect: CGRect {
        guard let expVC = expandWebViewController else {
            return webViewController?.contentView?.anVisibleRectangle ?? .zero
        }
        return expVC.contentView?.anVisibleRectangle ?? .zero
    }

    func adShouldExpand(with expandProperties: AMMRAIDExpandProperties?) {
        let presentingController = displayController()
        if presentingController == nil {
            AMLogDebug("Ignoring call to mraid.expand() - no root view controller to present from")
            return
        }
        if !userInteractedWithContentView {
            AMLogDebug("Ignoring attempt to expand ad as no hit was detected on ad")
            return
        }

        handleBrowserLoadingForMRAIDStateChange()
        adInteractionBegan(with: .expandedOrResized)

        AMLogDebug("Expanding with expand properties: \(String(describing: expandProperties?.description))")
        adViewDelegate?.adWillPresent()
        if resized {
            resizeManager?.detachResizeView()
            resizeManager = nil
        }

        var expandContentView = webViewController?.contentView

        var presentWithAnimation = false

        if (expandProperties?.anURL?.absoluteString.count ?? 0) != 0 {
            let customConfig = AMAdWebViewControllerConfiguration()

            customConfig.scrollingEnabled = true
            customConfig.navigationTriggersDefaultBrowser = false
            customConfig.initialMRAIDState = .expanded
            customConfig.userSelectionEnabled = true

            expandWebViewController = AMAdWebViewController(
                size: AMMRAIDUtil.screenSize(),
                url: expandProperties?.anURL,
                webViewBaseURL: baseURL,
                configuration: customConfig)
            expandWebViewController?.mraidDelegate = self
            expandWebViewController?.browserDelegate = self
            expandWebViewController?.anjamDelegate = self
            expandWebViewController?.adViewDelegate = adViewDelegate

            expandContentView = expandWebViewController?.contentView
            presentWithAnimation = true
        }

        expandController = AMMRAIDExpandViewController(
            contentView: expandContentView,
            expandProperties: expandProperties)
        if orientationProperties != nil {
            adShouldSetOrientationProperties(orientationProperties)
        }
        expandController?.modalPresentationStyle = .fullScreen
        expandController?.delegate = self
        if let expandController = expandController {
            presentingController?.present(
                expandController,
                animated: presentWithAnimation) {
                    self.adViewDelegate?.adDidPresent()
                    self.webViewController?.adDidFinishExpand()
                }
        }
    }

    func adShouldSetOrientationProperties(_ orientationProperties: AMMRAIDOrientationProperties?) {
        AMLogDebug("Setting orientation properties: \(String(describing: orientationProperties?.description))")
        self.orientationProperties = orientationProperties
        if let expController = expandController {
            expController.orientationProperties = orientationProperties
            return
        }
        
        if let interstitialDelegate = adViewDelegate as? AMInterstitialAdViewInternalDelegate {
            interstitialDelegate.adShouldSetOrientationProperties(orientationProperties)
        } else
        if let rewardedDelegate = adViewDelegate as? AMRewardedAdViewInternalDelegate {
            rewardedDelegate.adShouldSetOrientationProperties(orientationProperties)
        }
    }

    func adShouldSetUseCustomClose(_ useCustomClose: Bool) {
        AMLogDebug("Setting useCustomClose: \(useCustomClose)")
        self.useCustomClose = useCustomClose
        if let interstitialDelegate = adViewDelegate as? AMInterstitialAdViewInternalDelegate {
            interstitialDelegate.adShouldUseCustomClose(useCustomClose)
            if useCustomClose {
//                addSupplementaryCustomCloseRegion()
            }
        } else
        if let rewardedDelegate = adViewDelegate as? AMRewardedAdViewInternalDelegate {
            rewardedDelegate.adShouldUseCustomClose(useCustomClose)
        }
    }

    func addSupplementaryCustomCloseRegion() {
        customCloseRegion = UIButton(type: .custom)
        customCloseRegion?.translatesAutoresizingMaskIntoConstraints = false

        if let customCloseRegion = customCloseRegion, let contentView1 = webViewController?.contentView {
            insertSubview(
                customCloseRegion,
                aboveSubview: contentView1)
        }

        customCloseRegion?.anConstrain(with: CGSize(width: 50.0, height: 50.0))
        customCloseRegion?.anAlignToSuperview(
            withXAttribute: .right,
            yAttribute: .top)

        customCloseRegion?.addTarget(
            self,
            action: #selector(closeInterstitial(_:)),
            for: .touchUpInside)
    }

    @objc func closeInterstitial(_ sender: Any?) {
        if let interstitialDelegate = adViewDelegate as? AMInterstitialAdViewInternalDelegate {
            interstitialDelegate.adShouldClose()
        } else
        if let rewardedDelegate = adViewDelegate as? AMRewardedAdViewInternalDelegate {
            rewardedDelegate.adShouldClose()
        }
    }

    func adShouldAttemptResize(with resizeProperties: AMMRAIDResizeProperties?) {
        if !userInteractedWithContentView {
            AMLogDebug("Ignoring attempt to resize ad as no hit was detected on ad")
            return
        }

        AMLogDebug("Attempting resize with resize properties: \(String(describing: resizeProperties?.description))")
        handleBrowserLoadingForMRAIDStateChange()
        adInteractionBegan(with: .expandedOrResized)

        if resizeManager == nil {
            resizeManager = AMMRAIDResizeViewManager(
                contentView: webViewController?.contentView,
                anchorView: self)
            resizeManager?.delegate = self
        }

        var errorString: String?
        let resizeHappened = resizeManager?.attemptResize(with: resizeProperties, errorString: &errorString) ?? false
        
        webViewController?.adDidFinishResize(resizeHappened, errorString: errorString, isResized: resized)
        if !resized {
            adInteractionEnded(for: .expandedOrResized)
        }
    }

    func adShouldClose() {
        if resized || expanded {
            adShouldResetToDefault()
        } else {
            adShouldHide()
        }

        adInteractionEnded(for: .expandedOrResized)
    }

    func adShouldResetToDefault() {
        resizeManager?.detachResizeView()
        resizeManager = nil

        handleBrowserLoadingForMRAIDStateChange()

        if expanded {
            adViewDelegate?.adWillClose()

            var dismissWithAnimation = false
            let detachedContentView = expandController?.detachContentView()
            if detachedContentView == expandWebViewController?.contentView {
                dismissWithAnimation = true
            }

            expandController?.dismiss(
                animated: dismissWithAnimation) {
                    self.adViewDelegate?.adDidClose()
                }
            expandController = nil
        }

        expandWebViewController = nil

        let contentView = webViewController?.contentView
        if contentView?.superview != self {
            if let contentView = contentView {
                addSubview(contentView)
            }
            if let constraints = contentView?.constraints {
                contentView?.removeConstraints(constraints)
            }
            contentView?.anConstrainToSizeOfSuperview()
            contentView?.anAlignToSuperview(
                withXAttribute: .left,
                yAttribute: .top)
        }

        webViewController?.adDidResetToDefault()
        adInteractionEnded(for: .expandedOrResized)
    }

    func adShouldHide() {
        handleBrowserLoadingForMRAIDStateChange()

        if embeddedInModalView && adViewDelegate is AMInterstitialAdViewInternalDelegate {
            (adViewDelegate as? AMInterstitialAdViewInternalDelegate)?.adShouldClose()
        } else
        if embeddedInModalView && adViewDelegate is AMRewardedAdViewInternalDelegate {
            (adViewDelegate as? AMRewardedAdViewInternalDelegate)?.adShouldClose()
        }else {
            UIView.animate(
                withDuration: TimeInterval(kAdmixerAnimationDuration),
                animations: {
                    self.webViewController?.contentView?.alpha = 0.0
                }) { finished in
                    self.webViewController?.contentView?.isHidden = true
                }
            webViewController?.adDidHide()
        }
        adInteractionEnded(for: .expandedOrResized)
    }

    func adShouldOpenCalendar(withCalendarDict calendarDict: [AnyHashable : Any]?) {
        if !userInteractedWithContentView {
            AMLogDebug("Ignoring attempt to open calendar as no hit was detected on ad")
            return
        }

        adInteractionBegan(with: .calendar)
        calendarManager = AMMRAIDCalendarManager(
            calendarDictionary: calendarDict,
            delegate: self)
    }

    func adShouldSavePicture(withUri uri: String?) {
        if !userInteractedWithContentView {
            AMLogDebug("Ignoring attempt to save picture as no hit was detected on ad")
            return
        }

        adInteractionBegan(with: .picture)
        AMMRAIDUtil.storePicture(
            withUri: uri,
            withCompletionTarget: self,
            completionSelector: #selector(AMStorePictureCallbackProtocol.image(_:didFinishSavingWithError:contextInfo:)))
    }

    @objc func image(_ image: UIImage?, didFinishSavingWithError error: Error?, contextInfo: UnsafeMutableRawPointer?) {
        if error != nil {
            webViewController?.adDidFailPhotoSaveWithErrorString(error?.localizedDescription)
            expandWebViewController?.adDidFailPhotoSaveWithErrorString(error?.localizedDescription)
        }
        adInteractionEnded(for: .picture)
    }

    func adShouldPlayVideo(withUri uri: String?) {
        let presentingViewController = displayController()
        if presentingViewController == nil {
            AMLogDebug("Ignoring call to mraid.playVideo() - no root view controller to present from")
            return
        }
        if !userInteractedWithContentView {
            AMLogDebug("Ignoring attempt to play video as no hit was detected on ad")
            return
        }

        adInteractionBegan(with: .video)
        resizeManager?.resizeView?.isHidden = true
        AMMRAIDUtil.playVideo(
            withUri: uri,
            fromRootViewController: presentingViewController,
            withCompletionTarget: self,
            completionSelector: #selector(moviePlayerDidFinish(_:)))
    }

    @objc func moviePlayerDidFinish(_ notification: Notification?) {
        resizeManager?.resizeView?.isHidden = false
        adInteractionEnded(for: .video)
    }

// MARK: - UIView observer methods.
    override func didMoveToWindow() {
        resizeManager?.didMoveAnchorViewToWindow()
    }

// MARK: - AMMRAIDCalendarManagerDelegate
    func rootViewControllerForPresentation(for calendarManager: AMMRAIDCalendarManager?) -> UIViewController? {
        return displayController()
    }

    func willDismissCalendarEdit(for calendarManager: AMMRAIDCalendarManager?) {
        if !embeddedInModalView && !expanded {
            adViewDelegate?.adWillClose()
        }
        resizeManager?.resizeView?.isHidden = false
    }

    func didDismissCalendarEdit(for calendarManager: AMMRAIDCalendarManager?) {
        if !embeddedInModalView && !expanded {
            adViewDelegate?.adDidClose()
        }
        adInteractionEnded(for: .calendar)
    }

    func willPresentCalendarEdit(for calendarManager: AMMRAIDCalendarManager?) {
        if !embeddedInModalView && !expanded {
            adViewDelegate?.adWillPresent()
        }
        resizeManager?.resizeView?.isHidden = true
    }

    func didPresentCalendarEdit(for calendarManager: AMMRAIDCalendarManager?) {
        if !embeddedInModalView && !expanded {
            adViewDelegate?.adDidPresent()
        }
    }

    func calendarManager(_ calendarManager: AMMRAIDCalendarManager?, calendarEditFailedWithErrorString errorString: String?) {
        webViewController?.adDidFailCalendarEditWithErrorString(errorString)
        expandWebViewController?.adDidFailPhotoSaveWithErrorString(errorString)
        adInteractionEnded(for: .calendar)
    }

// MARK: - AMMRAIDExpandViewControllerDelegate
    func closeButtonWasTapped(on controller: AMMRAIDExpandViewController?) {
        adShouldResetToDefault()
    }

    func dismissAndPresentAgainForPreferredInterfaceOrientationChange() {
        weak var weakSelf = self
        let presentingViewController = expandController?.presentingViewController

        presentingViewController?.dismiss(
            animated: false) {
                let strongSelf = weakSelf
                if strongSelf == nil {
                    AMLogError("COULD NOT ACQUIRE strongSelf.")
                    return
                }
                strongSelf?.expandController?.modalPresentationStyle = .fullScreen

                if let expandController1 = strongSelf?.expandController {
                    presentingViewController?.present(
                        expandController1,
                        animated: false)
                }
            }
    }

// MARK: - AMMRAIDResizeViewManagerDelegate
    func resizeViewClosed(by manager: AMMRAIDResizeViewManager?) {
        adShouldResetToDefault()
    }

// MARK: - AMAdWebViewControllerVideoDelegate.

    // NB  self.webViewController embeds its contentView into self.contentViewContainer.
    //     VAST fullscreen option is implemented by changing the frame size of self.contentViewContainer.
    //
    @objc func videoAdReady() {
        didCompleteFirstLoad(from: webViewController)
    }

    @objc func videoAdLoadFailed(_ error: Error?, with adResponseInfo: AMAdResponseInfo?) {
        if adViewDelegate?.responds(to: #selector(AMAdView.adRequestFailedWithError(_:andAdResponseInfo:))) ?? false {
            adViewDelegate?.adRequestFailedWithError(error, andAdResponseInfo: adResponseInfo)
        }
    }

    @objc func videoAdError(_ error: Error?) {
        guard let err = error as NSError? else { return }
        let userInfo = err.userInfo
        let errorString = "NSError: code=\(NSNumber(value: err.code)) domain=\(err.domain) userInfo=\(userInfo)"
        AMLogError(errorString)
    }

    @objc func videoAdPlayerFullScreenEntered(_ videoAd: AMAdWebViewController?) {
        let presentingController = displayController()
        if presentingController == nil {
            AMLogDebug("Ignoring call to mraid.expand() - no root view controller to present from")
            return
        }
        vastVideofullScreenController = AMInterstitialAdViewController()
        vastVideofullScreenController?.needCloseButton = false
        vastVideofullScreenController?.contentView = videoAd?.contentView
        vastVideofullScreenController?.modalPresentationStyle = .fullScreen
        if backgroundColor != nil {
            vastVideofullScreenController?.backgroundColor = backgroundColor
        }
        if let vastVideofullScreenController = vastVideofullScreenController {
            presentingController?.present(
                vastVideofullScreenController,
                animated: false)
        }

        isFullscreen = true

    }

    @objc func videoAdPlayerFullScreenExited(_ videoAd: AMAdWebViewController?) {
        let contentView = videoAd?.contentView

        contentView?.translatesAutoresizingMaskIntoConstraints = false

        if let contentView = contentView {
            addSubview(contentView)
        }

        contentView?.anConstrainToSizeOfSuperview()
        contentView?.anAlignToSuperview(
            withXAttribute: .left,
            yAttribute: .top)

        vastVideofullScreenController?.presentingViewController?.dismiss(animated: false)
        vastVideofullScreenController = nil
        isFullscreen = false
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
