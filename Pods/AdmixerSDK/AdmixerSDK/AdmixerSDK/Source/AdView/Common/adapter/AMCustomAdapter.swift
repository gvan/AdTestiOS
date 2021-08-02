//
//  AMCustomAdapter.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import UIKit

@objc public protocol AMCustomAdapterDelegate: NSObjectProtocol {
    func didFail(toLoadAd errorCode: AMAdResponseCode)
    func adWasClicked()
    func willPresentAd()
    func didPresentAd()
    func willCloseAd()
    func didCloseAd()
    func willLeaveApplication()
}

@objc public protocol AMCustomAdapter: class, NSObjectProtocol {
    var delegate: AMCustomAdapterDelegate? { get set }
    init()
}

public protocol AMCustomAdapterBanner: AMCustomAdapter {
    func requestAd(
        with size: CGSize,
        rootViewController: UIViewController?,
        serverParameter parameterString: String?,
        adUnitId idString: String?,
        targetingParameters: AMTargetingParameters?
    )
    var bannerDelegate: AMCustomAdapterBannerDelegate? { get set }
}

public protocol AMCustomAdapterInterstitial: AMCustomAdapter {
    func requestAd(
        withParameter parameterString: String?,
        adUnitId idString: String?,
        targetingParameters: AMTargetingParameters?
    )
    func present(from viewController: UIViewController?)
    func isReady() -> Bool
    var interstitialDelegate: (AMCustomAdapterInterstitialDelegate & AMCustomAdapterDelegate)? { get set }
}

public protocol AMCustomAdapterRewarded: AMCustomAdapter {
    func requestAd(
        withParameter paramenterString: String?,
        adUnitId idString: String?,
        targetingParameters: AMTargetingParameters?
    )
    func present(from viewController: UIViewController?)
    func isReady() -> Bool
    var rewardedDelegate: (AMCustomAdapterRewardedDelegate & AMCustomAdapterDelegate)? { get set }
}

public protocol AMCustomAdapterBannerDelegate: AMCustomAdapterDelegate {
    func didLoadBannerAd(_ view: UIView?)
}

public protocol AMCustomAdapterInterstitialDelegate: AMCustomAdapterDelegate {
    func didLoadInterstitialAd(_ adapter: AMCustomAdapterInterstitial?)
    func failedToDisplayAd()
}

public protocol AMCustomAdapterRewardedDelegate: AMCustomAdapterDelegate {
    func didLoadRewardedAd(_ adapter: AMCustomAdapterRewarded?)
    func adRewarded(_ item: AMRewardedItem)
    func failedToDisplayAd()
}
