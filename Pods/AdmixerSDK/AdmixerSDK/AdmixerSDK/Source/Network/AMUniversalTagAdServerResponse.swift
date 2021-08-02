//
//  AMUniversalTagAdServerResponse.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation
import CoreGraphics

// MARK: - Private constants.
private let kAMUniversalTagAdServerResponseKeyAdsCSMObject = "csm"
private let kAMUniversalTagAdServerResponseKeyAdsSSMObject = "ssm"
private let kAMUniversalTagAdServerResponseKeyAdsRTBObject = "rtb"
// Video
private let kAMUniversalTagAdServerResponseKeyVideoObject = "video"
// Banner
private let kAMUniversalTagAdServerResponseKeyBannerObject = "banner"
private let kAMUniversalTagAdServerResponseKeyBannerWidth = "width"
private let kAMUniversalTagAdServerResponseKeyBannerHeight = "height"
private let kAMUniversalTagAdServerResponseMraidJSFilename = "mraid.js"
// SSM
// CSM
private let kAMUniversalTagAdServerResponseValueIOS = "ios"
// Native
private let kAMUniversalTagAdServerResponseKeyNativeObject = "native"
private let kAMUniversalTagAdServerResponseKeyNativeURL = "url"
private let kAMUniversalTagAdServerResponseKeyNativeClickTrackArray = "click_trackers"
private let kAMUniversalTagAdServerResponseKeyNativeImpTrackArray = "impression_trackers"
private let kAMUniversalTagAdServerResponseKeyNativeLink = "link"
private let kAMUniversalTagAdServerResponseKeyNativeJavascriptTrackers = "javascript_trackers"

// MARK: -
class AMUniversalTagAdServerResponse: NSObject {
    class func generateStandardAdUnit(fromHTMLContent htmlContent: String, width: Int, height: Int) -> AMStandardAd? {
        let standardAd = AMStandardAd()

        standardAd.width = width
        standardAd.height = height
        standardAd.content = htmlContent

        return standardAd
    }

    class func generateRTBVideoAdUnit(fromVASTObject vastContent: String, width: Int,height: Int) -> AMRTBVideoAd? {
        let rtbVideoAd = AMRTBVideoAd()

        rtbVideoAd.width = width
        rtbVideoAd.height = height
        rtbVideoAd.content = vastContent

        return rtbVideoAd
    }

    class func generateAdObjectInstance(fromJSONAdServerResponseTag tag: AMResponseTag) -> [Any] {
        let arrayOfJSONAdObjects = tag.ads
        var arrayOfAdUnits: [Any] = []


