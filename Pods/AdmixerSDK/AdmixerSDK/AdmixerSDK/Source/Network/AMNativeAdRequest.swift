//
//  AMNativeAdRequest.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation
import UIKit

class AMNativeAdRequest: NSObject, AMNativeAdFetcherDelegate, AMUniversalTagRequestBuilderFetcherDelegate {
    var shouldLoadIconImage = false
    var shouldLoadMainImage = false
    
    var placementId: String?
    var inventoryCode: String?
    var reserve: CGFloat = 0.0
    var adType: AMAdType = .unknown
    var minDuration: Int = 0
    var maxDuration: Int = 0
    var shouldServePublicServiceAnnouncements: Bool = false
    var memberId: Int = 0
    var publisherId: Int = 0
    var contentId: String?
    var location: AMLocation?
    var age: String?
    var gender: AMGender = .unknown
    var externalUid: String?
    public var ortbObject: Data?
    var rendererId = 0
    weak var delegate: AMNativeAdRequestDelegate?
    private var adFetcher: AMNativeAdFetcher?
    private var allowedAdSizes: Set<NSValue>?
    private var allowSmallerSizes = false
    private weak var marManager: AMMultiAdRequest?
    private var utRequestUUIDString = ""
    var customKeywords: [String : [String]]? = [:]
// MARK: - AMNativeAdRequestProtocol properties.

    // AMNativeAdRequestProtocol properties.
    //
// MARK: - Lifecycle.
    override init() {
        super.init()
        setupSizeParametersAs1x1()
        utRequestUUIDString = anUUID
    }

    func setupSizeParametersAs1x1() {
        self.allowedAdSizes = Set([NSValue(cgSize: kAMAdSize1x1)])
        self.allowSmallerSizes = false
        self.rendererId = 0
    }

    func loadAd() {
        if delegate == nil {
            AMLogError("AMNativeAdRequestDelegate must be set on AMNativeAdRequest in order for an ad to begin loading")
            return
        }

        createAdFetcher()
        adFetcher?.requestAd()
    }

    ///  This method provides a single point of entry for the MAR object to pass tag content received in the UT Request to the fetcher defined by the adunit.
    ///  Adding this public method which is used only for an internal process is more desirable than making the universalAdFetcher property public.
    func ingestAdResponseTag(_ tag: AMResponseTag?) {
        if delegate == nil {
            AMLogError("AMNativeAdRequestDelegate must be set on AMNativeAdRequest in order for an ad to be ingested.")
            return
        }

        //
        createAdFetcher()

        adFetcher?.prepareForWaterfall(withAdServerResponseTag: tag)
    }

