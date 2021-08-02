//
//  AMNativeMediatedAdController.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation
class AMNativeMediatedAdController: NSObject, AMNativeCustomAdapterRequestDelegate {
    // Designated initializer
    class func initMediatedAd(_ mediatedAd: AMMediatedAd?,  with adFetcher: AMNativeAdFetcher?, adRequest adRequestDelegate: AMNativeAdFetcherDelegate?) -> AMNativeMediatedAdController? {
        let controller = AMNativeMediatedAdController(withMediatedAd: mediatedAd, with: adFetcher, adRequest: adRequestDelegate)
        guard controller.initializeRequest() else { return nil }
        return controller
    }

    private var mediatedAd: AMMediatedAd?
    private var currentAdapter: AMNativeCustomAdapter?
    private var hasSucceeded = false
    private var hasFailed = false
    private var timeoutCanceled = false
    // variables for measuring latency.
    private var latencyStart: TimeInterval = 0.0
    private var latencyStop: TimeInterval = 0.0
    private weak var adFetcher: AMNativeAdFetcher?
    private weak var adRequestDelegate: AMNativeAdFetcherDelegate?

    init(withMediatedAd mediatedAd: AMMediatedAd?, with adFetcher: AMNativeAdFetcher?, adRequest adRequestDelegate: AMNativeAdFetcherDelegate?) {
        super.init()
        self.adFetcher = adFetcher
        self.adRequestDelegate = adRequestDelegate
        self.mediatedAd = mediatedAd
    }

    func initializeRequest() -> Bool {
        var className: String = ""

        guard let mediatedAd = self.mediatedAd else {
            handleInstantiationFailure(className, errorCode: .amAdResponseUnableToFill, errorInfo: "null mediated ad object")
            return false
        }

        className = mediatedAd.className ?? ""
        AMLogDebug("instantiating_class \(String(describing: className))")

        AMPostNotifications(
            kAMUniversalAdFetcherWillInstantiateMediatedClassNotification,
            self,
            [kAMUniversalAdFetcherMediatedClassKey: className]
        )
        guard let adClass = NSClassFromString(className) as? AMNativeCustomAdapter.Type else {
            handleInstantiationFailure(className, errorCode: .amAdResponseMediatedSDKUnavailable, errorInfo: "ClassNotFoundError")
            return false
        }

        let adInstance = adClass.init()
        guard validAdInstance(adInstance) else {
            handleInstantiationFailure(className, errorCode: .amAdResponseMediatedSDKUnavailable, errorInfo: "InstantiationError")
            return false
        }

//         instance valid - request a mediated ad
        let adapter = adInstance as? AMNativeCustomAdapter
        adapter?.requestDelegate = self
        self.currentAdapter = adapter

        markLatencyStart()
        startTimeout()

       self.currentAdapter?.requestNativeAd(
            withServerParameter: mediatedAd.param,
            adUnitId: mediatedAd.adId,
            targetingParameters: targetingParameters()
        )
        
        return true
    }

    func validAdInstance(_ adInstance: Any?) -> Bool {
        guard let instance =  adInstance else { return false }
        guard instance is AMNativeCustomAdapter else { return false}
        return true
    }

    func handleInstantiationFailure(
        _ className: String?,
        errorCode: AMAdResponseCode,
        errorInfo: String?
    ) {
        if (errorInfo?.count ?? 0) > 0 {
            AMLogError("mediation_instantiation_failure \(errorInfo!)")
        }

        didFail(toReceiveAd: errorCode)
    }

    func setAdapter(_ adapter: AMNativeCustomAdapter?) {
        currentAdapter = adapter
    }

    func clearAdapter() {
        if currentAdapter != nil {
            currentAdapter?.requestDelegate = nil
        }
        currentAdapter = nil
        hasSucceeded = false
        hasFailed = true
        cancelTimeout()
        AMLogInfo("mediation_finish")
    }

    func targetingParameters() -> AMTargetingParameters? {
        let targetingParameters = AMTargetingParameters()

        var customKeywordsAsStrings: [String : String]? = nil
        if let customKeywords1 = adRequestDelegate?.customKeywords {
            customKeywordsAsStrings = AMGlobal.convertCustomKeywordsAsMap(
                toStrings: customKeywords1,
                withSeparatorString: ",")
        }

        targetingParameters.customKeywords = customKeywordsAsStrings
        targetingParameters.age = adRequestDelegate?.age
        targetingParameters.gender = adRequestDelegate?.gender
        targetingParameters.externalUid = adRequestDelegate?.externalUid
        targetingParameters.location = adRequestDelegate?.location
        targetingParameters.idforadvertising = AMAdvertisingIdentifier()

        return targetingParameters
    }

// MARK: - helper methods
    func checkIfHasResponded() -> Bool {
        // we received a callback from mediation adaptor, cancel timeout
        cancelTimeout()
        // don't succeed or fail more than once per mediated ad
        return hasSucceeded || hasFailed
    }

    func didReceiveAd(_ adObject: Any?) {
        if checkIfHasResponded() {
            return
        }
        if adObject == nil {
            didFail(toReceiveAd: .amAdResponseInternalError)
            return
        }
        hasSucceeded = true
        markLatencyStop()

        AMLogDebug("received an ad from the adapter")

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
        DispatchQueue.main.async{
            let responseURLString = self.createResponseURLRequest(
                self.mediatedAd?.responseURL,
                reason: errorCode.rawValue)

            // fireResulCB will clear the adapter if fetcher exists
            if self.adFetcher == nil {
                self.clearAdapter()
            }

            guard let adObject = adObject else { return }
            self.adFetcher?.fireResponseURL(responseURLString, reason: errorCode, adObject: adObject)
            
        }
    }

    func createResponseURLRequest(_ baseString: String?, reason reasonCode: Int) -> String? {
        if (baseString?.count ?? 0) < 1 {
            return ""
        }

        // append reason code
        var responseURLString = baseString?.anString(
            byAppendingUrlParameter: "reason",
            value: "\(reasonCode)")

        // append latency measurements
        let latency = TimeInterval(getLatency() * 1000) // secs to ms

        if latency > 0 {
            responseURLString = responseURLString?.anString(
                byAppendingUrlParameter: "latency",
                value: String(format: "%.0f", latency))
        }

        AMLogDebug("responseURLString=\(responseURLString ?? "")")
        return responseURLString
    }

// MARK: - Timeout handler
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

// MARK: - AMNativeCustomAdapterRequestDelegate
    func didLoadNativeAd(_ response: AMNativeMediatedAdResponse) {
        // Add the AdmixerImpression trackers into the mediated response.
        response.impTrackers = mediatedAd?.impressionUrls
        response.verificationScriptResource = mediatedAd?.verificationScriptResource
        didReceiveAd(response)
    }

    func didFail(toLoadNativeAd errorCode: AMAdResponseCode) {
        didFail(toReceiveAd: errorCode)
    }
}