        for adObject in arrayOfJSONAdObjects {
            let contentSource = adObject.contentSource
//            let adTypeStr = adObject.adType
            let creativeId = adObject.creativeId
            let adType = adObject.adType
            let placementId = tag.tagId

            let memberId = Int(adObject.memberId ?? "") ?? 0

            //Initialise AdResponse object to expose all the public facing APIs from the UTv3 response
            let adResponseInfo = AMAdResponseInfo()
            adResponseInfo.creativeId = creativeId
            adResponseInfo.placementId = placementId
            adResponseInfo.adType = AMAdType.fromString(adType)
            adResponseInfo.contentSource = contentSource
            adResponseInfo.memberId = memberId

            // RTB
            if let rtbObject = adObject.rtb {
                // RTB - Banner
                if (adType == kAMUniversalTagAdServerResponseKeyBannerObject) {
                    guard let standardAd = self.standardAd(fromRTBObject: rtbObject) else { continue}
                    standardAd.creativeId = creativeId
                    arrayOfAdUnits.append(standardAd)
                // RTB - Video
                } else if (adType == kAMUniversalTagAdServerResponseKeyVideoObject) {
                    guard let videoAd = self.videoAd(fromRTBObject: rtbObject) else { continue }
                    videoAd.notifyUrlString = adObject.notifyUrl
                    videoAd.creativeId = creativeId
                    arrayOfAdUnits.append(videoAd)
                // RTB - Native
                } else if (adType == kAMUniversalTagAdServerResponseKeyNativeObject) {
                    guard let nativeAd = self.nativeAd(fromRTBObject: rtbObject) else { continue }
                    nativeAd.creativeId = creativeId
                    nativeAd.adResponseInfo = adResponseInfo
                    
                    if let nativeRenderingUrl = adObject.rendererURL {
                        let nativeRenderingElements = self.nativeRenderingJSON(rtbObject)
                        
                        let haveRenderer = !(nativeRenderingUrl.isEmpty || nativeRenderingElements == nil)
                        
                        if haveRenderer {
                            nativeAd.nativeRenderingObject = nativeRenderingElements
                            nativeAd.nativeRenderingUrl = nativeRenderingUrl
                        }
                    }
                    // Parsing viewability object to create measurement resources for OMID Native integration
                    nativeAd.verificationScriptResource = self.anVerificationScript(fromAdObject: adObject)
                    arrayOfAdUnits.append(nativeAd)
                } else {
                    AMLogError("UNRECOGNIZED AD_TYPE in RTB.  (adType=\(adType)  rtbObject=\(String(describing: rtbObject))")
                }
            }
            
            // CSM
            else if (contentSource == kAMUniversalTagAdServerResponseKeyAdsCSMObject) {
                if (adType == kAMUniversalTagAdServerResponseKeyBannerObject) || (adType == kAMUniversalTagAdServerResponseKeyNativeObject) ||
                    (adType == kAMUniversalTagAdServerResponseKeyVideoObject) {
                    guard let csmObject = adObject.csm else { continue }
                    if let mediatedAd = self.mediatedAd(fromCSMObject: csmObject) {
                        if (adType == kAMUniversalTagAdServerResponseKeyNativeObject) {
                            mediatedAd.isAdTypeNative = true
                            // Parsing viewability object to create measurement resources for OMID Native integration
                            mediatedAd.verificationScriptResource = self.anVerificationScript(fromAdObject: adObject)
                        }
                        mediatedAd.creativeId = creativeId
                        guard let clName = mediatedAd.className, clName.count > 0 else { continue }
                        adResponseInfo.networkName = mediatedAd.className
                        arrayOfAdUnits.append(mediatedAd)
                    }
                } else if (adType == kAMUniversalTagAdServerResponseKeyVideoObject) {
                    let csmVideoAd = self.videoCSMAd(fromCSMObject: adObject, withTagObject: tag)
                    if let csmVideoAd = csmVideoAd {
                        arrayOfAdUnits.append(csmVideoAd)
                    }
                } else {
                    AMLogError("UNRECOGNIZED AD_TYPE in CSM.  (adObject=\(adObject)")
                }

            // SSM - Only Banner and Interstitial are supported in SSM
            } else if (contentSource == kAMUniversalTagAdServerResponseKeyAdsSSMObject) {
                if (adType == kAMUniversalTagAdServerResponseKeyBannerObject) {
                    if let ssmObject = adObject.ssm {
                        let ssmStandardAd = self.standardSSMAd(fromSSMObject: ssmObject)
                        if ssmStandardAd != nil {
                            ssmStandardAd?.creativeId = creativeId
                            if let ssmStandardAd = ssmStandardAd {
                                arrayOfAdUnits.append(ssmStandardAd)
                            }
                        }
                    }
                } else {
                    AMLogError("UNRECOGNIZED AD_TYPE in SSM.  (adObject=\(adObject)")
                }
            } else {
                AMLogError("UNRECOGNIZED adObject.  (adObject=\(adObject))")
            }


            // Store general attributes of UT Response into select ad objects.

            let baseAdObject = arrayOfAdUnits.last as? AMBaseAdObject
            baseAdObject?.adType = adType
            baseAdObject?.adResponseInfo = adResponseInfo
        }


        //
        return arrayOfAdUnits
    }

// MARK: Inject creative content.

// MARK: - Universal Tag Support
    class func anVerificationScript(fromAdObject adObject: AMResponseAd) -> AMVerificationScriptResource? {
        guard let viewabilityObject = adObject.viewability else {
            AMLogError("Response from ad server in an unexpected format. Expected Viewability in adObject: \(String(describing: adObject))")
            return nil
        }
        let verificationScriptResource = AMVerificationScriptResource()
        verificationScriptResource.anVerificationScriptResource(viewabilityObject)
        return verificationScriptResource
    }