    func createAdFetcher() {
        if marManager != nil {
            if let marManager = marManager {
                adFetcher = AMNativeAdFetcher(delegate: self, andAdUnitMultiAdRequestManager: marManager)
            }
        } else {
            adFetcher = AMNativeAdFetcher(delegate: self)
        }
    }

// MARK: - AMNativeAdFetcherDelegate.
    @objc func didFinish(with response: AMAdFetcherResponse) {
        var error: Error? = nil

        if !response.successful {
            error = response.error
        } else if !(response.adObject is AMNativeAdResponse) {
            error = AMError("native_request_invalid_response", AMAdResponseCode.amAdResponseBadFormat.rawValue)
        }

        if error != nil {
            if let error = error {
                delegate?.adRequest(self, didFailToLoadWithError: error, with: response.adResponseInfo)
            }
            return
        }


        //
        weak var weakSelf = self
        guard  let nativeResponse = response.adObject as? AMNativeAdResponse else { return }
        
        // In case of Mediation

        let obj: AMBaseAdObject? = response.adObjectHandler
        if nativeResponse.adResponseInfo == nil {
            if let adResponseInfo = obj?.adResponseInfo {
                setAdResponseInfo(adResponseInfo, onObject: nativeResponse, forKeyPath: kAMAdResponseInfo)
            }
        }
            //
        if nativeResponse.creativeId == nil {
            let creativeId = obj?.creativeId
            setCreativeId(creativeId, onObject: nativeResponse, forKeyPath: kAMCreativeId)
        }

        //
        let backgroundQueue = DispatchQueue(label: #function)

        backgroundQueue.async(
            execute: {
                guard let strongSelf = weakSelf else { return }

                //
                var semaphoreMainImage: DispatchSemaphore? = nil
                var semaphoreIconImage: DispatchSemaphore? = nil

                if self.shouldLoadMainImage {
                    semaphoreMainImage = self.setImageInBackgroundForImageURL(
                        nativeResponse.mainImageURL,
                        onObject: nativeResponse,
                        forKeyPath: "mainImage")
                }

                if self.shouldLoadIconImage {
                    semaphoreIconImage = self.setImageInBackgroundForImageURL(
                        nativeResponse.iconImageURL,
                        onObject: nativeResponse,
                        forKeyPath: "iconImage")
                }

                _ = semaphoreMainImage?.wait(timeout: DispatchTime.distantFuture)
                _ = semaphoreIconImage?.wait(timeout: DispatchTime.distantFuture)

                DispatchQueue.main.async(execute: {
                    AMLogDebug("...END NSURL sessions.")
                    strongSelf.delegate?.adRequest(strongSelf, didReceive: nativeResponse)
                })
            })
    }

    func adAllowedMediaTypes() -> [Int] {
        return [AMAllowedMediaType.native.rawValue]
    }

    @objc func nativeAdRendererId() -> Int {
        return rendererId
    }

    func internalDelegateUniversalTagSizeParameters() -> [AnyHashable : Any] {
        var delegateReturnDictionary: [AnyHashable : Any] = [:]
        delegateReturnDictionary[AMInternalDelgateTagKeyPrimarySize] = NSValue(cgSize: kAMAdSize1x1)
        delegateReturnDictionary[AMInternalDelegateTagKeySizes] = allowedAdSizes
        delegateReturnDictionary[AMInternalDelegateTagKeyAllowSmallerSizes] = NSNumber(value: allowSmallerSizes)

        return delegateReturnDictionary
    }

    func internalGetUTRequestUUIDString() -> String {
        return utRequestUUIDString
    }

    func internalUTRequestUUIDStringReset() {
        utRequestUUIDString = anUUID
    }

    // NB  Some duplication between AMNativeAd* and the other entry points is inevitable because AMNativeAd* does not inherit from AMAdView.
    //
// MARK: - AMUniversalAdFetcherFoundationDelegate helper methods.
    func setCreativeId(_ creativeId: String?, onObject object: AMNativeAdResponse, forKeyPath keyPath: String?) {
        object.setValue(creativeId, forKeyPath: keyPath ?? "")
    }

    func setAdResponseInfo(_ adResponseInfo: AMAdResponseInfo?, onObject object: AMNativeAdResponse, forKeyPath keyPath: String?) {
        object.setValue(adResponseInfo, forKeyPath: keyPath ?? "")
    }

    // RETURN:  dispatch_semaphore_t    For first time image requests.
    //          nil                     When image is cached  -OR-  if imageURL is undefined.
    //
    // If semaphore is defined, call dispatch_semaphore_wait(semaphor, DISPATCH_TIME_FOREVER) to wait for this background task
    //   before continuing in the calling method.
    // Wait period is limited by NSURLRequest with timeoutInterval of kAdmixerNativeAdImageDownloadTimeoutInterval.
    //
    func setImageInBackgroundForImageURL(_ imageURL : URL?, onObject object: AMNativeAdResponse?, forKeyPath keyPath: String?) -> DispatchSemaphore? {
        guard let url = imageURL else { return nil }

        if let cachedImage = AMNativeAdImageCache.image(forURL: url) {
            object?.setValue(cachedImage, forKeyPath: keyPath ?? "")
            return nil
        }

        //
        let semaphore = DispatchSemaphore(value: 0)

        var request: URLRequest? = nil
        if let imageURL = imageURL {
            request = URLRequest(
                url: imageURL,
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: TimeInterval(kAdmixerNativeAdImageDownloadTimeoutInterval))
        }

        var task: URLSessionDataTask? = nil
        if let request = request {
            task = URLSession.shared.dataTask(
                with: request,
                completionHandler: { data, response, error in
                    AMLogDebug("BEGIN NSURL session...")

                    var statusCode = -1

                    if (response is HTTPURLResponse) {
                        let httpResponse = response as? HTTPURLResponse
                        statusCode = httpResponse?.statusCode ?? 0
                    }

                    if (statusCode >= 400) || (statusCode == -1) {
                        AMLogError("Error downloading image: \(String(describing: error))")
                    } else {
                        var image: UIImage? = nil
                        if let data = data {
                            image = UIImage(data: data)
                        }

                        if image != nil {
                            AMNativeAdImageCache.setImage(image, forURL: url)
                            object?.setValue(image, forKeyPath: keyPath ?? "")
                        }
                    }

                    semaphore.signal()
                })
        }
        task?.resume()

        //
        return semaphore
    }

// MARK: - AMNativeAdRequestProtocol methods.
    func setPlacementId(_ placementId: String?) {
        guard let placementId = placementId else {
            AMLogError("Could not set placementId to non-string value")
            return
        }
        if placementId.isEmpty { return }
        if placementId != self.placementId {
            AMLogDebug("Setting placementId to \(placementId)")
            self.placementId = placementId
        }
    }

    func setPublisherId(_ newPublisherId: Int) {
        if (newPublisherId > 0) && marManager != nil {
            if marManager?.publisherId != newPublisherId {
                AMLogError("Arguments ignored because newPublisherID \(newPublisherId) is not equal to publisherID used in Multi-Ad Request.")
                return
            }
        }

        AMLogDebug("Setting publisher ID to \(newPublisherId)")
        publisherId = newPublisherId
    }

    func setInventoryCode(_ newInvCode: String?, memberId newMemberId: Int) {
        let newInvCode = newInvCode
        if (newMemberId > 0) && marManager != nil {
            if marManager?.memberId != newMemberId {
                AMLogError("Arguments ignored because newMemberId \(newMemberId) is not equal to memberID used in Multi-Ad Request.")
                return
            }
        }

        if newInvCode != nil && newInvCode != inventoryCode {
            AMLogDebug("Setting inventory code to \(String(describing: newInvCode))")
            inventoryCode = newInvCode
        }
        if newMemberId > 0 && newMemberId != memberId {
            AMLogDebug("Setting member id to \(newMemberId)")
            memberId = newMemberId
        }
    }

    func setLocationWithLatitude(_ latitude: CGFloat, longitude: CGFloat, timestamp: Date?, horizontalAccuracy: CGFloat) {
        location = AMLocation.getWithLatitude(
            latitude,
            longitude: longitude,
            timestamp: timestamp,
            horizontalAccuracy: horizontalAccuracy)
    }

    func setLocationWithLatitude(_ latitude: CGFloat, longitude: CGFloat, timestamp: Date?, horizontalAccuracy: CGFloat, precision: Int) {
        self.location = AMLocation.getWithLatitude(
            latitude,
            longitude: longitude,
            timestamp: timestamp,
            horizontalAccuracy: horizontalAccuracy,
            precision: precision)
    }

    func addCustomKeyword(withKey key: String, value: String) {
        if key.isEmpty { return }
        guard var valueArray = self.customKeywords?[key] else {
            self.customKeywords?[key] = [value]
            return
        }
        if valueArray.contains(value) { return }
        
        valueArray.append(value)
        self.customKeywords?[key] = valueArray
    }

    func removeCustomKeyword(withKey key: String) {
        if key.isEmpty { return }
        self.customKeywords?[key] = nil
    }

    func clearCustomKeywords() {
        self.customKeywords?.removeAll()
    }
}
