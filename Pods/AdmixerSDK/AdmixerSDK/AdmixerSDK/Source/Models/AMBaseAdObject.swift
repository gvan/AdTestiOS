//
//  AMBaseAdObject.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation

class AMBaseAdObject: NSObject {
    var content: String?
    var height: Int?
    var width: Int?
    var adType: String?
    var creativeId: String?
    var impressionUrls: [String]?
    var clickUrls: [String]?
    var adResponseInfo: AMAdResponseInfo?
}
