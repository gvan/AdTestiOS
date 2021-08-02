//
//  AMRequestModel.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation
import CoreGraphics

struct AMRequestModel: Codable {
    var sendImpressionURLS: Bool = true
    var supplyType: String = "mobile_app"
    var sdk: AMSDKDescription = AMSDKDescription(source: AM_SDK_NAME, version: AM_SDK_VERSION)
    var sdkVersion: String = "\(AM_SDK_NAME)\(AM_SDK_VERSION)"
    var app: AMAppDescription = AMAppDescription()
    var tags: [AMRequestTag] = []
    
    var device: AMDeviceDescription
    
    var memberId: Int?
    var publisherId: Int?
    var user: AMUserDescription?
    var ortb2: AMJSON?
    
    enum CodingKeys: String, CodingKey {
        case sdk, app, device, user, tags, ortb2
        
        case sendImpressionURLS = "send_impression_urls"
        case supplyType = "supply_type"
        case sdkVersion = "sdkver"
        
        case memberId = "member_id"
        case publisherId = "publisher_id"
    }
    
    mutating func update(memberId: Int) {
        if memberId > 0 { self.memberId = memberId}
    }
    
    mutating func update(publisherId: Int) {
        if publisherId > 0 { self.publisherId = publisherId}
    }
    
    mutating func update(user: AMUserDescription) {
        self.user = user
    }
    
    mutating func update(ortb2: AMJSON) {
        self.ortb2 = ortb2
    }
    
    mutating func add(tag: AMRequestTag?){
        guard let tag = tag else { return }
        self.tags.append(tag)
    }
}

struct AMRequestTag : Codable {
    var prebid: Bool = false
    var requireAssetURL: Bool = false
    var mraidSupported: Bool = true
    
    var id: String?
    var uuid: String
    var primarySize: AMSize
    var sizes: [AMSize]
    var allowSmallerSizes: Bool
    var isTest: Bool
    var allovedMediaTypes: [Int]
    var disablePSA: Bool
    var code: String?
    var keywords: [AMKeyword]?
    var contentId: String?
    
    enum CodingKeys: String, CodingKey {
        case id, uuid, sizes, prebid, code, keywords
        
        case primarySize = "primary_size"
        case allowSmallerSizes = "allow_smaller_sizes"
        case isTest = "is_test"
        case allovedMediaTypes = "allowed_media_types"
        case disablePSA = "disable_psa"
        case requireAssetURL = "require_asset_url"
        case mraidSupported = "mraid_supported"
        case contentId = "content_id"
    }
    
    mutating func update(code: String?) {
        self.code = code
    }
    
    mutating func update(id: String?) {
        self.id = id
    }
    
    mutating func update(contentId: String?) {
        self.contentId = contentId
    }
    
    mutating func add(keywords value: [AMKeyword]) {
        if value.isEmpty { return }
        if self.keywords == nil { self.keywords = [] }
        self.keywords?.append(contentsOf: value)
    }
}

struct AMSize: Codable {
    var width: Int = 0
    var height: Int = 0
    
    var cgSize: CGSize { return CGSize(width: self.width, height: self.height)}
    
    init(_ size: CGSize) {
        self.width = Int(size.width)
        self.height = Int(size.height)
    }
    init() {}
}


struct AMSDKDescription: Codable {
    static let value = AMSDKDescription(source: AM_SDK_NAME, version: AM_SDK_VERSION)
    var source: String
    var version: String
}

struct AMRequestLocation: Codable {
    var latitude: CGFloat
    var longitude: CGFloat
    var timestamp: Int // age in milliseconds
    var horizontalAccuracy: CGFloat
    
    enum CodingKeys: String, CodingKey {
        case latitude = "lat"
        case longitude = "lng"
        case timestamp = "loc_age"
        case horizontalAccuracy = "loc_precision"
    }
    
    
}

struct AMKeyword : Codable {
    var key: String
    var value: [String]
}
