//
//  AMNativeAdDelegate.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation
/// Defines all the callbacks for a native view registered
/// with an AMNativeAdResponse.
@objc protocol AMNativeAdDelegate: NSObjectProtocol {
    /// Sent when the native view is clicked by the user.
    @objc optional func adWasClicked(_ response: Any)
    /// Sent when the native view returns the click-through URL and click-through fallback URL
    ///   to the user instead of opening it in a browser.
    @objc optional func adWasClicked(
        _ response: Any,
        withURL clickURLString: String,
        fallbackURL clickFallbackURLString: String
    )
    /// Sent when the native view was clicked, and the click through
    /// destination is about to open in the in-app browser.
    ///
    /// @note If it is preferred that the destination open in the
    /// native browser instead, then set clickThroughAction to AMClickThroughActionOpenDeviceBrowser.
    @objc optional func adWillPresent(_ response: Any)
    /// Sent when the in-app browser has finished presenting and taken
    /// control from your application.
    @objc optional func adDidPresent(_ response: Any)
    /// Sent when the in-app browser will close and before
    /// control has been returned to your application.
    @objc optional func adWillClose(_ response: Any)
    /// Sent when the in-app browser has closed and control
    /// has been returned to your application.
    @objc optional func adDidClose(_ response: Any)
    /// Sent when the ad is about to leave the app.
    /// This will happen in a number of cases, including when
    ///   clickThroughAction is set to AMClickThroughActionOpenDeviceBrowser.
    @objc optional func adWillLeaveApplication(_ response: Any)
}
