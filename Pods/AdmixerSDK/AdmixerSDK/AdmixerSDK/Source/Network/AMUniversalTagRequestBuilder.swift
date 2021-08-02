//
//  AMUniversalTagRequestBuilder.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import CoreGraphics
import Foundation

class AMUniversalTagRequestBuilder: NSObject {
    // NB  Protocol type of adFetcherDelegate can be AMUniversalAdFetcherDelegate or AMUniversalNativeAdFetcherDelegate.
    //
    class func buildRequest(withAdFetcherDelegate adFetcherDelegate: AMUniversalTagRequestBuilderFetcherDelegate, baseUrlString: String) -> URLRequest? {
        let requestBuilder = AMUniversalTagRequestBuilder(
            adFetcherDelegate: adFetcherDelegate,
            optionallyWithAdunitMultiAdRequestManager: nil,
            orMultiAdRequestManager: nil,
            baseUrlString: baseUrlString)
        return requestBuilder.request()
    }

    class func buildRequest(withAdFetcherDelegate adFetcherDelegate: AMUniversalTagRequestBuilderFetcherDelegate, adunitMultiAdRequestManager adunitMARManager: AMMultiAdRequest, baseUrlString: String) -> URLRequest? {
        let requestBuilder = AMUniversalTagRequestBuilder(
            adFetcherDelegate: adFetcherDelegate,
            optionallyWithAdunitMultiAdRequestManager: adunitMARManager,
            orMultiAdRequestManager: nil,
            baseUrlString: baseUrlString)
        return requestBuilder.request()
    }

    class func buildRequest(withMultiAdRequestManager marManager: AMMultiAdRequest, baseUrlString: String) -> URLRequest? {
        let requestBuilder = AMUniversalTagRequestBuilder(
            adFetcherDelegate: marManager as? AMUniversalTagRequestBuilderFetcherDelegate,
            optionallyWithAdunitMultiAdRequestManager: nil,
            orMultiAdRequestManager: marManager,
            baseUrlString: baseUrlString)
        return requestBuilder.request()
    }

    // NB  adFetcherDelegate and marManager are mutually exclusive in initialization methods.
    //
    private weak var adFetcherDelegate: AMUniversalTagRequestBuilderFetcherDelegate?
    private weak var fetcherMARManager: AMMultiAdRequest?
    private weak var adunitMARManager: AMMultiAdRequest?
    private var baseURLString: String?

// MARK: Lifecycle.

    // NB  Protocol type of adFetcherDelegate can be AMUniversalAdFetcherDelegate or AMUniversalNativeAdFetcherDelegate.
    // NB  marManager is defined when this class is involed by MultiAdRequest, otherwise it is nil.
    //
    init(
        adFetcherDelegate: AMUniversalTagRequestBuilderFetcherDelegate?,
        optionallyWithAdunitMultiAdRequestManager adunitMARManager: AMMultiAdRequest?,
        orMultiAdRequestManager fetcherMARManager: AMMultiAdRequest?,
        baseUrlString: String
    ) {
        super.init()


        //
        self.adFetcherDelegate = adFetcherDelegate
        self.fetcherMARManager = fetcherMARManager
        self.adunitMARManager = adunitMARManager

        baseURLString = baseUrlString
    }

// MARK: - UT Request builder methods.
    func request() -> URLRequest? {
        let anURL = URL(string: baseURLString ?? "")
        var mutableRequest: URLRequest? = nil
        if let anURL = anURL {
            mutableRequest = URLRequest(
                url: anURL,
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: TimeInterval(kAdmixerRequestTimeoutInterval))
        }

        // Set header fields for HTTP request.
        // NB  Content-Type needs to be set explicity else will default to "application/x-www-form-urlencoded".
        //
        mutableRequest?.setValue(AMUtil.userAgent, forHTTPHeaderField: "User-Agent")
        mutableRequest?.setValue("application/json", forHTTPHeaderField: "Content-Type")
        mutableRequest?.httpMethod = "POST"

        var error: Error? = nil
        var postData: Data? = nil
        let jsonObject = requestBody()

        if jsonObject == nil {
            let userInfo = [
                NSLocalizedDescriptionKey: "[AMUniversalTagRequestBuilder requestBody] returned nil."
            ]
            error = NSError(domain: AM_ERROR_DOMAIN, code: AMAdResponseCode.amAdResponseInternalError.rawValue, userInfo: userInfo)
        }

        if error == nil {
            do {
                if let jsonObject = jsonObject {
                    postData = try JSONEncoder().encode(jsonObject)
                }
            } catch {
            }
        }

        if let err = error {
            AMLogError("Error formulating Universal Tag request: \(err.localizedDescription)")
            return nil
        }

        //
        var jsonString: String? = nil
        if let postData = postData {
            jsonString = String(data: postData, encoding: .utf8)
        }

        AMLogDebug("Post JSON: \(String(describing: jsonString))")
        AMLogDebug("[self requestBody] = \(String(describing: jsonObject))") //DEBUG

        mutableRequest?.httpBody = postData!
        return mutableRequest
    }

