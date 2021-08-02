//
//  AMAdFetcherBase.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation

@objc protocol AMRequestTagBuilderCore: AnyObject {
    // customKeywords is shared between the adunits and the fetcher.
    //
    // NB  This definition of customKeywords should not be confused with the public facing AMTargetingParameters.customKeywords
    //       which is shared between fetcher and the mediation adapters.
    //     The version here is a dictionary of arrays of strings, the public facing version is simply a dictionary of strings.
    //
    var customKeywords: [String : [String]]? { get set }
}

protocol AMMultiAdProtocol: AnyObject {
    var marManager: AMMultiAdRequest? { get set }
    /// This property is only used with AMMultiAdRequest.
    /// It associates a unique identifier with each adunit per request, allowing ad objects in the UT Response to be
    /// matched with adunit elements of the UT Request.
    /// NB  This value is updated for each UT Request.  It does not persist across the lifecycle of the instance.
    var utRequestUUIDString: String { get set }
    /// Used only in MultiAdRequest to pass ad object returned by impbus directly to the adunit though it was requested by MAR UT Request.
    func ingestAdResponseTag(_ tag: Any)
}

class AMAdFetcherBase: NSObject {
    var ads: [AMBaseAdObject] = []
    var noAdUrl: String?
    var isFetcherLoading = false
    var adObjectHandler: AMBaseAdObject?
//    weak var delegate: AMUniversalTagRequestBuilderFetcherDelegate?
    var delegate: Any?
    weak var fetcherMARManager: AMMultiAdRequest?
    weak var adunitMARManager: AMMultiAdRequest?

    //
    override init() {
        super.init()

        //
        setup()
    }

    convenience init(delegate: AMUniversalTagRequestBuilderFetcherDelegate, andAdUnitMultiAdRequestManager adunitMARManager: AMMultiAdRequest) {
        self.init()

        //
        self.delegate = delegate
        self.adunitMARManager = adunitMARManager
    }

    convenience init(multiAdRequestManager marManager: AMMultiAdRequest) {
        self.init()

        //
        fetcherMARManager = marManager
    }

    func setup() {
        let canAccess = AMGDPRSettings.canAccessDeviceData
        HTTPCookieStorage.shared.cookieAcceptPolicy = canAccess ? .always : .never
    }

