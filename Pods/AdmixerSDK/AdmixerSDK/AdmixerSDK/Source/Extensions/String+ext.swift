//
//  String+ext.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation

extension String {
    func anQueryComponents() -> [AnyHashable : Any]? {
        var parameters: [AnyHashable : Any]? = nil

        if count > 0 {
            parameters = [:]

            for parameter in components(separatedBy: "&") {
                let range = (parameter as NSString).range(of: "=")

                if range.location != NSNotFound {
                    parameters?[((parameter as NSString).substring(to: range.location)).removingPercentEncoding ?? ""] = ((parameter as NSString).substring(from: range.location + range.length)).removingPercentEncoding
                } else {
                    parameters?[parameter.removingPercentEncoding ?? ""] = ""
                }
            }
        }

        return parameters
    }

    func anEncodeAsURIComponent() -> String? {
        return self.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)
    }

    func anString(byAppendingUrlParameter name: String?, value: String?) -> String? {
        // don't append anything if either field is empty
        if ((name?.count ?? 0) < 1) || ((value?.count ?? 0) < 1) {
            return self as String
        }

        var parameter = "\(name ?? "")=\(value?.anEncodeAsURIComponent() ?? "")"

        // add the proper prefix depending on the current string
        if (self as NSString).range(of: "=").length != 0 {
            parameter.insert(contentsOf: "&", at: self.index(self.startIndex, offsetBy: 0))
        } else if (self as NSString).range(of: "?").location != (count - 1) {
            parameter.insert(contentsOf: "?", at: self.index(self.startIndex, offsetBy: 0))
            // otherwise, keep the string as it is
        }

        return self + (parameter)
    }

    func anResponseTrackerReasonCode(_ reasonCode: Int, latency: TimeInterval) -> String? {
        // append reason code
        var urlString = anString(
            byAppendingUrlParameter: "reason",
            value: "\(reasonCode)")

        if latency > 0 {
            urlString = urlString?.anString(
                byAppendingUrlParameter: "latency",
                value: String(format: "%.0f", latency))
        }

        AMLogInfo("responseURLString=\(String(describing: urlString))")

        return urlString
    }
}
