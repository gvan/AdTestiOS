//
//  AMRewardedAdViewInternalDelegate.swift
//  AdmixerSDK
//
//  Created by Admixer on 10.03.2021.
//  Copyright © 2021 Admixer. All rights reserved.
//

import Foundation

protocol AMRewardedAdViewInternalDelegate: AMAdViewInternalDelegate {
    func adFailedToDisplay()
    func adShouldClose()
    func adShouldSetOrientationProperties(_ orientationProperties: AMMRAIDOrientationProperties?)
    func adShouldUseCustomClose(_ useCustomClose: Bool)
}
