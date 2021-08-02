//
//  AMMediationAdViewController.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import UIKit
import Foundation

class AMMediationAdViewController: NSObject, AMCustomAdapterBannerDelegate, AMCustomAdapterInterstitialDelegate, AMCustomAdapterRewardedDelegate {
    
    
    private weak var delegate: AMMultiAdRequestDelegate?
    // adUnits is an array of AdUnits managed by the MultiAdRequest.
    // It is declared in a manner capable of storing weak pointers.  Pointers to deallocated AdUnits are automatically assigned to nil.
    //
    private var adUnits: NSPointerArray!
    private var adFetcher: AMAdFetcherBase?
    
    func startTimeout() {

        if timeoutCanceled {
            return
        }
        weak var weakSelf = self
        DispatchQueue.main.asyncAfter(
            deadline: DispatchTime.now() + Double(
                kAdmixerMediationNetworkTimeoutInterval * Double(NSEC_PER_SEC)) / Double(NSEC_PER_SEC),
            execute: {
                let strongSelf = weakSelf
                if strongSelf == nil || strongSelf?.timeoutCanceled ?? false {
                    return
                }
                AMLogWarn("mediation_timeout")
                strongSelf?.didFail(toReceiveAd: .amAdResponseInternalError)
            })

    }

    func clearAdapter() {
        if currentAdapter != nil {
            currentAdapter?.delegate = nil
        }
        currentAdapter = nil
        hasSucceeded = false
        hasFailed = true
        adFetcher = nil
        adViewDelegate = nil
        mediatedAd = nil

        cancelTimeout()

        AMLogInfo("mediation_finish")
    }

    class func initMediatedAd(
        _ mediatedAd: AMMediatedAd?,
        with adFetcher: AMUniversalAdFetcher?,
        adViewDelegate: AMUniversalAdFetcherDelegate?
    ) -> AMMediationAdViewController? {

        let controller = AMMediationAdViewController()
        controller.adFetcher = adFetcher
        controller.adViewDelegate = adViewDelegate

        if controller.request(for: mediatedAd) {
            return controller
        } else {
            return nil
        }
    }

    private var mediatedAd: AMMediatedAd?
    private var currentAdapter: AMCustomAdapter?
    private var hasSucceeded = false
    private var hasFailed = false
    private var timeoutCanceled = false
    private weak var adViewDelegate: AMUniversalAdFetcherDelegate?
    // variables for measuring latency.
    private var latencyStart: TimeInterval = 0.0
    private var latencyStop: TimeInterval = 0.0

// MARK: - Lifecycle.

    func request(for ad: AMMediatedAd?) -> Bool {
        guard let ad = ad else {
            handleInstantiationFailure(
                "",
                errorCode: .amAdResponseUnableToFill,
                errorInfo: "null mediated ad object"
            )
            return false
        }

        mediatedAd = ad
        let className = ad.className ?? ""

        // notify that a mediated class name was received
        AMPostNotifications(
            kAMUniversalAdFetcherWillInstantiateMediatedClassNotification,
            self,
            [ kAMUniversalAdFetcherMediatedClassKey: className ]
        )

        AMLogDebug("instantiating_class \(className))")

        guard let adapter = instantiateAdapterFor(className) else {
            handleInstantiationFailure(
                className,
                errorCode: .amAdResponseMediatedSDKUnavailable,
                errorInfo: "ClassNotFoundError"
            )
            return false
        }

        // instance valid - request a mediated ad
        adapter.delegate = self
        currentAdapter = adapter
        
        // Grab the size of the ad - interstitials will ignore this value
        let sizeOfCreative = CGSize(
            width: ad.width ?? 0,
            height: ad.height ?? 0
        )

        let requestedSuccessfully = requestAd(
            sizeOfCreative,
            serverParameter: ad.param,
            adUnitId: ad.adId,
            adView: adViewDelegate)

        // otherwise, no error yet
        // wait for a mediation adapter to hit one of our callbacks.
        return true
    }
    
    private func instantiateAdapterFor(_ className: String) -> AMCustomAdapter? {
        // Swift expects to see the class name in `NSClassFromString` prefixed by the module name.
        guard
            let adapterClass = NSClassFromString(className) as? AMCustomAdapter.Type
        else {
            return nil
        }
        return adapterClass.init()
    }

    func handleInstantiationFailure(_ className: String?, errorCode: AMAdResponseCode, errorInfo: String?) {
        if let errInfo = errorInfo {
            AMLogError("mediation_instantiation_failure \(errInfo)")
        }

        didFail(toReceiveAd: errorCode)
    }

    func setAdapter(_ adapter: AMCustomAdapter) {
        currentAdapter = adapter
    }

