//
//  AMGlobal.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//


import AdSupport
import Foundation
import WebKit

// MARK: - Constants


let AM_ERROR_DOMAIN = "net.admixer.sdk"
let AM_ERROR_TABLE = "errors"

let AM_DEFAULT_PLACEMENT_ID = "default_placement_id"
let AM_SDK_VERSION = "0.7.7"
let AM_SDK_NAME = "admixersdk"


let ADMIXER_BANNER_SIZE = CGSize(width: 320, height: 50)
let ADMIXER_MEDIUM_RECT_SIZE = CGSize(width: 300, height: 250)
let ADMIXER_LEADERBOARD_SIZE = CGSize(width: 728, height: 90)
let ADMIXER_WIDE_SKYSCRAPER_SIZE = CGSize(width: 160, height: 600)

let ADMIXER_SIZE_UNDEFINED = CGSize(width: -1, height: -1)



let kAdmixerRequestTimeoutInterval = 30.0
let kAdmixerAnimationDuration = 0.4
let kAdmixerMediationNetworkTimeoutInterval = 15.0
let kAdmixerMRAIDCheckViewableFrequency = 1.0
let kAdmixerBannerAdTransitionDefaultDuration = 1.0
let kAdmixerNativeAdImageDownloadTimeoutInterval = 10.0
let kAdmixerNativeAdCheckViewabilityForTrackingFrequency = 0.25
let kAdmixerNativeAdIABShouldBeViewableForTrackingDuration = 1.0

let kAMAdSize1x1 = CGSize(width: 1, height: 1)

@objc enum AMAllowedMediaType : Int {
    case banner = 1
    case interstitial = 3
    case video = 4
    case native = 12
}

@objc enum AMAdFormat: Int {
    case unknown = 0
    case banner = 1
    case interstitial = 2
    case native = 3
    case instream_vide = 4
    case rewarded = 5
}

@objc enum AMVideoAdSubtype : Int {
    case unknown = 0
    case instream
    case bannerVideo
}

let kAMCreativeId = "creativeId"
let kAMImpressionUrls = "impressionUrls"
let kAMAspectRatio = "aspectRatio"
let kAMAdResponseInfo = "adResponseInfo"
let AMInternalDelgateTagKeyPrimarySize = "AMInternalDelgateTagKeyPrimarySize"
let AMInternalDelegateTagKeySizes = "AMInternalDelegateTagKeySizes"
let AMInternalDelegateTagKeyAllowSmallerSizes = "AMInternalDelegateTagKeyAllowSmallerSizes"
let kAMUniversalAdFetcherWillRequestAdNotification = "kAMUniversalAdFetcherWillRequestAdNotification"
let kAMUniversalAdFetcherAdRequestURLKey = "kAMUniversalAdFetcherAdRequestURLKey"
let kAMUniversalAdFetcherWillInstantiateMediatedClassNotification = "kAMUniversalAdFetcherWillInstantiateMediatedClassNotification"
let kAMUniversalAdFetcherMediatedClassKey = "kAMUniversalAdFetcherMediatedClassKey"
let kAMUniversalAdFetcherDidReceiveResponseNotification = "kAMUniversalAdFetcherDidReceiveResponseNotification"
let kAMUniversalAdFetcherAdResponseKey = "kAMUniversalAdFetcherAdResponseKey"
let kAMFirstLaunchKey = "kAMFirstLaunchKey"
var notificationsEnabled = false

// MARK: - Banner AutoRefresh

// These constants control the default behavior of the ad view autorefresh (i.e.,
// how often the view will fetch a new ad).  Ads will only autorefresh
// when they are visible.

// Default autorefresh interval: By default, your ads will autorefresh
// at this interval.
let kAMBannerDefaultAutoRefreshInterval = 30.0

// Minimum autorefresh interval: The minimum time between refreshes.
// kAMBannerMinimumAutoRefreshInterval MUST be greater than kAMBannerAutoRefreshThreshold.
//
let kAMBannerMinimumAutoRefreshInterval = 15.0

// Autorefresh threshold: time value to disable autorefresh
let kAMBannerAutoRefreshThreshold = 0.0

// Interstitial Close Button Delay
let kAMInterstitialDefaultCloseButtonDelay = 0.0
let kAMInterstitialMaximumCloseButtonDelay = 30.0

// Rewarded Close Button Delay
let kAMRewardedDefaultCloseButtonDelay = 0.0
let kAMRewardedMaximumCloseButtonDelay = 30.0