    func requestBody() -> AMRequestModel? {
        var model = AMRequestModel(device: self.device)

        if fetcherMARManager == nil {
            let singleTag = tag(&model)
            model.add(tag: singleTag)
        } else {
            let arrayOfAdUnits = fetcherMARManager?.internalGetAdUnits()

            //
            if let arrayOfAdUnits = arrayOfAdUnits {
                for au in arrayOfAdUnits {
                    adFetcherDelegate = au as? AMUniversalTagRequestBuilderFetcherDelegate

                    let tagFromAdUnit = tag(&model)
                    model.add(tag: tagFromAdUnit)
                }
            }
            adFetcherDelegate = fetcherMARManager as? AMUniversalTagRequestBuilderFetcherDelegate
        }

        if model.tags.isEmpty {
            AMLogError("FAILED TO GENERATE AT LEAST ONE TAG for this UT Request.")
            return nil
        }


        // If the festcher is loading an individual AdUnit that is encapsulated by MultiAdRequest,
        //   begin using the MultiAdRequest context to define page global fields.
        //
        if fetcherMARManager == nil && adunitMARManager != nil {
            fetcherMARManager = adunitMARManager
            adFetcherDelegate = adunitMARManager as? AMUniversalTagRequestBuilderFetcherDelegate
        }


        // For MultiAdRequest (AdUnit is encapsulated in MAR): set nodes for member_id and/or publisher_id.
        //   Compare to similar case in [self tag:].
        //
        if let mar = fetcherMARManager {
            model.update(memberId: mar.memberId)
            model.update(publisherId: mar.publisherId)
        }

        if let user = self.user() { model.update(user: user) }
        
        if let ortb2 = self.ortb2() { model.update(ortb2:  ortb2) }

//        if fetcherMARManager != nil {
//            requestDict["keywords"] = keywords()
//        }
//
//
//        // add GDPR Consent
//        let gdprConsent = getGDPRConsentObject()
//        if gdprConsent != nil {
//            requestDict["gdpr_consent"] = gdprConsent
//        }
//
//        // add USPrivacy String
//        let privacyString = AMUSPrivacySettings.getUSPrivacyString()
//        if privacyString.count != 0 {
//            requestDict["us_privacy"] = privacyString
//        }

        return model
    }

    func tag(_ requestModel: inout AMRequestModel) -> AMRequestTag? {
        guard let source = adFetcherDelegate else { return nil }
        source.internalUTRequestUUIDStringReset()
        
        let isTest = false
        let uuid = source.internalGetUTRequestUUIDString()
        let delegateReturnDictionary = source.internalDelegateUniversalTagSizeParameters() as? [String : Any]
        var primarySize = AMSize()
        if let val = delegateReturnDictionary?[AMInternalDelgateTagKeyPrimarySize] as? NSValue {
            primarySize = AMSize(val.cgSizeValue)
        }
        
        let sizes = delegateReturnDictionary?[AMInternalDelegateTagKeySizes] as? [CGSize]
        let allowSmallerSizes = (delegateReturnDictionary?[AMInternalDelegateTagKeyAllowSmallerSizes] as? NSNumber)?.boolValue ?? false
        
        var sizesArray: [AMSize] = []

        if let sizes = sizes {
            sizesArray = sizes.map{AMSize($0)}
        }
        
        let allovedMediaTypes = source.adAllowedMediaTypes()
        let anouncements = !(source.shouldServePublicServiceAnnouncements)
        
        var result = AMRequestTag(uuid: uuid, primarySize: primarySize, sizes: sizesArray, allowSmallerSizes: allowSmallerSizes, isTest: isTest, allovedMediaTypes: allovedMediaTypes, disablePSA: anouncements)

        result.add(keywords: self.keywords)
        
        // For AdUnit (MultiAdRequest is not active): set nodes for member_id and/or publisher_id.
        //   Compare to similar case in [self requestbody].
        //
        let placementId = source.placementId
        let publisherId = source.publisherId
        let memberId = source.memberId
        let invCode = source.inventoryCode
        let contentId = source.contentId

        if invCode != nil && memberId > 0 {
            result.update(code: invCode)

            if fetcherMARManager == nil {
                requestModel.update(memberId: memberId)
                requestModel.update(publisherId: publisherId)
            }
        } else {
            result.update(id: placementId)
        }
        
        if contentId != nil {
            result.update(contentId: contentId)
        }

//        let nativeRendererRequest = self.nativeRendererRequest()
//        if nativeRendererRequest != nil {
//            tagDict["native"] = nativeRendererRequest
//        }
//
//        let video = self.video()
//        if video != nil {
//            tagDict["video"] = video
//        }
//
//        //
//        let reservePrice = source.reserve ?? 0.0
//        if reservePrice > 0 {
//            tagDict["reserve"] = NSNumber(value: Float(reservePrice))
//        }

        //
        return result
    }

