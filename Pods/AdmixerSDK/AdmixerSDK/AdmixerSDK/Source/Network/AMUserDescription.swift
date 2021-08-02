//
//  AMUserDescription.swift
//  AdmixerSDK
//
//  Created by admin on 10/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation
struct AMUserDescription: Codable {
    var age: Int?
    var gender: Int
    var language: String?
    var externalUID: String?
    
    enum CodingKeys: String, CodingKey {
        case age, gender, language
        
        case externalUID = "external_uid"
    }
    
    init(gender: AMGender, language: String?, age: Int?, externalUID: String?) {
        self.gender = gender.rawValue
        
        if let lang = language, lang.count > 0 { self.language = lang }
        if let ageValue = age, ageValue > 0 { self.age = ageValue }
        if let uid = externalUID, uid.count > 0 { self.externalUID = uid}
    }
}