    class func standardAd(fromRTBObject rtbObject: AMResponseRTB) -> AMStandardAd? {
        guard let banner = rtbObject.banner else {
            AMLogError("Response from ad server in an unexpected format.  Expected RTB Banner in rtbObject:\(String(describing: rtbObject))")
            return nil
        }
        let standardAd = AMStandardAd()

        standardAd.width = banner.width
        standardAd.height = banner.height
        standardAd.content = banner.content
        standardAd.impressionUrls = rtbObject.trackers.first?.impressionURLs
        standardAd.clickUrls = rtbObject.trackers.first?.clickURLs

        if standardAd.content == nil || (standardAd.content?.count ?? 0) == 0 {
            AMLogError("blank_ad")
            return nil
        }

        let mraidJSRange = (standardAd.content as NSString?)?.range(of: kAMUniversalTagAdServerResponseMraidJSFilename)
        if mraidJSRange?.location != NSNotFound {
            standardAd.mraid = true
        }
        return standardAd
    }

    class func videoAd(fromRTBObject rtbObject: AMResponseRTB) -> AMRTBVideoAd? {
        guard let video = rtbObject.video else {
            AMLogError("Response from ad server in an unexpected format.  Expected RTB Video in rtbObject:\(String(describing: rtbObject))")
            return nil
        }

        let videoAd = AMRTBVideoAd()

        videoAd.content = video.content
        videoAd.assetURL = video.assetURL
        videoAd.width = video.width
        videoAd.height = video.height
        
        let range = video.content.range(of: "skipoffset=") ?? nil
        if let range = range {
            let index: Int = video.content.distance(from: video.content.startIndex, to: range.upperBound)
            let indexStart = video.content.index(video.content.startIndex, offsetBy: index + 1)
            let indexEnd = video.content.index(video.content.startIndex, offsetBy: index + 9)
            let range1 = indexStart..<indexEnd
            let substring = video.content[range1]
            let timeStr = String(substring)
            let timeArr = timeStr.components(separatedBy: ":")
            
            var seconds:Int = 0
            var minutes:Int = 0
            var hours:Int = 0
            if timeArr.count == 1 {
                seconds = Int(timeArr[0]) ?? 0
            } else
            if timeArr.count == 2 {
                minutes = Int(timeArr[0]) ?? 0
                seconds = Int(timeArr[1]) ?? 0
            } else
            if timeArr.count >= 3 {
                hours = Int(timeArr[0]) ?? 0
                minutes = Int(timeArr[1]) ?? 0
                seconds = Int(timeArr[2]) ?? 0
            }
            let timeSec = seconds + minutes * 60 + hours * 60 * 60
            videoAd.skipOffset = timeSec
        }

        return videoAd
    }

    class func mediatedAd(fromCSMObject csmObject: AMResponseCSM) -> AMMediatedAd? {
        let handlerArray = csmObject.handler
        var mediatedAd: AMMediatedAd? = nil
        
