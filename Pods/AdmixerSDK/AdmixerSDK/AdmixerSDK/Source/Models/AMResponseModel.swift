//
//  AMResponseModel.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation
struct AMResponseModel : Codable {
    var tags: [AMResponseTag]
}

struct AMResponseTag : Codable {
    var nobid: Bool
    var noAdUrl: String?
    var tagId: String
    var auctionId: String?
    var ads: [AMResponseAd]
    var uuid: String?
    
    enum CodingKeys: String, CodingKey {
        case nobid, ads, uuid
        
        case noAdUrl = "no_ad_url"
        case tagId = "tag_id"
        case auctionId = "auction_id"
    }
}

struct AMResponseAd: Codable {
    var notifyUrl: String?
    var contentSource: String
    var adType: String
    var creativeId: String?
    var memberId: String?
    var rendererURL: String?
    
    var rtb: AMResponseRTB?
    var csm: AMResponseCSM?
    var ssm: AMResponseSSM?
    
    var viewability: AMResponseViewability?
    
    enum CodingKeys: String, CodingKey {
        case rtb, csm, ssm, viewability
        
        case notifyUrl = "notify_url"
        case contentSource = "content_source"
        case adType = "ad_type"
        case creativeId = "creative_id"
        case memberId = "buyer_member_id"
        case rendererURL = "renderer_url"
    }
}

struct AMResponseViewability: Codable {
    var config: String?
}

struct AMResponseSSM: Codable {
    var banner: AMResponseSSMBanner
    var handler: [AMResponseSSMHandler]
    var responseURL: String?
    var trackers: [AMResponseTracker]?
    
    enum CodingKeys: String, CodingKey {
        case banner, handler, trackers
        
        case responseURL = "response_url"
    }
}

struct AMResponseSSMHandler: Codable {
    var url: String?
}

struct AMResponseSSMBanner: Codable {
    var width: Int
    var height: Int
}


struct AMResponseCSM: Codable {
    var handler: [AMResponseCSMHandler]
    var responseURL: String?
    var trackers: [AMResponseTracker]?
    
    enum CodingKeys: String, CodingKey {
        case handler, trackers
        
        case responseURL = "response_url"
    }
}

struct AMResponseCSMHandler: Codable {
    var type: String
    var className: String
    var param: String?
    var width: Int
    var height: Int
    var id: String?
    
    enum CodingKeys: String, CodingKey {
        case type, param, width, height, id
        
        case className = "class"
    }
}


struct AMResponseRTB: Codable {
    var responseURL: String
    var banner: AMResponseRTBBanner?
    var video: AMResponseRTBVideo?
    var native: AMResponseRTBNative?
    var trackers: [AMResponseTracker]
    
    enum CodingKeys: String, CodingKey {
        case banner, trackers, video
        
        case responseURL = "response_url"
    }
}

struct AMResponseRTBBanner : Codable {
    var width: Int
    var height: Int
    var content: String
}

struct AMResponseRTBVideo : Codable {
    var width: Int
    var height: Int
    var content: String
    var assetURL: String?
    
    enum CodingKeys: String, CodingKey {
        case content
        case width = "player_width"
        case height = "player_height"
        case assetURL = "asset_url"
    }
}

struct AMResponseRTBNative : Codable {
    var additionalDescription: String?
    var mediaType: String?
    var title: String?
    var body: String?
    var callToAction: String?
    var sponsoredBy: String?
    
    var link: AMResponseRTBNativeLink?
    var icon: AMResponseRTBNativeImage?
    var mainImage: AMResponseRTBNativeImage?
    var video: String?
    
    var impressionTrackers: [String]?
    var rating: Float?
    var privacyLink: String?
    
    enum CodingKeys: String, CodingKey {
        case title, icon, rating, video
        
        case body = "desc"
        case additionalDescription = "desc2"
        case mediaType = "type"
        case callToAction = "ctatext"
        case sponsoredBy = "sponsored"
        case mainImage = "main_img"
        
        case impressionTrackers = "impression_trackers"
        case privacyLink = "privacy_link"
        
    }
}

struct AMResponseRTBNativeLink: Codable {
    var url: String?
    var fallbackURL: String?
    var clickTrackers: [String]?
    
    enum CodingKeys: String, CodingKey {
        case url
        case fallbackURL = "fallback_url"
        case clickTrackers = "click_trackers"
    }
}

struct AMResponseRTBNativeImage: Codable {
    var url: String?
    var size: AMSize?
}

struct AMResponseTracker: Codable {
    var impressionURLs: [String]?
    var clickURLs: [String]?
    
    enum CodingKeys: String, CodingKey {
        case impressionURLs = "impression_urls"
        case clickURLs = "click_urls"
    }
}
