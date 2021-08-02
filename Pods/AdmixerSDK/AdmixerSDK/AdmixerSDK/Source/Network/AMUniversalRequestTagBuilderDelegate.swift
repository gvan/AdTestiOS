//
//  AMUniversalRequestTagBuilderDelegate.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation
@objc protocol AMUniversalRequestTagBuilderDelegate: AMRequestTagBuilderCore {
    func adAllowedMediaTypes() -> [Int]
    // NB  Represents lazy evaluation as a means to get most current value of primarySize (eg: from self.containerSize).
    //     In addition, this method combines collection of all three size parameters to avoid synchronization issues.
    //
    func internalDelegateUniversalTagSizeParameters() -> [AnyHashable : Any]
    // AdUnit internal methods to manage UUID property used during Multi-Tag Requests.
    //
    func internalGetUTRequestUUIDString() -> String
    func internalUTRequestUUIDStringReset()

    //   If rendererId is not set, the default is zero (0).
    //   A value of zero indicates that renderer_id will not be sent in the UT Request.
    //   nativeRendererId is sufficient for AMBannerAdView and AMNativeAdRequest entry point.
    //
    @objc func nativeAdRendererId() -> Int
    //
    @objc optional func universalAdFetcher(_ fetcher: AMUniversalAdFetcher, didFinishRequestWith response: AMAdFetcherResponse)
    
    @objc optional func adRewarded(_ rewardedItem: AMRewardedItem)
}
