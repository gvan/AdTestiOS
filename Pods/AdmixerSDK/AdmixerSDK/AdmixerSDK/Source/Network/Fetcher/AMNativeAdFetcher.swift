//
//  AMNativeAdFetcher.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation

class AMNativeAdFetcher: AMAdFetcherBase {
    convenience init(delegate: AMUniversalTagRequestBuilderFetcherDelegate) {
        self.init()
            self.delegate = delegate
            setup()
    }

    private var nativeMediationController: AMNativeMediatedAdController?

    override func clearMediationController() {
        /*
             * Ad fetcher gets cleared, in the event the mediation controller lives beyond the ad fetcher.  The controller maintains a weak reference to the
             * ad fetcher delegate so that messages to the delegate can proceed uninterrupted.  Currently, the controller will only live on if it is still
             * displaying inside a banner ad view (in which case it will live on until the individual ad is destroyed).
             */
        nativeMediationController = nil

    }

// MARK: - UT ad response processing methods
    override func finishRequestWithError(_ error: Error, andAdResponseInfo adResponseInfo: AMAdResponseInfo?) {
        isFetcherLoading = false
        AMLogInfo("No ad received. Error: %@", error.localizedDescription)
        let response = AMAdFetcherResponse(error: error)
        response.adResponseInfo = adResponseInfo
        processFinalResponse(response)
    }

    override func processFinalResponse(_ response: AMAdFetcherResponse?) {
        ads = []
        isFetcherLoading = false
        guard let delegate = self.delegate as? AMNativeAdRequest else { return }
        guard let response = response else { return }
        
        delegate.didFinish(with: response)
    }

    //NB  continueWaterfall is co-functional the ad handler methods.
    //    The loop of the waterfall lifecycle is managed by methods calling one another
    //      until a valid ad object is found OR when the waterfall runs out.
    //
    override func continueWaterfall() {
        // stop waterfall if delegate reference (adview) was lost
        if delegate == nil {
            isFetcherLoading = false
            return
        }

        let adsLeft = ads.isEmpty

        if !adsLeft {
            AMLogWarn("response_no_ads")
            if noAdUrl != nil {
                AMLogDebug("(no_ad_url)")
                AMTrackerManager.fireTrackerURL(noAdUrl)
            }
            finishRequestWithError(AMError("response_no_ads", AMAdResponseCode.amAdResponseUnableToFill.rawValue), andAdResponseInfo: nil)
            return
        }


        //
        let nextAd = ads.first
        ads.remove(at: 0)

        adObjectHandler = nextAd


        if let mediatedAd = nextAd as? AMMediatedAd {
            handleCSMSDKMediatedAd(mediatedAd)
        } else /*if let standartAdResponse = nextAd as? AMNativeStandardAdResponse {
            handleNativeStandardAd(standartAdResponse)
        } else*/ {
            AMLogError("Implementation error: Unspported ad in native ads waterfall.  (class=\(type(of: nextAd))")
            continueWaterfall() // skip this ad an jump to next ad
        }
    }

    override func stopAdLoad() {
        super.stopAdLoad()
    }

    override func restartAutoRefreshTimer() {
        // Implemented only by AMUniversalAdFetcher
    }

// MARK: - Ad handlers.
    func handleCSMSDKMediatedAd(_ mediatedAd: AMMediatedAd?) {
        if mediatedAd?.isAdTypeNative ?? false {
            nativeMediationController = AMNativeMediatedAdController.initMediatedAd(
                mediatedAd,
                with: self,
                adRequest: delegate as? AMNativeAdFetcherDelegate)
        } else {
            // TODO: should do something here
        }
    }

    func handleNativeStandardAd(_ nativeStandardAd: AMNativeStandardAdResponse?) {

        var fetcherResponse: AMAdFetcherResponse? = nil
        if let nativeStandardAd = nativeStandardAd {
            fetcherResponse = AMAdFetcherResponse(adObject: nativeStandardAd, andAdObjectHandler: nil)
        }
        processFinalResponse(fetcherResponse)
    }
}

// MARK: - AMUniversalAdFetcherDelegate partitions.
protocol AMNativeAdFetcherDelegate: AMAdProtocolFoundation, AMRequestTagBuilderCore {
    func didFinish(with response: AMAdFetcherResponse)
    func internalGetUTRequestUUIDString() -> String
    func internalUTRequestUUIDStringReset()
}
