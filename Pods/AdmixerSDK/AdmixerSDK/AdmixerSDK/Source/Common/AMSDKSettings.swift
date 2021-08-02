//
//  AMSDKSettings.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation
class AMBaseUrlConfig: NSObject {
    static let sharedInstance =  AMBaseUrlConfig()
    private override init(){}

    func webViewBaseUrl() -> String {
        return "https://inv-nets-eu.admixer.net/sdk.aspx"
    }

    func utAdRequestBaseUrl() -> String? {
        return "https://inv-nets-eu.admixer.net/sdk.aspx"
    }

    func videoWebViewUrl() -> URL? {
        return urlForResource(withBasename: "admixer_vast_video", andExtension: "html")
    }

    func nativeRenderingUrl() -> URL? {
        return urlForResource(withBasename: "nativeRenderer", andExtension: "html")
    }

// MARK: - Helper methods.
    func urlForResource(withBasename basename: String?, andExtension ext: String?) -> URL? {
        if AMLogLevel.currentLevel.rawValue > AMLogLevel.debug.rawValue {
            return resourcesBundle.url(forResource: basename, withExtension: ext)
        } else {
            let url = resourcesBundle.url(forResource: basename, withExtension: ext)
            let URLString = url?.absoluteString
            let debugQueryString = "?ast_debug=true"
            let URLwithDebugQueryString = URLString ?? "" + (debugQueryString)
            let debugURL = URL(string: URLwithDebugQueryString)

            return debugURL
        }
    }
    //EMPTY
}

class AMSDKSettings {
    static let sharedInstance = AMSDKSettings()
    private init(){}
    
    var baseUrlConfig: AMBaseUrlConfig { return .sharedInstance }
    private var sdkVersion: String { return AM_SDK_VERSION }
    var httpsEnabled = false
    var enableOpenMeasurement = false
    var sizesThatShouldConstrainToSuperview: [NSValue]?
    var locationEnabledForCreative = false
    var customUserAgent: String?
    // Optionally call this method early in the app lifecycle.  For example in [AppDelegate application:didFinishLaunchingWithOptions:].
    //
    func optionalSDKInitialization() {
        _ = AMUtil.userAgent
        do {
            try AMReachability.shared.startNotifier()
        } catch {
            AMLogDebug("Unable to start notifier")
        }
        _ = AMCarrierObserver.shared
    }
}
