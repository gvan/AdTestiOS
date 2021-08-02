//
//  AMUniversalAdFetcher.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation
import CoreGraphics

// MARK: -

@objc class AMUniversalAdFetcher: AMAdFetcherBase, AMVideoAdProcessorDelegate, AMAdWebViewControllerLoadingDelegate, AMNativeRenderingViewControllerLoadingDelegate {
    
    private var adView: AMMRAIDContainerView?
    private var nativeAdView: AMNativeRenderingViewController?
    private var mediationController: AMMediationAdViewController?
    private var nativeMediationController: AMNativeMediatedAdController?
//    private var ssmMediationController: AMSSMMediationAdViewController?
    private var autoRefreshTimer: Timer?
    
    convenience init(delegate: Any?) {
        self.init()
        self.delegate = delegate
    }

    func startAutoRefreshTimer() {
        if autoRefreshTimer == nil {
            AMLogDebug("fetcher_stopped")
        } else if autoRefreshTimer?.anIsScheduled() ?? false {
            AMLogDebug("AutoRefresh timer already scheduled.")
        } else {
            autoRefreshTimer?.anScheduleNow()
        }
    }

    // NB  Invocation of this method MUST ALWAYS be followed by invocation of startAutoRefreshTimer.
    //
    override func restartAutoRefreshTimer() {
        // stop old autoRefreshTimer
        stopAutoRefreshTimer()

        // setup new autoRefreshTimer if refresh interval positive
        let interval = getAutoRefreshFromDelegate()
        if interval > 0.0 {
            autoRefreshTimer = Timer(timeInterval: interval, target: self,
                selector: #selector(autoRefreshTimerDidFire(_:)), userInfo: nil, repeats: false)
        }
    }

    func stopAutoRefreshTimer() {
        autoRefreshTimer?.invalidate()
        autoRefreshTimer = nil
    }

    func getWebViewSize(forCreativeWidth width: Int, andHeight height: Int) -> CGSize {

        // Compare the size of the received impression with what the requested ad size is. If the two are different, send the ad delegate a message.
        let receivedSize = CGSize(width: CGFloat(Float(width)), height: CGFloat(Float(height)))
        let requestedSize = getAdSizeFromDelegate()

        let receivedRect = CGRect(x: CGPoint.zero.x, y: CGPoint.zero.y, width: receivedSize.width, height: receivedSize.height)
        let requestedRect = CGRect(x: CGPoint.zero.x, y: CGPoint.zero.y, width: requestedSize.width, height: requestedSize.height)

        if !requestedRect.contains(receivedRect) {
            let w1 = Int(receivedRect.size.width)
            let h1 = Int(receivedRect.size.height)
            let w2 = Int(requestedRect.size.width)
            let h2 = Int(requestedRect.size.height)
            AMLogInfo("adsize_too_big \(w1)X\(h1) VS \(w2)X\(h2)")
            if let delegate = self.delegate as? AMUniversalAdFetcherDelegate {
                if delegate.getAdFormat?() == .interstitial || delegate.getAdFormat?() == .rewarded {
                    return requestedSize
                }
            }
        }

        let sizeOfCreative = ((receivedSize.width > 0) && (receivedSize.height > 0))
            ? receivedSize
            : requestedSize

        return sizeOfCreative
    }

    

// MARK: Lifecycle.

    deinit {
        stopAdLoad()
        NotificationCenter.default.removeObserver(self)
    }

    override func clearMediationController() {
        /*
             * Ad fetcher gets cleared, in the event the mediation controller lives beyond the ad fetcher.  The controller maintains a weak reference to the
             * ad fetcher delegate so that messages to the delegate can proceed uninterrupted.  Currently, the controller will only live on if it is still
             * displaying inside a banner ad view (in which case it will live on until the individual ad is destroyed).
             */
        mediationController = nil

        nativeMediationController = nil
    }

// MARK: - Ad Request
    override func stopAdLoad() {
        super.stopAdLoad()
        clearMediationController()
        stopAutoRefreshTimer()

    }

// MARK: - Ad Response
    override func finishRequestWithError(_ error: Error?, andAdResponseInfo adResponseInfo: AMAdResponseInfo?) {
        isFetcherLoading = false

        let interval = getAutoRefreshFromDelegate()
        let errString = error?.localizedDescription ?? "error"
        if interval > 0.0 {
            AMLogInfo("No ad received. Will request ad in \(interval) seconds. Error: \(errString)")
        } else {
            AMLogInfo("No ad received. Error: \(errString)")
        }

        var response: AMAdFetcherResponse? = nil
        if let error = error {
            response = AMAdFetcherResponse(error: error)
        }
        response?.adResponseInfo = adResponseInfo
        processFinalResponse(response)
    }

    override func processFinalResponse(_ response: AMAdFetcherResponse?) {
        ads = []
        isFetcherLoading = false
        guard let response = response else { return }
        // MAR case.
        //
        if fetcherMARManager != nil {
            if !(response.successful) {
                fetcherMARManager?.internalMultiAdRequestDidFailWithError(response.error)
            } else {
                AMLogError("MultiAdRequest manager SHOULD NEVER CALL processFinalResponse, except on error.")
            }

            return
        }


        // AdUnit case.
        if let fetcherDelegate  = delegate as? AMUniversalTagRequestBuilderFetcherDelegate {
            fetcherDelegate.universalAdFetcher?(self, didFinishRequestWith: response)
        }
        
        if (response.adObject is AMMRAIDContainerView) {
            if (response.adObject as? AMMRAIDContainerView)?.isBannerVideo ?? false {
                stopAutoRefreshTimer()
                return
            }
        }
//        restartAutoRefreshTimer()
        startAutoRefreshTimer()
    }
    
    override func processRewardedItem(_ rewardedItem: AMRewardedItem) {
        if let fetcherDelegate = delegate as? AMUniversalTagRequestBuilderFetcherDelegate {
            fetcherDelegate.adRewarded?(rewardedItem)
        }
    }

    //NB  continueWaterfall is co-functional the ad handler methods.
    //    The loop of the waterfall lifecycle is managed by methods calling one another
    //      until a valid ad object is found OR when the waterfall runs out.
    //
    override func continueWaterfall() {
        // stop waterfall if delegate reference was lost
        if delegate == nil {
            isFetcherLoading = false
            return
        }

        if self.ads.isEmpty {
            AMLogWarn("response_no_ads")
            if noAdUrl != nil {
                AMLogDebug("(no_ad_url, \(String(describing: noAdUrl))")
                AMTrackerManager.fireTrackerURL(noAdUrl)
            }
            finishRequestWithError(AMError("response_no_ads", AMAdResponseCode.amAdResponseUnableToFill.rawValue), andAdResponseInfo: nil)
            return
        }


        //
        let nextAd = ads.first
        ads.remove(at: 0)

        adObjectHandler = nextAd

        if let rtbVideoAd = nextAd as? AMRTBVideoAd { handle(rtbVideoAd)}
        else if let csmVideoAd  = nextAd as? AMCSMVideoAd {handle(csmVideoAd)}
        else if let standardAd = nextAd as? AMStandardAd {handle(standardAd)}
        else if let mediatedAd = nextAd as? AMMediatedAd {handleCSMSDKMediatedAd(mediatedAd)}
//        else if let nativeAd = nextAd as? AMNativeStandardAdResponse {handleNativeAd(nativeAd)}
        else {
            AMLogError("Implementation error: Unknown ad in ads waterfall.  (class=\(type(of: nextAd))" )
        }
    }

// MARK: - Auto refresh timer.

    @objc func autoRefreshTimerDidFire(_ timer: Timer?) {
        stopAdLoad()
        requestAd()
    }

    func getAutoRefreshFromDelegate() -> TimeInterval {
        if let delegate = self.delegate as? AMUniversalAdFetcherDelegate{
            return delegate.autoRefreshInterval?(for: self) ?? 0.0
        }

        return 0.0
    }

// MARK: - Ad handlers.

    // VAST ad.
    //
    func handle(_ videoAd: AMRTBVideoAd?) {
        if videoAd?.assetURL == nil && videoAd?.content == nil {
            continueWaterfall()
        }

        let notifyUrlString = videoAd?.notifyUrlString

        if (notifyUrlString?.count ?? 0) > 0 {
            AMLogDebug("(notify_url, \(String(describing: notifyUrlString)))")
            AMTrackerManager.fireTrackerURL(notifyUrlString)
        }

        var videoAdType: AMVideoAdSubtype = .unknown
        if let delegate = self.delegate as? AMUniversalAdFetcherDelegate {
            if let video = delegate.videoAdType?(for: self) {
                videoAdType = video
            }
        }

        if .bannerVideo == videoAdType {
            let sizeOfWebView = getWebViewSize(forCreativeWidth: videoAd?.width ?? 0, andHeight: videoAd?.height ?? 0)

            adView = AMMRAIDContainerView(
                size: sizeOfWebView,
                videoXML: videoAd?.content,
                skipOffset: videoAd?.skipOffset)

            adView?.loadingDelegate = self
            // Allow AMJAM events to always be passed to the AMAdView
            adView?.webViewController?.adViewAMJAMDelegate = delegate as? AMAdViewInternalDelegate
        } else {
            if let videoAd = videoAd {
                _ = AMVideoAdProcessor(delegate: self, withAdVideoContent: videoAd)
            }
        }
    }

    // Video ad.
    //
    func handle(_ videoAd: AMCSMVideoAd) {
        _ = AMVideoAdProcessor(delegate: self, withAdVideoContent: videoAd)
    }

    func handle(_ standardAd: AMStandardAd?) {
        let sizeofWebView = getWebViewSize(
            forCreativeWidth: standardAd?.width ?? 0,
            andHeight: standardAd?.height ?? 0)

        if adView != nil {
            adView?.loadingDelegate = nil
        }

        adView = AMMRAIDContainerView(
            size: sizeofWebView,
            html: standardAd?.content,
            webViewBaseURL: URL(string: AMSDKSettings.sharedInstance.baseUrlConfig.webViewBaseUrl()))
        adView?.loadingDelegate = self
        // Allow AMJAM events to always be passed to the AMAdView
        adView?.webViewController?.adViewAMJAMDelegate = delegate as? AMAdViewInternalDelegate

    }

    func handleCSMSDKMediatedAd(_ mediatedAd: AMMediatedAd?) {
        mediationController = AMMediationAdViewController.initMediatedAd(
            mediatedAd,
            with: self,
            adViewDelegate: delegate as? AMUniversalAdFetcherDelegate)
    }

    func handleNativeAd(_ nativeAd: AMNativeStandardAdResponse?) {
        var enableNativeRendering = false
        if let delegate = self.delegate as? AMUniversalAdFetcherDelegate {
            if let val = delegate.enableNativeRendering?() {
                enableNativeRendering = val
            }
            
            if ((nativeAd?.nativeRenderingUrl?.count ?? 0) > 0) && enableNativeRendering {
                let rtnNativeAdResponse = AMRTBNativeAdResponse()
                rtnNativeAdResponse.nativeAdResponse = nativeAd
                renderNativeAd(rtnNativeAdResponse)
                return
            }
        }
        // Traditional native ad instance.
        traditionalNativeAd(nativeAd)

    }

    func traditionalNativeAd(_ nativeAd: AMNativeStandardAdResponse?) {
        var fetcherResponse: AMAdFetcherResponse? = nil
        if let nativeAd = nativeAd {
            fetcherResponse = AMAdFetcherResponse(adObject: nativeAd, andAdObjectHandler: nil)
        }
        processFinalResponse(fetcherResponse)

    }

    func renderNativeAd(_ nativeRenderingElement: AMBaseAdObject?) {

        let sizeofWebView = getAdSizeFromDelegate()


        if nativeAdView != nil {
            nativeAdView = nil
        }

        nativeAdView = AMNativeRenderingViewController(size: sizeofWebView, baseObject: nativeRenderingElement)
        nativeAdView?.loadingDelegate = self
    }

    func didFailToLoadNativeWebViewController() {
        if (adObjectHandler is AMNativeStandardAdResponse) {
            let nativeStandardAdResponse = adObjectHandler as? AMNativeStandardAdResponse
            traditionalNativeAd(nativeStandardAdResponse)
        } else {
            let error = AMError("AMAdWebViewController is UNDEFINED.", AMAdResponseCode.amAdResponseInternalError.rawValue)
            let fetcherResponse = AMAdFetcherResponse(error: error)
            processFinalResponse(fetcherResponse)
        }
    }

    @objc func didCompleteFirstLoad(fromNativeWebViewController controller: AMNativeRenderingViewController?) {
        var fetcherResponse: AMAdFetcherResponse? = nil

        if nativeAdView == controller {
            if let controller = controller {
                fetcherResponse = AMAdFetcherResponse(adObject: controller, andAdObjectHandler: adObjectHandler)
            }
            processFinalResponse(fetcherResponse)
        } else {
            didFailToLoadNativeWebViewController()
        }
    }

// MARK: - AMUniversalAdFetcherDelegate.
    func getAdSizeFromDelegate() -> CGSize {
        if let delegate = self.delegate as? AMUniversalAdFetcherDelegate {
            return delegate.requestedSize(for: self)
        }
        return CGSize.zero
    }

// MARK: - AMAdWebViewControllerLoadingDelegate.
    @objc func didCompleteFirstLoad(from controller: AMAdWebViewController?) {
        var fetcherResponse: AMAdFetcherResponse? = nil

        if adView?.webViewController == controller {
            if controller?.videoAdOrientation != nil {
                if let delegate = self.delegate as? AMUniversalAdFetcherDelegate{
                    if let videoAdOrientation1 = controller?.videoAdOrientation {
                        delegate.setVideoAdOrientation?(videoAdOrientation1)
                    }
                }
            }
            if let adView = adView {
                fetcherResponse = AMAdFetcherResponse(adObject: adView, andAdObjectHandler: adObjectHandler)
            }
        } else {
            let error = AMError("AMAdWebViewController is UNDEFINED.", AMAdResponseCode.amAdResponseInternalError.rawValue)
            fetcherResponse = AMAdFetcherResponse(error: error)
        }

        processFinalResponse(fetcherResponse)
    }

    @objc func immediatelyRestartAutoRefreshTimer(from controller: AMAdWebViewController?) {
        autoRefreshTimerDidFire(nil)

    }

    @objc func stopAutoRefreshTimer(from controller: AMAdWebViewController?) {
        stopAutoRefreshTimer()
    }

// MARK: - AMVideoAdProcessor delegate
    @objc func videoAdProcessor(_ videoProcessor: AMVideoAdProcessor, didFinishVideoProcessing adVideo: AMVideoAdPlayer) {
        DispatchQueue.main.async{
            let adFetcherResponse = AMAdFetcherResponse(adObject: adVideo, andAdObjectHandler: self.adObjectHandler)
            self.processFinalResponse(adFetcherResponse)
        }
    }

    @objc func videoAdProcessor(_ videoAdProcessor: AMVideoAdProcessor, didFailVideoProcessing error: Error) {
        continueWaterfall()
    }

}
