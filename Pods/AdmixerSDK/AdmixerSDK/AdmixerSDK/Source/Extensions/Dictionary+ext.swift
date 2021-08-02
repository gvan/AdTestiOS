//
//  Dictionary+ext.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation

extension Dictionary {
    func anJsonString(withPrettyPrint prettyPrint: Bool) -> String? {
        var jsonData: Data? = nil
        do {
            jsonData = try JSONSerialization.data(
                withJSONObject: self,
                options: JSONSerialization.WritingOptions(rawValue: (prettyPrint ? JSONSerialization.WritingOptions.prettyPrinted.rawValue : 0)))
        } catch {
        }

        if jsonData == nil {
            return "{}"
        } else {
            if let jsonData = jsonData {
                return String(data: jsonData, encoding: .utf8)
            }
            return nil
        }
    }
}
