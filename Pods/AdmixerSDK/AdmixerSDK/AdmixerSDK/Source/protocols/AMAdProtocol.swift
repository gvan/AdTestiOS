//
//  AMAdProtocol.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import UIKit

// MARK: - AMAdProtocol partitions.
@objc public protocol AMAdProtocolFoundationCore: NSObjectProtocol {
    var memberId: Int { get }
    var publisherId: Int { get set }
    var location: AMLocation? { get set }
    var age: String? { get set }
    var gender: AMGender { get set }
    var externalUid: String? { get set }
    var contentId: String? { get set }
    var ortbObject: Data? {get set}
    func setLocationWithLatitude(_ latitude: CGFloat, longitude: CGFloat, timestamp: Date?, horizontalAccuracy: CGFloat)
    
    func setLocationWithLatitude(_ latitude: CGFloat, longitude: CGFloat, timestamp: Date?, horizontalAccuracy: CGFloat, precision: Int)

    func addCustomKeyword(withKey key: String, value: String)
    func removeCustomKeyword(withKey key: String)
    func clearCustomKeywords()
}

// MARK: -
@objc protocol AMAdProtocolFoundation: AMAdProtocolFoundationCore {
    var placementId: String? { get set }
    var inventoryCode: String? { get }
    var reserve: CGFloat { get set }
    var adType: AMAdType { get set }
    func setInventoryCode(_ inventoryCode: String?, memberId memberID: Int)
}


// MARK: -
@objc protocol AMAdProtocolBrowser: AnyObject {
    var clickThroughAction: AMClickThroughAction { get set }
    /// Set whether the landing page should load in the background or in the foreground when an ad is clicked.
    /// If set to YES, when an ad is clicked the user is presented with an activity indicator view, and the in-app
    /// browser displays only after the landing page content has finished loading. If set to NO, the in-app
    /// browser displays immediately. The default is YES.
    /// Only used when clickThroughAction is set to AMClickThroughActionOpenSDKBrowser.
    var landingPageLoadsInBackground: Bool { get set }
}

// MARK: -
@objc protocol AMAdProtocol: AMAdProtocolFoundation, AMAdProtocolBrowser, AMAdProtocolPublicServiceAnnouncement {
    var creativeId: String? { get set }
    var adResponseInfo: AMAdResponseInfo? { get set }
}

// MARK: -
@objc protocol AMAdProtocolPublicServiceAnnouncement: AnyObject {
    var shouldServePublicServiceAnnouncements: Bool { get set }
}

protocol AMNativeAdRequestProtocol: AMAdProtocolFoundation {
    //EMPTY
}

protocol AMNativeAdResponseProtocol: AMAdProtocolBrowser {
    //EMPTY
}
