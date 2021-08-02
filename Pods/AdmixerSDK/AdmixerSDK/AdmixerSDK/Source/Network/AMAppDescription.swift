//
//  AMAppDescription.swift
//  AdmixerSDK
//
//  Created by admin on 10/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation
struct AMAppDescription: Codable {
    var appId: String
    enum CodingKeys: String, CodingKey {
        case appId = "appid"
    }
    
    init() {
        let bundleAppId = Bundle.main.infoDictionary?["CFBundleIdentifier"] as? String
        let id = bundleAppId ?? "unknown_appId"
        self.appId = id
    }
}
