//
//  AMInterstitialAd.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation
import UIKit

private let kAMInterstitialAdTimeout: TimeInterval = 270.0
// List of allowed ad sizes for interstitials.  These must fit in the
// maximum size of the view, which in this case, will be the size of
// the window.
let kAMInterstitialAdSize300x250 = CGSize(width: 300, height: 250)
let kAMInterstitialAdSize320x480 = CGSize(width: 320, height: 480)
let kAMInterstitialAdSize900x500 = CGSize(width: 900, height: 500)
let kAMInterstitialAdSize1024x1024 = CGSize(width: 1024, height: 1024)
let kAMInterstitialAdViewKey = "kAMInterstitialAdViewKey"
let kAMInterstitialAdObjectHandlerKey = "kAMInterstitialAdObjectHandlerKey"
let kAMInterstitialAdViewDateLoadedKey = "kAMInterstitialAdViewDateLoadedKey"
let kAMInterstitialAdViewAuctionInfoKey = "kAMInterstitialAdViewAuctionInfoKey"

/// This is the interface through which interstitial ads are (1)
/// fetched and then (2) shown.  These are distinct steps.  Here's an
/// example:
/// @code
/// // Make an interstitial ad.
/// self.inter = [[AMInterstitialAd alloc] initWithPlacementId:@"1326299"];
/// // We set ourselves as the delegate so we can respond to the `adDidReceiveAd:' message of the
/// // `AMInterstitialAdDelegate' protocol.  (See the bottom of this file for an example.)
/// self.inter.delegate = self;
/// // When the user clicks, use the following to open the default browser on the device.
/// self.inter.clickThroughAction = AMClickThroughActionOpenDeviceBrowser;
/// // Fetch an ad in the background.  In order to show this ad,
/// // you'll need to implement `adDidReceiveAd:' (see below).
/// [self.inter loadAd];
/// @endcode
@objc
public class AMInterstitialAd: AMAdView, AMInterstitialAdViewControllerDelegate, AMInterstitialAdViewInternalDelegate {
    /// Delegate object that receives custom app event notifications from this
    /// AMInterstitialAd.
    weak var appEventDelegate: AMAppEventDelegate?
    /// Whether the interstitial ad has been fetched and is ready to
    /// display.

    public var isReady: Bool {
        // check the cache for a valid ad
        while (precachedAdObjects?.count ?? 0) > 0 {
            let adDict = precachedAdObjects?[0] as? [String : Any]

            // Check to see if the ad has expired
            if let dateLoaded = adDict?[kAMInterstitialAdViewDateLoadedKey] as? Date {
                let timeIntervalSinceDateLoaded = TimeInterval(dateLoaded.timeIntervalSinceNow * -1)
                if timeIntervalSinceDateLoaded >= 0 && timeIntervalSinceDateLoaded < kAMInterstitialAdTimeout {
                    // Found a valid ad
                    if let readyAd = adDict?[kAMInterstitialAdViewKey] as? AMCustomAdapterInterstitial {
                        return readyAd.isReady()
                    }
                    // if it's a standard ad, we are ready to display
                    return true
                } else {
                    // Ad is stale, remove it
                    precachedAdObjects?.remove(at: 0)
                    continue
                }
            } else {
                precachedAdObjects?.remove(at: 0)
            }
        }

        return false
    }
    /// The delay between when an interstitial ad is displayed and when the
    /// close button appears to the user. 10 seconds is the default; it is
    /// also the maximum. Setting the value to 0 allows the close button to
    /// appear immediately.

    private var _closeDelay: TimeInterval = 0.0
    var closeDelay: TimeInterval {
        get {
            _closeDelay
        }
        set(closeDelay) {
            if closeDelay > kAMInterstitialMaximumCloseButtonDelay {
                AMLogWarn("Maximum allowed value for closeDelay is %.1f", kAMInterstitialMaximumCloseButtonDelay)
                _closeDelay = TimeInterval(kAMInterstitialMaximumCloseButtonDelay)
            }

            _closeDelay = closeDelay
        }
    }
    /// The set of allowed ad sizes for the interstitial ad.
    /// The set should contain CGSize values wrapped as NSValue objects.

