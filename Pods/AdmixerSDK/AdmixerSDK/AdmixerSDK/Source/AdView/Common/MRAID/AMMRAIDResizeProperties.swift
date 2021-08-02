//
//  AMMRAIDResizeProperties.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation
import CoreGraphics

class AMMRAIDResizeProperties: NSObject {
    convenience init?(fromQueryComponents queryComponents: [AnyHashable : Any]?) {
        let w = CGFloat((queryComponents?["w"] as? NSNumber)?.floatValue ?? 0.0)
        let h = CGFloat((queryComponents?["h"] as? NSNumber)?.floatValue ?? 0.0)
        let offsetX = CGFloat((queryComponents?["offset_x"] as? NSNumber)?.floatValue ?? 0.0)
        let offsetY = CGFloat((queryComponents?["offset_y"] as? NSNumber)?.floatValue ?? 0.0)

        let customClosePositionString: String = queryComponents?["custom_close_position"] as? String ?? ""
        let closePosition = AMMRAIDUtil.customClosePosition(fromCustomClosePositionString: customClosePositionString)

        var allowOffscreen: Bool
        if queryComponents?["allow_offscreen"] != nil {
            allowOffscreen = (queryComponents?["allow_offscreen"] as? NSNumber)?.boolValue ?? false
        } else {
            allowOffscreen = true
        }

        self.init(
            width: w,
            height: h,
            offsetX: offsetX,
            offsetY: offsetY,
            customClosePosition: closePosition,
            allowOffscreen: allowOffscreen)
    }

    init(
        width: CGFloat,
        height: CGFloat,
        offsetX: CGFloat,
        offsetY: CGFloat,
        customClosePosition: AMMRAIDCustomClosePosition,
        allowOffscreen: Bool
    ) {
        super.init()
            self.width = width
            self.height = height
            self.offsetX = offsetX
            self.offsetY = offsetY
            self.customClosePosition = customClosePosition
            self.allowOffscreen = allowOffscreen
    }

    private(set) var width: CGFloat = 0.0
    private(set) var height: CGFloat = 0.0
    private(set) var offsetX: CGFloat = 0.0
    private(set) var offsetY: CGFloat = 0.0
    private(set) var customClosePosition: AMMRAIDCustomClosePosition!
    private(set) var allowOffscreen = false

    override var description: String {
        let pos = customClosePosition.rawValue
        return String(format: "(width \(width), height \(height), offsetX \(offsetX), offsetY \(offsetY), customClosePosition \(pos), allowOffscreen \(allowOffscreen)")
    }
}
