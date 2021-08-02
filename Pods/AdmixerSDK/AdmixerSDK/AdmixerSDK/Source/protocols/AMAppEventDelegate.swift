//
//  AMAppEventDelegate.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation
/// Delegate to receive app events from the ad.
@objc protocol AMAppEventDelegate: NSObjectProtocol {
    /// Called when the ad has sent the app an event via the Admixer
    /// Javascript API for Mobile
    func ad(_ ad: AMAdProtocol, didReceiveAppEvent name: String, withData data: String)
}