    func requestAd() {
        if isFetcherLoading { return }

        //
        let urlString = AMSDKSettings.sharedInstance.baseUrlConfig.utAdRequestBaseUrl()
        var req: URLRequest? = nil

        if let fetcherMARManager = fetcherMARManager {
            req = AMUniversalTagRequestBuilder.buildRequest(withMultiAdRequestManager: fetcherMARManager, baseUrlString: urlString ?? "")
        } else {
            
            if let delegate = delegate as? AMUniversalTagRequestBuilderFetcherDelegate {
                if let adunitMARManager = adunitMARManager {
                    req = AMUniversalTagRequestBuilder.buildRequest(withAdFetcherDelegate: delegate, adunitMultiAdRequestManager: adunitMARManager, baseUrlString: urlString ?? "")
                } else {
                    req = AMUniversalTagRequestBuilder.buildRequest(withAdFetcherDelegate: delegate, baseUrlString: urlString ?? "")
                }
            }
        }

        guard let request = req else {
            if fetcherMARManager != nil {
                let sessionError = AMError("multi_ad_request_failed %@", AMAdResponseCode.amAdResponseNetworkError.rawValue)
                AMLogError("\(sessionError)")

                let response = AMAdFetcherResponse(error: sessionError)
                processFinalResponse(response)
            }

            return
        }


        //
        var requestContent: String? = nil
        if let http = request.httpBody {
            requestContent = "\(urlString ?? "") /n \(String(data: http, encoding: .utf8) ?? "")"
        }

        var requestAdTask: URLSessionDataTask? = nil


        AMPostNotifications(
            kAMUniversalAdFetcherWillRequestAdNotification,
            self,
            [
                kAMUniversalAdFetcherAdRequestURLKey: requestContent ?? ""
            ])

        requestAdTask = URLSession.shared.dataTask(with: request, completionHandler: {[weak self] data, response, error in
            guard let self = self else { return }
            
            var statusCode = -1
            if self.fetcherMARManager == nil { self.restartAutoRefreshTimer() }

            if (response is HTTPURLResponse) {
                let httpResponse = response as? HTTPURLResponse
                statusCode = httpResponse?.statusCode ?? 0
            }

            if statusCode >= 400 || statusCode == -1 {
                self.isFetcherLoading = false

                DispatchQueue.main.async(execute: {
                    var sessionError: Error? = nil

                    if self.fetcherMARManager != nil {
                        sessionError = AMError("multi_ad_request_failed %@", AMAdResponseCode.amAdResponseNetworkError.rawValue)
                    } else {
                        sessionError = AMError("ad_request_failed %@", AMAdResponseCode.amAdResponseNetworkError.rawValue)
                    }
                    AMLogError(sessionError?.localizedDescription ?? "unknown error")

                    var response: AMAdFetcherResponse? = nil
                    if let sessionError = sessionError {
                        response = AMAdFetcherResponse(error: sessionError)
                    }
                    self.processFinalResponse(response)
                })
            } else {
                self.isFetcherLoading = true

                DispatchQueue.main.async(execute: {
                    var responseString: String? = nil
                    
                    if let data = data {
                        responseString = String(data: data, encoding: .utf8)
                    }
                    if self.fetcherMARManager == nil {
                        AMLogDebug("Response JSON (for single tag requests ONLY)... \(String(describing: responseString))")
                    }

                    AMPostNotifications(
                        kAMUniversalAdFetcherDidReceiveResponseNotification,
                        self,
                        [
                            kAMUniversalAdFetcherAdResponseKey: (responseString ?? "")
                        ])

                    self.handleAdServerResponse(data!)
                })
                // ENDIF -- statusCode
            }
        })

        requestAdTask?.resume()
    }

    func stopAdLoad() {
        isFetcherLoading = false
        ads = []
    }

    func fireResponseURL(_ urlString: String?, reason: AMAdResponseCode, adObject: Any) {
        if urlString != nil {
            AMTrackerManager.fireTrackerURL(urlString)
        }

        if reason == .amAdResponseSuccessful {
            let response = AMAdFetcherResponse(adObject: adObject, andAdObjectHandler: adObjectHandler)
            processFinalResponse(response)
        } else {
            AMLogError("FAILED with reason=\(reason)")

            // mediated ad failed. clear mediation controller
            clearMediationController()

            // stop waterfall if delegate reference (adview) was lost
            if delegate == nil {
                isFetcherLoading = false
                return
            }

            continueWaterfall()
        }
    }
    
    func fireRewardedItem(_ rewardedItem: AMRewardedItem) {
        processRewardedItem(rewardedItem)
    }

    /// Accept a single tag from an UT Response.
    /// Divide the tag into ad objects and begin to process them via the waterfall.
    func prepareForWaterfall(withAdServerResponseTag tag: AMResponseTag?) {
        guard let tag = tag else {
            finishRequestWithError(AMError("response_no_ads", AMAdResponseCode.amAdResponseUnableToFill.rawValue), andAdResponseInfo: nil)
            return
        }
        if tag.nobid {
            AMLogWarn("response_no_ads")

            let adResponseInfo = AMAdResponseInfo()

            adResponseInfo.placementId = tag.tagId

            finishRequestWithError(AMError("response_no_ads", AMAdResponseCode.amAdResponseUnableToFill.rawValue), andAdResponseInfo: adResponseInfo)
            return
        }

        //
        let anyAds: [Any] =  AMUniversalTagAdServerResponse.generateAdObjectInstance(fromJSONAdServerResponseTag: tag)
        var ads: [AMBaseAdObject] = anyAds.compactMap{ $0 as? AMBaseAdObject }

        if ads.count <= 0 {
            AMLogWarn("response_no_ads")
            finishRequestWithError(AMError("response_no_ads", AMAdResponseCode.amAdResponseUnableToFill.rawValue), andAdResponseInfo: nil)
            return
        }

        if let noAdURLString = tag.noAdUrl, !noAdURLString.isEmpty {
            noAdUrl = noAdURLString
        }

        //
        beginWaterfall(withAdObjects: &ads)
    }