        for handlerObject in handlerArray {
            var className = handlerObject.className
            // Prod
            switch className {
            case "net.admixer.sdk.mediatedviews.AdMobBanner":
                className = "AdmixerSDK.AMAdAdapterBannerAdMob"
            case "net.admixer.sdk.mediatedviews.AdMobInterstitial":
                className = "AdmixerSDK.AMAdAdapterInterstitialAdMob"
            case "net.admixer.sdk.mediatedviews.AdMobRewarded":
                className = "AdmixerSDK.AMAdAdapterRewardedAdMob"
            case "net.admixer.sdk.mediatedviews.GooglePlayDFPBanner":
                className = "AdmixerSDK.AMAdAdapterBannerDFP"
            case "net.admixer.sdk.mediatedviews.GooglePlayDFPInterstitial":
                className = "AdmixerSDK.AMAdAdapterInterstitialDFP"
            default:
                className = handlerObject.className
            }
            // AdMob 7.69
//            switch className {
//            case "net.admixer.sdk.mediatedviews.AdMobBanner":
//                className = "GoogleMediationPre8.AMAdAdapterBannerAdMob"
//            case "net.admixer.sdk.mediatedviews.AdMobInterstitial":
//                className = "GoogleMediationPre8.AMAdAdapterInterstitialAdMob"
//            case "net.admixer.sdk.mediatedviews.AdMobRewarded":
//                className = "GoogleMediationPre8.AMAdAdapterRewardedAdMob"
//            case "net.admixer.sdk.mediatedviews.GooglePlayDFPBanner":
//                className = "GoogleMediationPre8.AMAdAdapterBannerDFP"
//            case "net.admixer.sdk.mediatedviews.GooglePlayDFPInterstitial":
//                className = "GoogleMediationPre8.AMAdAdapterInterstitialDFP"
//            default:
//                className = handlerObject.className
//            }
//             AdMob 8.0
//            switch className {
//            case "net.admixer.sdk.mediatedviews.AdMobBanner":
//                className = "GoogleMediation.AMAdAdapterBannerAdMob"
//            case "net.admixer.sdk.mediatedviews.AdMobInterstitial":
//                className = "GoogleMediation.AMAdAdapterInterstitialAdMob"
//            case "net.admixer.sdk.mediatedviews.AdMobRewarded":
//                className = "GoogleMediation.AMAdAdapterRewardedAdMob"
//            case "net.admixer.sdk.mediatedviews.GooglePlayDFPBanner":
//                className = "GoogleMediation.AMAdAdapterBannerDFP"
//            case "net.admixer.sdk.mediatedviews.GooglePlayDFPInterstitial":
//                className = "GoogleMediation.AMAdAdapterInterstitialDFP"
//            default:
//                className = handlerObject.className
//            }
            
            mediatedAd = AMMediatedAd()
            mediatedAd?.className = className
            mediatedAd?.param = handlerObject.param
            mediatedAd?.width = handlerObject.width
            mediatedAd?.height = handlerObject.height
            mediatedAd?.adId = handlerObject.id

            AMLogDebug("adId = \( String(describing: mediatedAd?.adId))")
            break
        }
        //endfor -- handlerObject
        
        guard let ad = mediatedAd else {
            AMLogError("Response from ad server in an unexpected format. Expected CSM in csmObject: \(String(describing: csmObject))")
            return nil
        }
            
            
        ad.responseURL = csmObject.responseURL
        ad.impressionUrls = csmObject.trackers?.first?.impressionURLs
        ad.clickUrls = csmObject.trackers?.first?.clickURLs

        return ad
    }

    class func videoCSMAd(fromCSMObject csmObject: AMResponseAd, withTagObject tagDictionary: AMResponseTag) -> AMCSMVideoAd? {
        var newTagDictionary = tagDictionary.dictionary
        let csmObjectDictionary = csmObject.dictionary
        newTagDictionary?["uuid"] = "\(NSNumber(value: arc4random_uniform(65536)))"
        newTagDictionary?["ads"] = [csmObjectDictionary]
        let videoAd = AMCSMVideoAd()
        videoAd.adDictionary = newTagDictionary
        return videoAd
    }

    class func standardSSMAd(fromSSMObject ssmObject: AMResponseSSM) -> AMSSMStandardAd? {
        let banner = ssmObject.banner
        let handlerArray = ssmObject.handler

        guard let handlerDict = handlerArray.first else {
            AMLogError("Response from ad server in an unexpected format. Unable to find SSM Banner in ssmObject: \(String(describing: ssmObject))")
            return nil
        }
        let standardAd = AMSSMStandardAd()
        standardAd.urlString = handlerDict.url
        standardAd.responseURL = ssmObject.responseURL
        standardAd.impressionUrls = ssmObject.trackers?.first?.impressionURLs
        standardAd.clickUrls = ssmObject.trackers?.first?.clickURLs
        standardAd.width = banner.width
        standardAd.height = banner.height
        standardAd.content = nil
        return standardAd
    }

    class func nativeJson(_ nativeRTBObject: [AnyHashable : Any]?) -> [String : Any]? {

        var nativeAd = nativeRTBObject
        nativeAd?.removeValue(forKey: kAMUniversalTagAdServerResponseKeyNativeImpTrackArray)
        nativeAd?.removeValue(forKey: kAMUniversalTagAdServerResponseKeyNativeLink)
        nativeAd?.removeValue(forKey: kAMUniversalTagAdServerResponseKeyNativeJavascriptTrackers)
        var nativeJSON: [String :Any]? = nil
        if let nativeAd = nativeAd {
            nativeJSON = [
                kAMNativeElementObject: nativeAd
            ]
        }
        return nativeJSON
    }

