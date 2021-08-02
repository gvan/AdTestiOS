//
//  AMVideoAdProcessor.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation

class AMVideoAdProcessor: NSObject, AMVideoAdPlayerDelegate {
    convenience init(delegate: AMVideoAdProcessorDelegate, withAdVideoContent videoAdContent: Any) {


        self.init()
            self.delegate = delegate

            if let csmVideoAd = videoAdContent as? AMCSMVideoAd {
                csmJsonContent = csmVideoAd.adDictionary?.anJsonString(withPrettyPrint: true)
            } else if let rtbVideo = videoAdContent as? AMRTBVideoAd {
                if (rtbVideo.content?.count ?? 0) > 0 {
                    videoXmlContent = rtbVideo.content
                    creativeWidth = rtbVideo.width
                    creativeHeight = rtbVideo.height
                } else if (rtbVideo.assetURL?.count ?? 0) > 0 {
                    videoURLString = rtbVideo.assetURL
                } else {
                    AMLogError("RTBVideo content & url are empty")
                }
            }

            processAdVideoContent()
    }

    private var delegate: AMVideoAdProcessorDelegate?
    private var csmJsonContent: String?
    private var videoXmlContent: String?
    private var videoURLString: String?
    private var adPlayer: AMVideoAdPlayer?
    private var creativeWidth: Int?
    private var creativeHeight: Int?

    func processAdVideoContent() {

        adPlayer = AMVideoAdPlayer()
        if let adPlayer = self.adPlayer {
            adPlayer.delegate = self
            adPlayer.creativeWidth = creativeWidth
            adPlayer.creativeHeight = creativeHeight
            if let videoURLString  = self.videoURLString {
                adPlayer.loadAd(withVastUrl: videoURLString)
            } else if let videoXmlContent = videoXmlContent {
                adPlayer.loadAd(withVastContent: videoXmlContent)
            } else if let csmJsonContent = csmJsonContent {
                adPlayer.loadAd(withJSONContent: csmJsonContent)
            } else {
                AMLogError("no csm or rtb object content available to process")
            }
        } else {
            AMLogError("AdPlayer creation failed")
        }

    }

// MARK: AMVideoAdPlayerDelegate methods
    @objc func videoAdReady() {

        adPlayer?.delegate = nil

        if delegate?.responds(to: #selector(AMUniversalAdFetcher.videoAdProcessor(_:didFinishVideoProcessing:))) ?? false {
            if let adPlayer = adPlayer {
                delegate?.videoAdProcessor(self, didFinishVideoProcessing: adPlayer)
            }
        } else {
            AMLogError("no delegate subscription found")
        }


    }

    @objc func videoAdLoadFailed(_ error: Error, with adResponseInfo: AMAdResponseInfo?) {
        adPlayer?.delegate = nil

        if delegate?.responds(to: #selector(AMUniversalAdFetcher.videoAdProcessor(_:didFailVideoProcessing:))) ?? false {
            let error = AMError("Error parsing video tag", AMAdResponseCode.amAdResponseInternalError.rawValue)
            delegate?.videoAdProcessor(self, didFailVideoProcessing: error)
        } else {
            AMLogError("no delegate subscription found")
        }

    }
}

@objc protocol AMVideoAdProcessorDelegate: NSObjectProtocol {
    func videoAdProcessor(_ videoAdProcessor: AMVideoAdProcessor, didFinishVideoProcessing adVideoPlayer: AMVideoAdPlayer)
    func videoAdProcessor(_ videoAdProcessor: AMVideoAdProcessor, didFailVideoProcessing error: Error)
}