// MARK: - Global functions.
func AMDeviceModel() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    let machineMirror = Mirror(reflecting: systemInfo.machine)
    let identifier = machineMirror.children.reduce("") { identifier, element in
        guard let value = element.value as? Int8, value != 0 else { return identifier }
        return identifier + String(UnicodeScalar(UInt8(value)))
    }
    
    return identifier
}

var AMAdvertisingTrackingEnabled: Bool {
    // If a user does turn this off, use the unique identifier *only* for the following:
    // - Frequency capping
    // - Conversion events
    // - Estimating number of unique users
    // - Security and fraud detection
    // - Debugging
    return ASIdentifierManager.shared().isAdvertisingTrackingEnabled
}

func AMIsFirstLaunch() -> Bool {
    let isFirstLaunch = !UserDefaults.standard.bool(forKey: kAMFirstLaunchKey)

    if isFirstLaunch {
        UserDefaults.standard.set(true, forKey: kAMFirstLaunchKey)
    }

    return isFirstLaunch
}

var anUUID: String { return UUID().uuidString }

var AMAdvertisingIdentifierUdidComponent = ""

func AMAdvertisingIdentifier() -> String {

    if (AMAdvertisingIdentifierUdidComponent == "") {
        let advertisingIdentifier = ASIdentifierManager.shared().advertisingIdentifier.uuidString

        if advertisingIdentifier != "" {
            AMAdvertisingIdentifierUdidComponent = advertisingIdentifier
            AMLogInfo("IDFA = %@", advertisingIdentifier)
        } else {
            AMLogWarn("No advertisingIdentifier retrieved. Cannot generate udidComponent.")
        }
    }

    return AMAdvertisingIdentifierUdidComponent
}

func AMErrorString(_ key: String) -> String {
    return NSLocalizedString(key, tableName: AM_ERROR_TABLE, bundle: resourcesBundle, value: "", comment: "")
}

func AMError(_ key: String, _ code: Int, _ args: String...) -> Error {
    var errorInfo: [AnyHashable : Any]? = nil
    var localizedDescription = AMErrorString(key)
    if localizedDescription != "" {
        localizedDescription = String(
            format: localizedDescription,
            arguments: args)
    } else {
        AMLogWarn("Could not find localized error string for key %@", key)
        localizedDescription = ""
    }
    errorInfo = [
        NSLocalizedDescriptionKey: localizedDescription
    ]
    return NSError(domain: AM_ERROR_DOMAIN, code: code, userInfo: errorInfo as? [String : Any])
}

let resourcesBundle = Bundle(for: AMGlobal.self)

func AMPathForAMResource(_ name: String?, _ type: String?) -> String? {
    guard let name = name, let type = type else { return nil}
    let path = resourcesBundle.path(forResource: name, ofType: type)
    if path == nil {
        AMLogError("Could not find resource \(name).\(type). Please make sure that all the resources in sdk/resources are included in your app target's \"Copy Bundle Resources\".")
    }
    return path
}

func AMAdjustAbsoluteRectInWindowCoordinatesForOrientationGivenRect(_ rect: CGRect) -> CGRect {
    // If portrait, no adjustment is necessary.
    if UIApplication.shared.statusBarOrientation == .portrait {
        return rect
    }

    let screenBounds = UIScreen.main.bounds
    // iOS 8
    if !screenBounds.origin.equalTo(CGPoint.zero) || screenBounds.size.width > screenBounds.size.height {
        return rect
    }

    // iOS 7 and below
    let flippedOriginX = screenBounds.size.height - (rect.origin.y + rect.size.height)
    let flippedOriginY = screenBounds.size.width - (rect.origin.x + rect.size.width)

    var adjustedRect: CGRect
    switch UIApplication.shared.statusBarOrientation {
        case .landscapeLeft, .landscapeRight:
            adjustedRect = CGRect(x: flippedOriginX, y: rect.origin.x, width: rect.size.height, height: rect.size.width)
        case .portraitUpsideDown:
            adjustedRect = CGRect(x: flippedOriginY, y: flippedOriginX, width: rect.size.width, height: rect.size.height)
        default:
            adjustedRect = rect
    }

    return adjustedRect
}

func AMMRAIDBundlePath() -> String? {
//    guard let mraidPath = AMPathForAMResource("mraid", "js") else {
        
    guard let mraidPath = AMPathForAMResource("AMMRAID", "bundle") else {
        AMLogError("Could not find AMMRAID.bundle. Please make sure that AMMRAID.bundle resource in sdk/resources is included in your app target's \"Copy Bundle Resources\".")
        return nil
    }
    return mraidPath
}

