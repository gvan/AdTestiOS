//
//  AMAdViewInternalDelegate.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import UIKit

// NB  Native does not use AMAdViewInternalDelegate, but instead has its own specific delegates for the
//       request and response halves of Native entry point.
//     See AMNativeAdRequestDelegate and AMNativeAdDelegate (for response).
//

@objc protocol AMAdViewInternalDelegate: NSObjectProtocol {
    var clickThroughAction: AMClickThroughAction {get}
    var landingPageLoadsInBackground: Bool {get}
    
    @objc optional func adWasClicked(withURL urlString: String?)
    @objc optional func adDidReceiveAd(_ adObject: Any?)
    @objc optional func ad(_ loadInstance: Any?, didReceiveNativeAd responseInstance: Any?)

    func adRequestFailedWithError(_ error: Error?, andAdResponseInfo adResponseInfo: AMAdResponseInfo?)
    func adWasClicked()
    func adWillPresent()
    func adDidPresent()
    func adWillClose()
    func adDidClose()
    func adWillLeaveApplication()
    func adDidReceiveAppEvent(_ name: String?, withData data: String?)
    func adTypeForMRAID() -> String?
    func displayController() -> UIViewController?
    func adInteractionDidBegin()
    func adInteractionDidEnd()
}