    private var _allowedAdSizes: Set<NSValue> = []
    var allowedAdSizes: Set<NSValue> {
        get {
            _allowedAdSizes
        }
        set(newValue) {
            if (newValue.count <= 0) {
                AMLogError("adSizes array IS EMPTY.")
                return
            }

            for value in newValue {
                let sizeElement = value.cgSizeValue

                if (sizeElement.width <= 0) || (sizeElement.height <= 0) {
                    AMLogError("One or more elements assigned to allowedAdSizes have a width or height LESS THAN ZERO. \(newValue)")
                    return
                }
            }

            _allowedAdSizes = Set(newValue)
        }
    }
    /// The set of setDismissOnClick for the interstitial ad dismiss
    /// the interstitial ad view when the user clicks the ad
    var dismissOnClick = false

    /// Initialize the ad view, with required placement ID. Note that
    /// you'll need to get a placement ID from your Admixer representative
    /// or your ad network.
    /// - Parameter placementId: the placement ID given from AN
    /// - Returns:s void
    @objc
    public convenience init(placementId: String) {
        self.init(frame: .zero)

        self.adFormat = .interstitial
        self.placementId = placementId
    }
    
    private var confirmationURLs: [String]? = nil

    /// Once you've loaded the ad into your view with loadAd, you'll show
    /// it to the user.  For example:
    /// @code
    /// - (void)adDidReceiveAd:(id)ad
    /// {
    /// if (self.inter.isReady) {
    /// [self.inter displayAdFromViewController:self];
    /// }
    /// }
    /// @endcode
    /// Technically, you don't need to implement adDidReceiveAd: in order to
    /// display the ad; it's used here for convenience. Note that you should
    /// check isReady first to make sure there's an ad to show.
    @objc
    public func display(from controller: UIViewController) {
        display(from: controller, autoDismissDelay: -1)
    }

    /// Instead of displaying an interstitial to the user using displayAdFromViewController, alternatively, you can use the
    /// method below which will auto-dismiss the ad after the delay seconds.
    public func display(from vc: UIViewController, autoDismissDelay delay: TimeInterval) {

        var adToShow: Any? = nil
        var adObjectHandler: Any? = nil

        var impressionURLs: [String]? = nil


        self.controller?.orientationProperties = nil
        self.controller?.useCustomClose = false

        if (self.controller?.contentView is AMMRAIDContainerView) {
            let mraidContainerView = self.controller?.contentView as? AMMRAIDContainerView
            mraidContainerView?.adViewDelegate = nil
        }


        // Find first valid pre-cached ad and meta data.
        // Pull out impression URL trackers.
        //
        while (precachedAdObjects?.count ?? 0) > 0 {
            // Pull the first ad off
            let adDict = precachedAdObjects?[0] as? [AnyHashable : Any]

            // Check to see if ad has expired
            guard let dateLoaded = adDict?[kAMInterstitialAdViewDateLoadedKey] as? Date else { continue }
            let timeIntervalSinceDateLoaded = TimeInterval(dateLoaded.timeIntervalSinceNow * -1)
            if timeIntervalSinceDateLoaded >= 0 && timeIntervalSinceDateLoaded < kAMInterstitialAdTimeout {
                // If ad is still valid, save a reference to it. We'll use it later
                adToShow = adDict?[kAMInterstitialAdViewKey]
                adObjectHandler = adDict?[kAMInterstitialAdObjectHandlerKey]

                precachedAdObjects?.remove(at: 0)
                break
            }

            // This ad is now stale, so remove it from our cached ads.
            precachedAdObjects?.remove(at: 0)
        }
        
        impressionURLs = (adObjectHandler  as? AMBaseAdObject)?.impressionUrls
        clickURLs = (adObjectHandler as? AMBaseAdObject)?.clickUrls
        
        if impressionURLs?.count ?? 0 > 0 {
            confirmationURLs = []
            for url in impressionURLs! {
                guard url.contains("cet=4") else { continue }
                confirmationURLs?.append(url.replacingOccurrences(of: "cet=4", with: "cet=9"))
            }
            
            if confirmationURLs!.count > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    self?.fireConfView()
                }
            }
        }



        // Display the ad.
        //
        if let adViewToShow = adToShow as? UIView {
            if self.controller == nil {
                AMLogError("Could not present interstitial because of a nil interstitial controller. This happens because of ANSDK resources missing from the app bundle.")
                adFailedToDisplay()
                return
            }
            if let mraidContainerView = adToShow as? AMMRAIDContainerView {
                mraidContainerView.adViewDelegate = self
                mraidContainerView.embeddedInModalView = true
                mraidContainerView.shouldDismissOnClick = dismissOnClick
            }

            self.controller?.contentView = adViewToShow
            self.controller?.autoDismissAdDelay = delay

            if backgroundColor != nil {
                self.controller?.backgroundColor = backgroundColor
            }
            self.controller?.modalPresentationStyle = .fullScreen
            self.controller?.modalPresentationCapturesStatusBarAppearance = true

            if !isOpaque && self.controller?.responds(to: #selector(UIContentContainer.viewWillTransition(to:with:))) ?? false {
                self.controller?.modalPresentationStyle = .overFullScreen
            }

            AMTrackerManager.fireTrackerURLArray(impressionURLs)
            impressionURLs = nil

            // Fire OMID - Impression event only for Admixer WKWebview TRUE for RTB and SSM
//            if (adToShow is AMMRAIDContainerView) {
//                let standardAdView = adToShow as? AMMRAIDContainerView
                //            if(standardAdView.webViewController.omidAdSession){
                //                [[AMOMIDImplementation sharedInstance] fireOMIDImpressionOccuredEvent:standardAdView.webViewController.omidAdSession];
                //            }
//            }

            if let controller = self.controller {
                vc.present(controller, animated: true)
            }
        } else if adToShow is AMCustomAdapterInterstitial {
            AMTrackerManager.fireTrackerURLArray(impressionURLs)
            impressionURLs = nil
            (adToShow as? AMCustomAdapterInterstitial)?.present(from: vc)
        } else {
            AMLogError("Display ad called, but no valid ad to show. Please load another interstitial ad.")
            adFailedToDisplay()
            return
        }

    }
    
    private func fireConfView() {
        guard confirmationURLs != nil else {return}
        
        AMTrackerManager.fireTrackerURLArray(confirmationURLs)
        confirmationURLs = nil
    }

    private var controller: AMInterstitialAdViewController?
    private var precachedAdObjects: [Any]?

    public override var frame: CGRect {
        get {
            // By definition, interstitials can only ever have the entire screen's bounds as its frame
            let screenBounds = AMPortraitScreenBounds()
            if controller?.orientation.isLandscape ?? false {
                return CGRect(x: screenBounds.origin.y, y: screenBounds.origin.x, width: screenBounds.size.height, height: screenBounds.size.width)
            }
            return screenBounds
        }
        set{
//            self.frame = newValue
        }
    }
    private var containerSize = CGSize.zero

// MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)

        controller = AMInterstitialAdViewController()
        controller?.delegate = self
        precachedAdObjects = []
        closeDelay = TimeInterval(kAMInterstitialDefaultCloseButtonDelay)
        isOpaque = true
        containerSize = ADMIXER_SIZE_UNDEFINED
        allowedAdSizes = getDefaultAllowedAdSizes()
        allowSmallerSizes = false
        //    [[AMOMIDImplementation sharedInstance] activateOMIDandCreatePartner];
    }

    deinit {
        controller?.delegate = nil
    }

    func getDefaultAllowedAdSizes() -> Set<NSValue> {
        var defaultAllowedSizes: Set<NSValue> = []

        let possibleSizesArray = [
            NSValue(cgSize: kAMInterstitialAdSize1024x1024),
            NSValue(cgSize: kAMInterstitialAdSize900x500),
            NSValue(cgSize: kAMInterstitialAdSize320x480),
            NSValue(cgSize: kAMInterstitialAdSize300x250)
        ]

        for sizeValue in possibleSizesArray {
            let possibleSize = sizeValue.cgSizeValue
            let possibleSizeRect = CGRect(x: frame.origin.x, y: frame.origin.y, width: possibleSize.width, height: possibleSize.height)
            if frame.contains(possibleSizeRect) {
                defaultAllowedSizes.insert(sizeValue)
            }
        }

        return defaultAllowedSizes
    }

// MARK: - Setters and getters.

// MARK: - EntryPoint ad serving lifecycle.

