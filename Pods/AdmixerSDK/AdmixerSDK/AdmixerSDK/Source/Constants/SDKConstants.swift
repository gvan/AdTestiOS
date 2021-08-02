//
//  SDKConstants.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation

@objc public enum AMAdResponseCode : Int {
    case amDefaultCode = -1
    case amAdResponseSuccessful = 0
    case amAdResponseInvalidRequest
    case amAdResponseUnableToFill
    case amAdResponseMediatedSDKUnavailable
    case amAdResponseNetworkError
    case amAdResponseInternalError
    case amAdResponseBadFormat = 100
    case amAdResponseBadURL
    case amAdResponseBadURLConnection
    case amAdResponseNonViewResponse
}

@objc public enum AMGender : Int {
    case unknown = 0
    case male
    case female
}

enum AMNativeAdRegisterErrorCode : Int {
    case invalidView = 200
    case invalidRootViewController
    case expiredResponse
    case badAdapter
    case internalError
}

enum AMNativeAdNetworkCode : Int {
    case admixer = 0
    case facebook
    case inMobi
    case yahoo
    case custom
    case adMob
}

@objc enum AMAdType : Int {
    case unknown = 0
    case banner = 1
    case video = 2
    case native = 3
    
    private static let allTypes = ["banner", "video", "native"]
    static func fromString(_ str: String) -> AMAdType {
        guard let index = AMAdType.allTypes.firstIndex(of: str) else {
            AMLogError("UNRECOGNIZED adTypeString.  \(str)")
            return .unknown
        }
        guard let adType = AMAdType(rawValue: index + 1) else {
            AMLogError("UNRECOGNIZED adTypeString.  \(str)")
            return .unknown
        }
        return adType
    }
}

@objc public enum AMClickThroughAction : Int {
    case returnURL
    case openDeviceBrowser
    case openSDKBrowser
}

/*
 * VideoOrientation maps to the orientation of the Video being rendered
 * */
@objc enum AMVideoOrientation : Int {
    case anUnknown
    case anPortraint
    case anLandscape
    case anSquare
}
