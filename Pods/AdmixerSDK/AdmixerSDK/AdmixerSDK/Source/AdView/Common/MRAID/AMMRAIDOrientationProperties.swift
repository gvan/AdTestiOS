//
//  AMMRAIDOrientationProperties.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation

class AMMRAIDOrientationProperties: NSObject {
    convenience init?(fromQueryComponents queryComponents: [AnyHashable : Any]?) {
        let allowOrientationChangeString = queryComponents?["allow_orientation_change"] as? String
        var allowOrientationChange: Bool
        if allowOrientationChangeString != nil {
            allowOrientationChange = (allowOrientationChangeString as NSString?)?.boolValue ?? false
        } else {
            allowOrientationChange = true
        }

        let forceOrientationString = queryComponents?["force_orientation"] as? String
        let forceOrientation = AMMRAIDUtil.orientation(fromForceOrientationString: forceOrientationString)
        self.init(
            allowOrientationChange: allowOrientationChange,
            force: forceOrientation)
    }

    init(allowOrientationChange: Bool, force forceOrientation: AMMRAIDOrientation) {
        self.allowOrientationChange = allowOrientationChange
        self.forceOrientation = forceOrientation
    }

    private(set) var allowOrientationChange = false
    private(set) var forceOrientation: AMMRAIDOrientation!

    override var description: String {
        return String(format: "(allowOrientationChange \(allowOrientationChange), forceOrientation: \(forceOrientation.rawValue)")
    }
}
