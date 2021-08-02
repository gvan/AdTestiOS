//
//  AMMRAIDJavascriptUtil.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation
import CoreGraphics

class AMMRAIDJavascriptUtil: NSObject {
    class func readyEvent() -> String? {
        return "window.mraid.util.readyEvent();"
    }
    
    class func pageFinished() -> String? {
        return "window.mraid.util.pageFinished();"
    }

    class func stateChange(_ state: AMMRAIDState) -> String? {
        var stateString = AMMRAIDUtil.stateString(from: state)
        if stateString == nil {
            stateString = ""
        }
        return "window.mraid.util.stateChangeEvent('\(stateString ?? "")');"
    }

    class func error(
        _ error: String?,
        forFunction function: String?
    ) -> String? {
        return "window.mraid.util.errorEvent('\(error ?? "")', '\(function ?? "")');"
    }

    class func placementType(_ placementType: String?) -> String? {
        return "window.mraid.util.setPlacementType('\(placementType ?? "")');"
    }

    class func isViewable(_ isViewable: Bool) -> String? {
        return "window.mraid.util.setIsViewable(\(isViewable ? "true" : "false"));"
    }

    class func currentSize(_ position: CGRect) -> String? {
        let width = Int(floorf(Float(position.size.width + 0.5)))
        let height = Int(floorf(Float(position.size.height + 0.5)))
        return String(format: "window.mraid.util.sizeChangeEvent(%i,%i);", width, height)
    }

    class func currentPosition(_ position: CGRect) -> String? {
        let offsetX = Int((position.origin.x > 0) ? floor(position.origin.x + 0.5) : ceil(position.origin.x - 0.5))
        let offsetY = Int((position.origin.y > 0) ? floor(position.origin.y + 0.5) : ceil(position.origin.y - 0.5))
        let width = Int(floorf(Float(position.size.width + 0.5)))
        let height = Int(floorf(Float(position.size.height + 0.5)))
        return String(format: "window.mraid.util.setCurrentPosition(%i, %i, %i, %i);", offsetX, offsetY, width, height)
    }

    class func defaultPosition(_ position: CGRect) -> String? {
        let offsetX = Int((position.origin.x > 0) ? floor(position.origin.x + 0.5) : ceil(position.origin.x - 0.5))
        let offsetY = Int((position.origin.y > 0) ? floor(position.origin.y + 0.5) : ceil(position.origin.y - 0.5))
        let width = Int(floorf(Float(position.size.width + 0.5)))
        let height = Int(floorf(Float(position.size.height + 0.5)))
        return String(format: "window.mraid.util.setDefaultPosition(%i, %i, %i, %i);", offsetX, offsetY, width, height)
    }

    class func screenSize(_ size: CGSize) -> String? {
        let width = Int(floorf(Float(size.width + 0.5)))
        let height = Int(floorf(Float(size.height + 0.5)))
        return String(format: "window.mraid.util.setScreenSize(%i, %i);", width, height)
    }

    class func maxSize(_ size: CGSize) -> String? {
        let width = Int(floorf(Float(size.width + 0.5)))
        let height = Int(floorf(Float(size.height + 0.5)))
        return String(format: "window.mraid.util.setMaxSize(%i, %i);", width, height)
    }

    class func feature(
        _ feature: String?,
        isSupported supported: Bool
    ) -> String? {
        return "window.mraid.util.setSupports(\'\(feature ?? "")\', \(supported ? "true" : "false"));"
    }

    class func getState() -> String? {
        return "window.mraid.getState()"
    }

    // Occulusion Rectangle is always null we donot support OcculusionRetangle Calculation.
    class func exposureChangeExposedPercentage(
        _ exposedPercentage: CGFloat,
        visibleRectangle visibleRect: CGRect
    ) -> String? {
        if exposedPercentage <= 0 {
            // If exposure percentage is 0 then send visibleRectangle as null.
            let exposureVal = String(format: "{\"exposedPercentage\":0.0,\"visibleRectangle\":null,\"occlusionRectangles\":null}")
            return "window.mraid.util.exposureChangeEvent(\(exposureVal));"
        } else {
            let offsetX = Int((visibleRect.origin.x > 0) ? floor(visibleRect.origin.x + 0.5) : ceil(visibleRect.origin.x - 0.5))
            let offsetY = Int((visibleRect.origin.y > 0) ? floor(visibleRect.origin.y + 0.5) : ceil(visibleRect.origin.y - 0.5))
            let width = Int(floorf(Float(visibleRect.size.width + 0.5)))
            let height = Int(floorf(Float(visibleRect.size.height + 0.5)))

            let exposureVal = String(format: "{\"exposedPercentage\":%.01f,\"visibleRectangle\":{\"x\":%i,\"y\":%i,\"width\":%i,\"height\":%i},\"occlusionRectangles\":null}", exposedPercentage, offsetX, offsetY, width, height)
            return "window.mraid.util.exposureChangeEvent(\(exposureVal));"
        }
    }

    class func setCurrentAppOrientation(
        _ orientation: String?,
        lockedOrientation locked: Bool
    ) -> String? {

        let orientationVal = "\"\(orientation ?? "")\",\(locked ? "true" : "false")"
        return "window.mraid.util.setCurrentAppOrientation(\(orientationVal));"
    }
}