    func beginWaterfall(withAdObjects ads: inout [AMBaseAdObject]) {
        self.ads = ads

        clearMediationController()
        continueWaterfall()
    }
    
    func restartAutoRefreshTimer() {
        // Implemented only by AMUniversalAdFetcher
    }
    func processFinalResponse(_ response: AMAdFetcherResponse?) {
        AMLogDebug("processFinalResponse : use implementation")
    }
    func processRewardedItem(_ rewardedItem: AMRewardedItem) {
    }
    func finishRequestWithError(_ error: Error, andAdResponseInfo adResponseInfo: AMAdResponseInfo?) {
    }
    func continueWaterfall() {
    }
    func clearMediationController() {
    }

// MARK: Lifecycle.

// MARK: - Response processing methods.

    /// Start with raw data from a UT Response.
    /// Transform the data into an array of dictionaries representing UT Response tags.
    ///
    /// If the fetcher is called by an ad unit, the process the tag with the existing fetcher.
    /// If the fetcher is called in Multi-Ad Request Mode, then process each tag with fetcher from the ad unit that generated the tag.
    func handleAdServerResponse(_ data: Data) {
        var dataReceived : AMResponseModel
        do {
                
            dataReceived = try JSONDecoder().decode(AMResponseModel.self, from: data)
        } catch let jsonErr {
            
            let err = AMError("Failed to serialize response json", 0)
            let errRresponse = AMAdFetcherResponse(error: err)
            self.processFinalResponse(errRresponse)
            
            AMLogError("Failed to serialize json: \(jsonErr)")
            return
        }
        

        if fetcherMARManager == nil {
            // If the UT Response is for a single adunit only, there should only be one ad object.
            //
            if dataReceived.tags.count > 1 {
                AMLogWarn("Response contains MORE THAN ONE TAG \(dataReceived.tags.count).  Using FIRST TAG ONLY and ignoring the rest...")
            }

            prepareForWaterfall(withAdServerResponseTag: dataReceived.tags.first)
            return
        } else {
            handleAdServerResponse(forMultiAdRequest: dataReceived.tags)
        }
    }

    func handleAdServerResponse(forMultiAdRequest arrayOfTags: [AMResponseTag]?) {
        // Multi-Ad Request Mode.
        //
        guard let arrayOfTags = arrayOfTags else { return }
        if arrayOfTags.isEmpty {
            let value = AMAdResponseCode.amAdResponseUnableToFill.rawValue
            let responseError = AMError("multi_ad_request_failed", value)
            fetcherMARManager?.internalMultiAdRequestDidFailWithError(responseError)
            return
        }

        fetcherMARManager?.internalMultiAdRequestDidComplete()

        // Process each ad object in turn, matching with adunit via UUID.
        //
        if fetcherMARManager?.countOfAdUnits() != arrayOfTags.count {
            AMLogWarn(
                "Number of tags in UT Response (%@) DOES NOT MATCH number of ad units in MAR instance (%@).",
                NSNumber(value: arrayOfTags.count),
                NSNumber(value: fetcherMARManager?.countOfAdUnits() ?? 0))
        }

        for tag in arrayOfTags {
            let uuid = tag.uuid
            let adunit = fetcherMARManager?.internalGetAdUnit(byUUID: uuid ?? "")
            (adunit as? AMMultiAdProtocol)?.ingestAdResponseTag(tag)
        }
    }
}
