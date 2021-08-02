//
//  AMLocation.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import CoreGraphics

private let kAMLocationMaxLocationPrecision = 6
private let kAMLocationDefaultHorizontalAccuracy = 100

@objc public class AMLocation: NSObject {
    public var latitude: CGFloat = 0.0
    public var longitude: CGFloat = 0.0
    public var timestamp: Date?
    public var horizontalAccuracy: CGFloat = 0.0
    private(set) var precision = 0

    public static func getWithLatitude(_ latitude: CGFloat, longitude: CGFloat, timestamp: Date?, horizontalAccuracy: CGFloat) -> AMLocation? {
        return AMLocation.getWithLatitude(
            latitude,
            longitude: longitude,
            timestamp: timestamp,
            horizontalAccuracy: horizontalAccuracy,
            precision: -1)
    }

    public static func getWithLatitude(_ latitude: CGFloat, longitude: CGFloat, timestamp: Date?, horizontalAccuracy: CGFloat, precision: Int) -> AMLocation? {
        var timestamp = timestamp
        var horizontalAccuracy = horizontalAccuracy
        let invalidLatitude = latitude < -90 || latitude > 90
        let invalidLongitude = longitude < -180 || longitude > 180
        let invalidHorizontalAccuracy = horizontalAccuracy < 0
        if invalidLatitude || invalidLongitude || invalidHorizontalAccuracy {
            return nil
        }

        let invalidPrecision = precision < -1
        if invalidPrecision {
            AMLogWarn("Invalid precision passed in (%d) with location, no rounding will occur", precision)
        }

        if horizontalAccuracy == 0 {
            horizontalAccuracy = CGFloat(kAMLocationDefaultHorizontalAccuracy)
        }

        if timestamp == nil {
            timestamp = Date()
        }

        // make a new object every time to make sure we don't use old data
        let location = AMLocation()
        if precision <= -1 {
            location.latitude = latitude
            location.longitude = longitude
            location.precision = -1
        } else {
            var effectivePrecision = precision
            if precision > kAMLocationMaxLocationPrecision {
                effectivePrecision = kAMLocationMaxLocationPrecision
            }

            let precisionFloat = CGFloat(powf(10, Float(effectivePrecision)))
            location.latitude = CGFloat(roundf(Float(latitude * precisionFloat))) / precisionFloat
            location.longitude = CGFloat(roundf(Float(longitude * precisionFloat))) / precisionFloat
            location.precision = effectivePrecision
        }
        location.timestamp = timestamp
        location.horizontalAccuracy = horizontalAccuracy
        return location
    }
}
