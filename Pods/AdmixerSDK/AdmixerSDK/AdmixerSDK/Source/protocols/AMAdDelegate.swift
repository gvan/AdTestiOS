//
//  AMAdDelegate.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation
@objc public protocol AMAdDelegate: NSObjectProtocol {
    @objc optional func adDidReceiveAd(_ ad: Any)
    @objc optional func ad(_ loadInstance: Any, didReceiveNativeAd responseInstance: Any)
    @objc optional func ad(_ ad: Any, requestFailedWithError error: Error)
    @objc optional func adWasClicked(_ ad: Any)
    @objc optional func adWasClicked(_ ad: AMAdView, withURL urlString: String)
    @objc optional func adWillClose(_ ad: Any)
    @objc optional func adDidClose(_ ad: Any)
    @objc optional func adWillPresent(_ ad: Any)
    @objc optional func adDidPresent(_ ad: Any)
    @objc optional func adWillLeaveApplication(_ ad: Any)
}
