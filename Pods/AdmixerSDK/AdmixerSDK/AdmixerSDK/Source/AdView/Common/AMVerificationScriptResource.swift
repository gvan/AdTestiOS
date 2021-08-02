//
//  AMVerificationScriptResource.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation

let RESPONSE_KEY_CONFIG = "config"
let PATTERN_SRC_VALUE = "src=\"(.*?)\""
let PATTERN_VENDORKEY_VALUE = "vk=(.*?);"
let KEY_HASH = "#"

class AMVerificationScriptResource: NSObject {
    var url: String?
    var vendorKey: String?
    var params: String?

    //Parsing Viewability dictionary from ad server response into url, vendorkey and params
    func anVerificationScriptResource(_ jsonDic: AMResponseViewability?) {
        guard let config = jsonDic?.config else { return }
        if config.isEmpty { return }
        
        var regexSrc: NSRegularExpression
        do {
            regexSrc = try NSRegularExpression(pattern: PATTERN_SRC_VALUE, options: [])
        } catch {
            return
        }
        let configRange = NSRange(location: 0, length: config.count)
        guard let srcStringMatcher = regexSrc.firstMatch(in: config , options: [], range: configRange) else {
            return
        }
        
        let range = srcStringMatcher.range(at: 1)
        guard let src = (config as NSString?)?.substring(with: range) else { return }
        
        let arrVerificationScriptResource = src.components(separatedBy: KEY_HASH)
        guard arrVerificationScriptResource.count >= 2 else { return }
        url = arrVerificationScriptResource[0]
        params = arrVerificationScriptResource[1]

        var regexVK: NSRegularExpression
        do {
            regexVK = try NSRegularExpression(pattern: PATTERN_VENDORKEY_VALUE, options: [])
        } catch {
            return
        }
        
        guard let vkStringMatcher = regexVK.firstMatch(in: config, options: [], range: configRange) else { return }
        let vkRange = vkStringMatcher.range(at: 1)
        vendorKey = (config as NSString?)?.substring(with: vkRange)
    }
}