// MARK: - AMUniversalAdFetcherDelegate
    @objc override func videoAdType(for fetcher: AMUniversalAdFetcher?) -> AMVideoAdSubtype {
        return .bannerVideo
    }
    
    @objc override func universalAdFetcher(_ fetcher: AMUniversalAdFetcher?, didFinishRequestWith response: AMAdFetcherResponse?) {
        let isResponseSuccessful = response?.successful ?? false
        guard isResponseSuccessful  else {
            adRequestFailedWithError(response?.error, andAdResponseInfo: response?.adResponseInfo)
            return
        }
        let objHandler = response?.adObjectHandler
        let info = objHandler?.adResponseInfo
        if let info = info {
            self.adResponseInfo = info
        }
        
        let creativeId = objHandler?.creativeId
        if let id = creativeId { self.creativeId = id}

        var adViewWithDateLoaded: [AnyHashable : Any]? = nil
        if let adObjectHandler1 = objHandler, let obj = response?.adObject {
            adViewWithDateLoaded = [
                kAMInterstitialAdViewKey : obj,
                kAMInterstitialAdObjectHandlerKey : adObjectHandler1,
                kAMInterstitialAdViewDateLoadedKey : Date()
            ]
        }

        if let adViewWithDateLoaded = adViewWithDateLoaded {
            self.precachedAdObjects?.append(adViewWithDateLoaded)
        }
        AMLogDebug("Stored ad \(String(describing: adViewWithDateLoaded)) in precached ad views")

        adDidReceiveAd(self)

    }

    @objc override func requestedSize(for fetcher: AMUniversalAdFetcher?) -> CGSize {
        return frame.size
    }

// MARK: - AMInterstitialAdViewControllerDelegate
    func interstitialAdViewControllerShouldDismiss(_ controller: AMInterstitialAdViewController?) {
        adWillClose()

        weak var weakSelf = self

        self.controller?.presentingViewController?.dismiss(
            animated: true) {
                let strongSelf = weakSelf
                if strongSelf == nil {
                    return
                }

                strongSelf?.controller = nil
                strongSelf?.adDidClose()
            }
    }

    func closeDelayForController() -> TimeInterval {
        return closeDelay
    }

    func dismissAndPresentAgainForPreferredInterfaceOrientationChange() {
        weak var weakSelf = self

        controller?.presentingViewController?.dismiss(
            animated: false) {
                let strongSelf = weakSelf
                if strongSelf == nil {
                    return
                }

                if let controller1 = strongSelf?.controller {
                    strongSelf?.controller?.presentingViewController?.present(
                        controller1,
                        animated: false)
                }
            }
    }

// MARK: - AMAdViewInternalDelegate
    override func adTypeForMRAID() -> String? {
        return "interstitial"
    }

    override func displayController() -> UIViewController? {
        return controller
    }

    override func internalDelegateUniversalTagSizeParameters() -> [AnyHashable : Any] {
        containerSize = frame.size

        var allowedAdSizesForSDK = Set<NSValue>(allowedAdSizes)
        allowedAdSizesForSDK.insert(NSValue(cgSize: kAMAdSize1x1))
        allowedAdSizesForSDK.insert(NSValue(cgSize: containerSize))

        allowSmallerSizes = false

        //
        var delegateReturnDictionary: [AnyHashable : Any] = [:]
        delegateReturnDictionary[AMInternalDelgateTagKeyPrimarySize] = NSValue(cgSize: containerSize)
        delegateReturnDictionary[AMInternalDelegateTagKeySizes] = Array(allowedAdSizesForSDK)
        delegateReturnDictionary[AMInternalDelegateTagKeyAllowSmallerSizes] = NSNumber(value: allowSmallerSizes)

        return delegateReturnDictionary
    }

// MARK: - AMInterstitialAdViewInternalDelegate
    func adFailedToDisplay() {
        guard let intDelegate = self.delegate as? AMInterstitialAdDelegate else { return }
        intDelegate.adFailed?(toDisplay: self)
    }

    func adShouldClose() {
        controller?.closeAction(true)
    }

    func adShouldSetOrientationProperties(_ orientationProperties: AMMRAIDOrientationProperties?) {
        controller?.orientationProperties = orientationProperties
    }

    func adShouldUseCustomClose(_ useCustomClose: Bool) {
        controller?.useCustomClose = useCustomClose
    }

    override func adAllowedMediaTypes() -> [Int] {
        return [AMAllowedMediaType.banner.rawValue, AMAllowedMediaType.interstitial.rawValue]
    }

// MARK: - Helper methods.

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}

// MARK: AMInterstitialAdDelegate
@objc public protocol AMInterstitialAdDelegate: AMAdDelegate {
    /// This method tells your ad view what to do if the ad can't be shown.
    /// A simple implementation used during development could just log,
    /// like so:
    /// @code
    /// - (void)adFailedToDisplay:(AMInterstitialAd *)ad
    /// {
    /// NSLog(@"Oh no, the ad failed to display!");
    /// }
    /// @endcode
    @objc optional func adFailed(toDisplay ad: AMInterstitialAd)
}
