//
//  AMDeviceDescription.swift
//  AdmixerSDK
//
//  Created by admin on 10/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation
struct AMDeviceDescription: Codable {
    struct IDDescription : Codable {
        var aaid: String
    }
    
    var make: String = "Apple"
    var connectionType: Int = AMReachability.shared.connection.code
    var userAgent: String = AMUtil.userAgent
    var devtime: Int = Int(Date().timeIntervalSince1970)
    var os: String = "iOS"
    var limitAdTracking: Bool = !AMAdvertisingTrackingEnabled
    
    var model: String
    var mnc: Int?
    var mcc: Int?
    var carrier: String?
    var geo: AMRequestLocation?
    
    var deviceId: IDDescription?
    
    enum CodingKeys: String, CodingKey {
        case make, model, mnc, mcc, carrier, devtime, os, geo
        
        case userAgent = "useragent"
        case connectionType = "connectiontype"
        case limitAdTracking = "limit_ad_tracking"
        case deviceId = "device_id"
    }
    
    init(model: String, aaid: String?, geo: AMRequestLocation?) {
        self.geo = geo
        self.model = model
        
        // FOR development reasons
//         self.deviceId = IDDescription(aaid: "6A88F450-D0D4-4E27-8427-C36C3DFDC842")
        if let aaid = aaid { self.deviceId = IDDescription(aaid: aaid)}
        
        guard let carrierMeta = AMCarrierObserver.shared.carrierMeta else { return }
        
        if let name = carrierMeta.name, name.count > 0 { self.carrier = name}
        
        if let mccStr = carrierMeta.countryCode, let mccInt = Int(mccStr) { self.mcc = mccInt}
        if let mncStr = carrierMeta.networkCode, let mncInt = Int(mncStr) { self.mnc = mncInt}
    }
}
