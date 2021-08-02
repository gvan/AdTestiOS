//
//  AMNativeAdRequestDelegate.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation
protocol AMNativeAdRequestDelegate: NSObjectProtocol {
    func adRequest(_ request: AMNativeAdRequest, didReceive response: AMNativeAdResponse)
    func adRequest(_ request: AMNativeAdRequest, didFailToLoadWithError error: Error, with adResponseInfo: AMAdResponseInfo?)
}
