//
//  AMNativeAdStarRating.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import CoreGraphics
class AMNativeAdStarRating: NSObject {
    /// - Parameters:
    ///   - value: The absolute value of the rating.
    ///   - scale: What the value is out, for example, 5 on a 5 star rating scale.
    init(value: CGFloat, scale: Int) {
        super.init()
        self.value = value
        self.scale = scale
    }

    /// The absolute value of the rating.
    private(set) var value: CGFloat = 0.0
    /// The scale that the value is out of, for example, 5 for a 5 star rating scale.
    private(set) var scale = 0
}