    func requestAd(
        _ size: CGSize,
        serverParameter parameterString: String?,
        adUnitId idString: String?,
        adView: AMUniversalAdFetcherDelegate?
    ) -> Bool {
        let targetingParameters = AMTargetingParameters()

        var customKeywordsAsStrings: [String : String]? = nil
        if let customKeywords1 = adView?.customKeywords {
            customKeywordsAsStrings = AMGlobal.convertCustomKeywordsAsMap(
                toStrings: customKeywords1,
                withSeparatorString: ",")
        }


        targetingParameters.customKeywords = customKeywordsAsStrings
        targetingParameters.age = adView?.age
        targetingParameters.externalUid = adView?.externalUid
        targetingParameters.gender = adView?.gender
        targetingParameters.location = adView?.location
        targetingParameters.idforadvertising = AMAdvertisingIdentifier()

        //
        if (adView is AMBannerAdView) {
            if let bannerAdapter = currentAdapter as? AMCustomAdapterBanner {
                markLatencyStart()
                startTimeout()
                let banner = adView as? AMBannerAdView
                bannerAdapter.requestAd(with: size, rootViewController: banner?.rootViewController, serverParameter: parameterString,
                adUnitId: idString, targetingParameters: targetingParameters)
                return true
            }
        } else if (adView is AMInterstitialAd) {
            if let interstitialAdapter = currentAdapter as? AMCustomAdapterInterstitial {
                markLatencyStart()
                startTimeout()
                interstitialAdapter.requestAd(
                withParameter: parameterString,
                adUnitId: idString,
                targetingParameters: targetingParameters)
                return true
            }
        } else if (adView is AMRewardedAd) {
            if let rewardedAdapter = currentAdapter as? AMCustomAdapterRewarded {
                markLatencyStart()
                startTimeout()
                rewardedAdapter.requestAd(
                    withParameter: parameterString,
                    adUnitId: idString,
                    targetingParameters: targetingParameters)
                return true
            }
        } else {
            AMLogError("UNRECOGNIZED Entry Point classname.  \(type(of: adView))" )
        }
        // executes iff request was unsuccessful
        return false
    }

// MARK: - AMCustomAdapterBannerDelegate
    func didLoadBannerAd(_ view: UIView?) {
        didReceiveAd(view)
    }

// MARK: - AMCustomAdapterInterstitialDelegate
    func didLoadInterstitialAd(_ adapter: AMCustomAdapterInterstitial?) {
        didReceiveAd(adapter)
    }
    
// MARK: - AMCustomAdapterRewardedDelegate
    func didLoadRewardedAd(_ adapter: AMCustomAdapterRewarded?) {
        didReceiveAd(adapter)
    }
    
    func adRewarded(_ item: AMRewardedItem) {
        if let fetcher = adFetcher {
            fetcher.fireRewardedItem(item)
        }
    }

// MARK: - AMCustomAdapterDelegate
    func didFail(toLoadAd errorCode: AMAdResponseCode) {
        didFail(toReceiveAd: errorCode)
    }

    func adWasClicked() {
        if hasFailed { return }
        DispatchQueue.main.async {
            self.adViewDelegate?.adWasClicked()
        }
    }

    func willPresentAd() {
        if hasFailed { return }
        DispatchQueue.main.async {
            self.adViewDelegate?.adWillPresent()
        }
    }

    func didPresentAd() {
        if hasFailed { return }
        DispatchQueue.main.async {
            self.adViewDelegate?.adDidPresent()
        }
    }

    func willCloseAd() {
        if hasFailed { return }
        DispatchQueue.main.async {
            self.adViewDelegate?.adWillClose()
        }
    }

    func didCloseAd() {
        if hasFailed { return }
        DispatchQueue.main.async {
            self.adViewDelegate?.adDidClose()
        }
    }

    func willLeaveApplication() {
        if hasFailed { return }
        DispatchQueue.main.async {
            self.adViewDelegate?.adWillLeaveApplication()
        }
    }

    func failedToDisplayAd() {
        if hasFailed { return }
        DispatchQueue.main.async {
             (self.adViewDelegate as? AMInterstitialAdViewInternalDelegate)?.adFailedToDisplay()
        }
    }

// MARK: - helper methods
    func checkIfHasResponded() -> Bool {
        // we received a callback from mediation adaptor, cancel timeout
        cancelTimeout()
        // don't succeed or fail more than once per mediated ad
        return hasSucceeded || hasFailed
    }

    func didReceiveAd(_ adObject: Any?) {
        var adObject = adObject
        if checkIfHasResponded() {
            return
        }

        if adObject == nil {
            didFail(toReceiveAd: .amAdResponseInternalError)
            return
        }

        //
        hasSucceeded = true
        markLatencyStop()

        AMLogDebug("received an ad from the adapter")

        if (adObject is UIView) {
            let adView = adObject as? UIView
            let containerView = AMMediationContainerView(mediatedView: adView)
            containerView.controller = self
            adObject = containerView
        }

        finish(.amAdResponseSuccessful, withAdObject: adObject)

    }

    func didFail(toReceiveAd errorCode: AMAdResponseCode) {

        if checkIfHasResponded() {
            return
        }
        markLatencyStop()
        hasFailed = true
        finish(errorCode, withAdObject: nil)
    }

    func finish(_ errorCode: AMAdResponseCode, withAdObject adObject: Any?) {
        // use queue to force return
        DispatchQueue.main.async {
            let fetcher = self.adFetcher

            let responseURL = self.mediatedAd?.responseURL?.anResponseTrackerReasonCode(
                errorCode.rawValue,
                latency: TimeInterval((self.getLatency() * 1000)))

            // fireResponseURL will clear the adapter if fetcher exists
            if fetcher == nil {
                self.clearAdapter()
            }
            if errorCode != .amAdResponseSuccessful || adObject != nil {
                fetcher?.fireResponseURL(responseURL, reason: errorCode, adObject: adObject)
            }
        }
    }

// MARK: - Timeout handler

    func cancelTimeout() {

        timeoutCanceled = true
    }

// MARK: - Latency Measurement

    /// Should be called immediately after mediated SDK returns
    /// from `requestAd` call.
    func markLatencyStart() {

        latencyStart = Date.timeIntervalSinceReferenceDate
    }

    /// Should be called immediately after mediated SDK
    /// calls either of `onAdLoaded` or `onAdFailed`.
    func markLatencyStop() {

        latencyStop = Date.timeIntervalSinceReferenceDate
    }

    /// The latency of the call to the mediated SDK.
    func getLatency() -> TimeInterval {

        if (latencyStart > 0) && (latencyStop > 0) {
            return latencyStop - latencyStart
        }
        // return -1 if invalid.
        return -1
    }

    deinit {

        clearAdapter()
    }
}
