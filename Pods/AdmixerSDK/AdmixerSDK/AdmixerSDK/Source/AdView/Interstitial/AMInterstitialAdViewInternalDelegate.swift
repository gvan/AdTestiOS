//
//  AMInterstitialAdViewInternalDelegate.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation

protocol AMInterstitialAdViewInternalDelegate: AMAdViewInternalDelegate {
    func adFailedToDisplay()
    func adShouldClose()
    func adShouldSetOrientationProperties(_ orientationProperties: AMMRAIDOrientationProperties?)
    func adShouldUseCustomClose(_ useCustomClose: Bool)
}
