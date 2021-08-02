//
//  AMTargetingParameters.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation

public class AMTargetingParameters: NSObject {
    /// Custom targeting keywords from the app.
    public var customKeywords: [String : String]?
    public var age: String?
    var gender: AMGender!
    var externalUid: String?
    /// location may be nil if not specified by app.
    public var location: AMLocation?
    /// The IDFA.
    var idforadvertising: String?
}