    func nativeRendererRequest() -> [String : Any?]? {
        guard let adFetcherDelegate = self.adFetcherDelegate else { return nil }
        let rendererId = adFetcherDelegate.nativeAdRendererId()
        let adAllowedMediaTypes = adFetcherDelegate.adAllowedMediaTypes()
        if (rendererId != 0) && adAllowedMediaTypes.contains(AMAllowedMediaType.native.rawValue) {
            return [
                "renderer_id": NSNumber(value: rendererId)
            ]
        }
        return nil
    }

    func video() -> [String : Any?]? {
        var videoDict: [String : Any?]? = [:]
        let minDurationValue = adFetcherDelegate?.minDuration ?? 0

        if minDurationValue > 0 {
            videoDict?["minduration"] = NSNumber(value: minDurationValue)
        }

        let maxDurationValue = adFetcherDelegate?.maxDuration ?? 0

        if maxDurationValue > 0 {
            videoDict?["maxduration"] = NSNumber(value: maxDurationValue)
        }
        

        if (videoDict?.count ?? 0) > 0 {
            return videoDict
        } else {
            return nil
        }
    }

    func user() -> AMUserDescription? {
        guard let source = adFetcherDelegate else { return nil}
        //
        let age = Int(source.age ?? "0") ?? 0
        let gender = source.gender
        let language = NSLocale.preferredLanguages.first
        let externalUid = source.externalUid
        
        let usr = AMUserDescription(gender: gender, language: language, age: age, externalUID: externalUid)

        return usr
    }
    
    func ortb2() -> AMJSON? {
        guard let source = adFetcherDelegate else { return nil }
        guard let ortb2 = source.ortbObject else { return nil }
        return try? JSONDecoder().decode(AMJSON.self, from: ortb2)
    }

    var device: AMDeviceDescription {
        let geo = self.geo
        let deviceModel = AMDeviceModel()
        var aaid: String? = AMGDPRSettings.canAccessDeviceData ? AMAdvertisingIdentifier() : nil
        
        #if targetEnvironment(simulator)
            aaid = "0a282562-0ad4-410e-b323-12eb47f2e795"
        #endif

        return AMDeviceDescription(model: deviceModel, aaid: aaid, geo: geo)
    }

    var geo: AMRequestLocation? {
        guard let location = adFetcherDelegate?.location else { return nil}

        let lat = location.latitude
        let lng = location.longitude
        
        let locationTimestamp = location.timestamp
        let ageInSeconds: TimeInterval = -1.0 * (locationTimestamp?.timeIntervalSinceNow ?? 0.0)
        let ageInMilliseconds = Int(ageInSeconds * 1000)

        return AMRequestLocation(latitude: lat, longitude: lng, timestamp: ageInMilliseconds, horizontalAccuracy: location.horizontalAccuracy)
    }

    // RETURN:  NSArray of NSDictionaries containing key/value pairs where the value is an NSArray of NSString.
    //
    var keywords : [AMKeyword] {
        var kvSegmentsArray: [AMKeyword] = []
        guard let customKeywords = adFetcherDelegate?.customKeywords else {
            return kvSegmentsArray
        }
        guard customKeywords.count > 0 else {
            return kvSegmentsArray
        }
        //

        for (key, value) in customKeywords {
            if value.isEmpty { continue }
            let unics = Array(Set(value))
            
            kvSegmentsArray.append(AMKeyword(key: key, value: unics))
        }

        //
        return kvSegmentsArray
    }


    func getGDPRConsentObject() -> [AnyHashable : Any]? {
        let gdprConsent = AMGDPRSettings.getConsentString()
        let gdprRequired = AMGDPRSettings.getConsentRequired()

        if gdprRequired != nil {
            if let gdprRequired = gdprRequired {
                return [
                    "consent_required": gdprRequired,
                    "consent_string": gdprConsent ?? ""
                ]
            }
            return nil
        } else {
            return nil
        }
    }
}

// MARK: -

// This protocol definition meant for local use only, to simplify typecasting of MAR Manager objects.
//
@objc protocol AMUniversalTagRequestBuilderFetcherDelegate: AMUniversalRequestTagBuilderDelegate, AMAdProtocolFoundation, AMAdProtocolVideo, AMAdProtocolPublicServiceAnnouncement {
    //EMPTY
}
