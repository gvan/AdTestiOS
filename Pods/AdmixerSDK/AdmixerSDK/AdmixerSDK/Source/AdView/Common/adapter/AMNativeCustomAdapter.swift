//
//  AMNativeCustomAdapter.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import UIKit
/// Defines a protocol by which an external native ad SDK can be mediated by Admixer.
@objc protocol AMNativeCustomAdapter: class, NSObjectProtocol {
    init()
    /// Allows the Admixer SDK to be notified of a successful or failed request load.
    weak var requestDelegate: AMNativeCustomAdapterRequestDelegate? { get set }
    /// Allows the Admixer SDK to be notified of actions performed on the native view.
    @objc weak var nativeAdDelegate: AMNativeCustomAdapterAdDelegate? { get set }
    /// - Returns: YES if the response is no longer valid, for example, if too much time has elapsed
    /// since receiving it. NO if the response is still valid.
    var expired: Bool { get set }
    /// Will be called by the Admixer SDK when a mediated native ad request should be initiated.
    func requestNativeAd(
        withServerParameter parameterString: String?,
        adUnitId: String?,
        targetingParameters: AMTargetingParameters?
    )

    /// Should be implemented if the mediated SDK handles both impression tracking and click tracking automatically.
    @objc optional func registerView(
        forImpressionTrackingAndClickHandling view: UIView,
        withRootViewController rvc: UIViewController,
        clickableViews: [AnyHashable]?
    )
    /// Should be implemented if the mediated SDK handles only impression tracking automatically, and needs to
    /// be manually notified that a user click has been detected.
    ///
    /// @note handleClickFromRootViewController: should be implemented as well.
    @objc optional func registerView(forImpressionTracking view: UIView)
    /// Should notify the mediated SDK that a click was registered, and that a click-through should be
    /// action should be performed.
    @objc optional func handleClick(fromRootViewController rvc: UIViewController)
    /// Should notify the mediated SDK that the native view should no longer be tracked.
    @objc optional func unregisterViewFromTracking()
}

/// Callbacks for when the native ad assets are being loaded.
@objc protocol AMNativeCustomAdapterRequestDelegate: NSObjectProtocol {
    func didLoadNativeAd(_ response: AMNativeMediatedAdResponse)
    func didFail(toLoadNativeAd errorCode: AMAdResponseCode)
}

/// Callbacks for when the native view has been registered and is being tracked.
@objc protocol AMNativeCustomAdapterAdDelegate: NSObjectProtocol {
    @objc optional func didInteractWithParams()

    func adWasClicked()
    func willPresentAd()
    func didPresentAd()
    func willCloseAd()
    func didCloseAd()
    func willLeaveApplication()
    func adDidLogImpression()
}