    class func nativeRenderingJSON(_ rtb: AMResponseRTB?) -> String? {
        guard let nativeAd = rtb?.native else { return nil }
        var utResponseJSONData: Data
        do {
            utResponseJSONData = try JSONSerialization.data(withJSONObject: nativeAd, options: .prettyPrinted)
        } catch {
            return nil
        }

        return String(data: utResponseJSONData, encoding: .utf8)
    }

    class func nativeAd(fromRTBObject rtbObject: AMResponseRTB) -> AMNativeStandardAdResponse? {
        guard let native = rtbObject.native else {
            AMLogDebug("Response from ad server in an unexpected format. Unable to find RTB native in nativeObject: \(String(describing: rtbObject))")
            return nil
        }

        let nativeAd = AMNativeStandardAdResponse()
        
        nativeAd.additionalDescription = native.additionalDescription
        nativeAd.adObjectMediaType = native.mediaType
        nativeAd.title = native.title
        nativeAd.body = native.body
        nativeAd.callToAction = native.callToAction
        nativeAd.sponsoredBy = native.sponsoredBy

        nativeAd.vastXML = native.video
        nativeAd.privacyLink = native.privacyLink
        
        nativeAd.impTrackers = native.impressionTrackers
        
        if let nativeLink = native.link {
            if let url = nativeLink.url { nativeAd.clickURL = URL(string: url) }
            if let fallbackURL = nativeLink.fallbackURL { nativeAd.clickFallbackURL = URL(string: fallbackURL) }
            if let clickTrackers =  nativeLink.clickTrackers { nativeAd.clickTrackers = clickTrackers }
        }

        if let icon = native.icon {
            if let url = icon.url { nativeAd.iconImageURL = URL(string: url) }
            if let size = icon.size { nativeAd.iconImageSize = size.cgSize }
        }

        if let image = native.mainImage {
            if let url = image.url { nativeAd.mainImageURL = URL(string: url) }
            if let size = image.size { nativeAd.mainImageSize = size.cgSize }
        }

        if let rating = native.rating {
            nativeAd.rating = AMNativeAdStarRating(value: CGFloat(rating), scale: -1)
        }

        return nativeAd
    }

    class func imageSize(_ nativeAdImageData: [AnyHashable : Any]?) -> CGSize {
        guard let data = nativeAdImageData else { return .zero }
        let w = (data[kAMUniversalTagAdServerResponseKeyBannerWidth] as? NSNumber) ?? 0
        let h = (data[kAMUniversalTagAdServerResponseKeyBannerHeight] as? NSNumber) ?? 0
        
        let width = CGFloat(truncating: w)
        let height = CGFloat(truncating: h)

        return CGSize(width: width, height: height)
    }

    class func imageURLString(_ nativeAdImageData: [AnyHashable : Any]?) -> URL? {
        let url = URL(string: "")
        guard let data = nativeAdImageData else { return url }
        guard let str = data[kAMUniversalTagAdServerResponseKeyNativeURL] as? String else { return url }
        return URL(string: str)

    }

// MARK: - Helper class methods (internal facing).
    class func generateDictionary(fromJSONResponse data: Data?) -> [String : Any?]? {
        var responseString: String? = nil
        if let data = data {
            responseString = String(data: data, encoding: .utf8)
        }

        if responseString == nil || ((responseString?.count ?? 0) <= 0) {
            AMLogDebug("Received empty response from ad server")
            return nil
        }

        //
        var jsonParsingError: Error? = nil

        var responseDictionary: Any? = nil
        do {
            if let data = data {
                responseDictionary = try JSONSerialization.jsonObject(
                    with: data,
                    options: [])
            }
        } catch { jsonParsingError = error }
        
        if jsonParsingError != nil {
            AMLogError("response_json_error \(String(describing: jsonParsingError))")
            return nil
        } else if !(responseDictionary is [AnyHashable : Any]) {
            AMLogError("Response from ad server in an unexpected format: \(String(describing: responseDictionary))")
            return nil
        }

        return responseDictionary as? [String : Any?]
    }
}
