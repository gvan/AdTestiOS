//
//  AMNativeStandardAdResponse.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import UIKit
import Foundation

class AMNativeStandardAdResponse: AMNativeAdResponse, AMBrowserViewControllerDelegate {
    
    var adObjectMediaType: String?
    var clickTrackers: [String]?
    var impTrackers: [String]?
    var clickURL: URL?
    var clickFallbackURL: URL?
    
    
    private var dateCreated: Date?
    private var inAppBrowser: AMBrowserViewController?
    private var viewabilityValue = 0
    private var targetViewabilityValue = 0
    private var viewabilityTimer: Timer?
    private var impressionHasBeenTracked = false

// MARK: - Lifecycle.
    override init() {
        super.init()
            networkCode = .admixer
            dateCreated = Date()
            impressionHasBeenTracked = false
    }

    deinit {
        viewabilityTimer?.invalidate()
    }

// MARK: - Registration
    override func registerInstance(withNativeView view: UIView?, rootViewController controller: UIViewController?, clickableViews: [AnyHashable]?) throws  -> Bool {
        setupViewabilityTracker()
        attachGestureRecognizers(
            toNativeView: view,
            withClickableViews: clickableViews)
        return true
    }

    @objc override func unregisterViewFromTracking() {
        super.unregisterViewFromTracking()
        viewabilityTimer?.invalidate()
    }

// MARK: - Impression Tracking
    func setupViewabilityTracker() {
        weak var weakSelf = self
        let requiredAmountOfSimultaneousViewableEvents = round(
            kAdmixerNativeAdIABShouldBeViewableForTrackingDuration / kAdmixerNativeAdCheckViewabilityForTrackingFrequency) + 1
        targetViewabilityValue = Int(round(pow(2, requiredAmountOfSimultaneousViewableEvents) - 1))
        
        let amount = NSNumber(value: requiredAmountOfSimultaneousViewableEvents)
        let viewability = NSNumber(value: targetViewabilityValue)
        AMLogDebug("\n\trequiredAmountOfSimultaneousViewableEvents=\(amount)  \n\ttargetViewabilityValue=\(viewability)")

        viewabilityTimer = Timer.anScheduledTimer(
            with: TimeInterval(kAdmixerNativeAdCheckViewabilityForTrackingFrequency),
            block: {
                let strongSelf = weakSelf
                strongSelf?.checkViewability()
            },
            repeats: true)
    }

    func checkViewability() {
        guard let vTraking = self.viewForTracking else { return }
        
        let valueBool = vTraking.anIsAtLeastHalfViewable
        let valueInt = Int(truncating: NSNumber(value : valueBool))
        viewabilityValue = (viewabilityValue << 1 | valueInt) & targetViewabilityValue
        let isIABViewable = viewabilityValue == targetViewabilityValue
        AMLogDebug("\n\tviewabilityValue=\(viewabilityValue) \n\tself.targetViewabilityValue=\(targetViewabilityValue) \n\tisIABViewable=\(isIABViewable)")

        if isIABViewable {
            trackImpression()
        }
    }

    func trackImpression() {
        if !impressionHasBeenTracked {
            AMLogDebug("Firing impression trackers")
            fireImpTrackers()
            viewabilityTimer?.invalidate()
            impressionHasBeenTracked = true
        }
    }

    func fireImpTrackers() {
        if impTrackers != nil {
            AMTrackerManager.fireTrackerURLArray(impTrackers)
        }
        //    if(self.omidAdSession != nil){
        //        [[AMOMIDImplementation sharedInstance] fireOMIDImpressionOccuredEvent:self.omidAdSession];
        //    }
    }

// MARK: - Click handling
    @objc override func handleClick() {
        fireClickTrackers()

        //
        if .returnURL == clickThroughAction {
            adWasClicked(withURL: clickURL?.absoluteString, fallbackURL: clickFallbackURL?.absoluteString)

            AMLogDebug("ClickThroughURL=\(String(describing: clickURL))")
            AMLogDebug("ClickThroughFallbackURL=\(String(describing: clickFallbackURL))")
            return
        }

        //
        adWasClicked()

        if openIntendedBrowser(with: clickURL) {
            return
        }
        AMLogDebug("Could not open click URL: \(String(describing: clickURL))")

        if openIntendedBrowser(with: clickFallbackURL) {
            return
        }
        AMLogError("Could not open click fallback URL: \(String(describing: clickFallbackURL))" )
    }

    func openIntendedBrowser(with URL: URL?) -> Bool {
        switch clickThroughAction {
            case .openSDKBrowser:
                // Try to use device browser even if SDK browser was requested in cases
                //   where the structure of the URL cannot be handled by the SDK browser.
                //
                if let URL = URL {
                    if !(AMHasHttpPrefix(URL.absoluteString )) && AMiTunesIDForURL(URL) == nil {
                        return openURL(withExternalBrowser: URL)
                    }
                }
                if inAppBrowser == nil {
                    inAppBrowser = AMBrowserViewController(
                        url: URL,
                        delegate: self,
                        delayPresentationForLoad: landingPageLoadsInBackground)
                } else {
                    inAppBrowser?.url = URL
                }
                return true
            case .openDeviceBrowser:
                return openURL(withExternalBrowser: URL)
            case .returnURL:
                fallthrough
            default:
                AMLogError("UNKNOWN AMClickThroughAction.  \(clickThroughAction.rawValue)")
                return false
        }
    }

    func openURL(withExternalBrowser url: URL?) -> Bool {
        if let url = url {
            if !UIApplication.shared.canOpenURL(url) {
                return false
            }
        }

        willLeaveApplication()
        AMGlobal.openURL(url?.absoluteString ?? "")

        return true
    }

    func fireClickTrackers() {
        AMTrackerManager.fireTrackerURLArray(clickTrackers)
    }

// MARK: - AMBrowserViewControllerDelegate
    func rootViewController(forDisplaying controller: AMBrowserViewController?) -> UIViewController? {
        return rootViewController
    }

    @objc func willPresent(_ controller: AMBrowserViewController?) {
        willPresentAd()
    }

    @objc func didPresent(_ controller: AMBrowserViewController?) {
        didPresentAd()
    }

    @objc func willDismiss(_ controller: AMBrowserViewController?) {
        willCloseAd()
    }

    @objc func didDismiss(_ controller: AMBrowserViewController?) {
        inAppBrowser = nil
        didCloseAd()
    }

    @objc func willLeaveApplication(from controller: AMBrowserViewController?) {
        willLeaveApplication()
    }
}
