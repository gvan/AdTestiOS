//
//  AMUniversalAdFetcherDelegate.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation
import CoreGraphics

@objc protocol AMUniversalAdFetcherDelegate: AMUniversalAdFetcherFoundationDelegate, AMAdProtocolBrowser, AMAdProtocolPublicServiceAnnouncement, AMAdViewInternalDelegate {
    func requestedSize(for fetcher: AMUniversalAdFetcher) -> CGSize

    // NB  autoRefreshIntervalForAdFetcher: and videoAdTypeForAdFetcher: are required for AMBannerAdView,
    //       but are not used by any other adunit.
    //
    @objc optional func autoRefreshInterval(for fetcher: AMUniversalAdFetcher) -> TimeInterval
    @objc optional func videoAdType(for fetcher: AMUniversalAdFetcher) -> AMVideoAdSubtype
    //   If enableNativeRendering is not set, the default is false.
    //   A value of false Indicates that NativeRendering is disabled
    //   enableNativeRendering is sufficient to BannerAd entry point.
    @objc optional func enableNativeRendering() -> Bool
    //   Set the Orientation of the Video rendered to BannerAdView taken from  AMAdWebViewController
    //   setVideoAdOrientation is sufficient to BannerAd entry point.
    @objc optional func setVideoAdOrientation(_ videoOrientation: AMVideoOrientation)
    @objc optional func getAdFormat() -> AMAdFormat
}

@objc protocol AMUniversalAdFetcherFoundationDelegate: AMUniversalRequestTagBuilderDelegate, AMAdProtocolFoundation {
}
