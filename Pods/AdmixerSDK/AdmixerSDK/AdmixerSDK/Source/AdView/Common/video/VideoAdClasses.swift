//
//  AMRTBVideoAd.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation

class AMRTBVideoAd: AMBaseAdObject {
    var assetURL: String?
    var notifyUrlString: String?
    var skipOffset: Int? = -1
}

class AMCSMVideoAd: AMBaseAdObject {
    var adDictionary: [AnyHashable : Any]?
}

class AMStandardAd: AMBaseAdObject {
    var mraid = false
}

class AMSSMStandardAd: AMBaseAdObject {
    var urlString: String?
    var responseURL: String?
}

class AMMediatedAd: AMBaseAdObject {
    var className: String?
    var param: String?
    var adId: String?
    var responseURL: String?
    var auctionInfo: String?
    var isAdTypeNative = false
    var verificationScriptResource: AMVerificationScriptResource?
}
