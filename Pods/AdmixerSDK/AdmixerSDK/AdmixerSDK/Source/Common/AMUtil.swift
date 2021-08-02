//
//  AMUtil.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import WebKit
import UIKit

struct AMUtil {
    static private var _usrAgent: String?
    static var userAgent: String {
        if let value = _usrAgent { return value}
        _usrAgent = UserAgent.getUserAgent()
        return _usrAgent!
    }
}

fileprivate class UserAgent {
    fileprivate static let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    private static let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as! String
    fileprivate static let uaBitSafari = "Safari/605.1.15"
    fileprivate static let uaBitMobile = "Mobile/15E148"

    fileprivate static let product = "Mozilla/5.0"
    fileprivate static let platform = "AppleWebKit/605.1.15"
    fileprivate static let platformDetails = "(KHTML, like Gecko)"


    private static func clientUserAgent(prefix: String) -> String {
        return "\(prefix)/\(appVersion) (\(UIDevice.current.model); iPhone OS \(UIDevice.current.systemVersion)) (\(displayName))"
    }

    static func getUserAgent(domain: String = "") -> String {
        return UserAgentBuilder.defaultMobileUserAgent().userAgent()
    }
}

struct UserAgentBuilder {
    // User agent components
    fileprivate var product = ""
    fileprivate var systemInfo = ""
    fileprivate var platform = ""
    fileprivate var platformDetails = ""
    fileprivate var extensions = ""
    
    init(product: String, systemInfo: String, platform: String, platformDetails: String, extensions: String) {
        self.product = product
        self.systemInfo = systemInfo
        self.platform = platform
        self.platformDetails = platformDetails
        self.extensions = extensions
    }
    
    func userAgent() -> String {
        let userAgentItems = [product, systemInfo, platform, platformDetails, extensions]
        return removeEmptyComponentsAndJoin(uaItems: userAgentItems)
    }
    
    /// Helper method to remove the empty components from user agent string that contain only whitespaces or are just empty
    private func removeEmptyComponentsAndJoin(uaItems: [String]) -> String {
        return uaItems.filter{ !(($0.isEmpty)||($0.trimmingCharacters(in: .whitespaces) == "")) }.joined(separator: " ")
    }

    static func defaultMobileUserAgent() -> UserAgentBuilder {
        return UserAgentBuilder(product: UserAgent.product, systemInfo: "(\(UIDevice.current.model); CPU OS \(UIDevice.current.systemVersion.replacingOccurrences(of: ".", with: "_")) like Mac OS X)", platform: UserAgent.platform, platformDetails: UserAgent.platformDetails, extensions: "FxiOS/\(UserAgent.appVersion)  \(UserAgent.uaBitMobile) \(UserAgent.uaBitSafari)")
    }

}