func AMHasHttpPrefix(_ url: String) -> Bool {
    return url.hasPrefix("http") || url.hasPrefix("https")
}

func AMPostNotifications(_ name: String, _ object: Any?, _ userInfo: [AnyHashable : Any]?) {
    guard notificationsEnabled else { return }
    
    let notifName = NSNotification.Name(name)
    NotificationCenter.default.post(name: notifName, object: object,userInfo: userInfo)
}

func AMPortraitScreenBounds() -> CGRect {
    let screenBounds = UIScreen.main.bounds
    if UIApplication.shared.statusBarOrientation != .portrait {
        if !screenBounds.origin.equalTo(CGPoint.zero) || screenBounds.size.width > screenBounds.size.height {
            // need to orient screen bounds
            switch UIApplication.shared.statusBarOrientation {
                case .landscapeLeft, .landscapeRight:
                    return CGRect(x: 0, y: 0, width: screenBounds.size.height, height: screenBounds.size.width)
                case .portraitUpsideDown:
                    return CGRect(x: 0, y: 0, width: screenBounds.size.width, height: screenBounds.size.height)
                default:
                    break
            }
        }
    }
    return screenBounds
}

func AMPortraitScreenBoundsApplyingSafeAreaInsets() -> CGRect {
    var screenBounds = UIScreen.main.bounds
    let window = UIApplication.shared.keyWindow
    if #available(iOS 11.0, *) {
        let topPadding = window?.safeAreaInsets.top ?? 0.0
        let bottomPadding = window?.safeAreaInsets.bottom ?? 0.0
        let leftPadding = window?.safeAreaInsets.left ?? 0.0
        let rightPadding = window?.safeAreaInsets.right ?? 0.0
        screenBounds = CGRect(x: leftPadding, y: topPadding, width: screenBounds.size.width - (leftPadding + rightPadding), height: screenBounds.size.height - (topPadding + bottomPadding))
    }
    if UIApplication.shared.statusBarOrientation != .portrait {
        if !screenBounds.origin.equalTo(CGPoint.zero) || screenBounds.size.width > screenBounds.size.height {
            // need to orient screen bounds
            switch UIApplication.shared.statusBarOrientation {
                case .landscapeLeft:
                    return CGRect(x: 0, y: 0, width: screenBounds.size.height, height: screenBounds.size.width)
                case .landscapeRight:
                    return CGRect(x: 0, y: 0, width: screenBounds.size.height, height: screenBounds.size.width)
                case .portraitUpsideDown:
                    return CGRect(x: 0, y: 0, width: screenBounds.size.width, height: screenBounds.size.height)
                default:
                    break
            }
        }
    }
    return screenBounds
}

func AMBasicRequestWithURL(_ url: URL) -> URLRequest {
    var request = URLRequest(
        url: url,
        cachePolicy: .reloadIgnoringLocalCacheData,
        timeoutInterval: TimeInterval(kAdmixerRequestTimeoutInterval))
    request.setValue(AMUtil.userAgent, forHTTPHeaderField: "User-Agent")
    return request
}

func AMiTunesIDForURL(_ url: URL) -> NSNumber? {
    guard url.host == "itunes.apple.com" else { return nil }
    let idStr = url.lastPathComponent
    let index = idStr.index(idStr.startIndex, offsetBy: 2)
    let appId = idStr[index...]
    return NSNumber(value: Int64(appId) ?? 0)
}

func AMCanPresentFromViewController(_ viewController: UIViewController?) -> Bool {
    return viewController?.view.window != nil ? true : false
}

// MARK: - Global class.
class AMGlobal: NSObject {
    class func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    class func convertCustomKeywordsAsMap(toStrings keywordsMap: [String : [String]], withSeparatorString separatorString: String) -> [String : String] {
        var keywordsMapToStrings: [String : String]? = [:]

        for (key, value) in keywordsMap {
            let mapValueString = value.joined(separator: separatorString)
            keywordsMapToStrings?[key] = mapValueString
        }

        return keywordsMapToStrings ?? [:]
    }

    class func parseVideoOrientation(_ aspectRatio: String?) -> AMVideoOrientation {
        let aspectRatioValue = Double(aspectRatio ?? "") ?? 0.0
        return aspectRatio == nil ? .anUnknown : (aspectRatioValue == 1) ? .anSquare : (aspectRatioValue > 1) ? .anLandscape : .anPortraint
    }

// MARK: - Custom keywords.

    // See also [AdSettings -setCustomKeywordsAsMapInEntryPoint:].
    //
    // Use alias for default separator string of comma (,).
    //
// MARK: - Get Video Orientation Method
}
