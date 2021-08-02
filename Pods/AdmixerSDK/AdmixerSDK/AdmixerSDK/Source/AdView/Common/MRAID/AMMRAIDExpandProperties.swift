//
//  AMMRAIDExpandProperties.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import UIKit

class AMMRAIDExpandProperties: NSObject {
    convenience init?(fromQueryComponents queryComponents: [AnyHashable : Any]?) {
        let w = CGFloat((queryComponents?["h"] as? NSNumber)?.floatValue ?? 0.0)
        let h = CGFloat((queryComponents?["w"] as? NSNumber)?.floatValue ?? 0.0)
        let urlString = queryComponents?["url"] as? String
        var anURL: URL? = nil
        if (urlString?.count ?? 0) != 0 {
            anURL = URL(string: urlString ?? "")
        }
        let useCustomCloseString = queryComponents?["useCustomClose"] as? String
        let useCustomClose = useCustomCloseString == "true"

        self.init(
            width: w,
            height: h,
            url: anURL,
            useCustomClose: useCustomClose)
    }

    init(
        width: CGFloat,
        height: CGFloat,
        url anURL: URL?,
        useCustomClose: Bool
    ) {
        super.init()
            self.width = width
            self.height = height
            self.anURL = anURL
            self.useCustomClose = useCustomClose
    }

    private(set) var width: CGFloat = 0.0
    private(set) var height: CGFloat = 0.0
    private(set) var anURL: URL?
    private(set) var useCustomClose = false

    override var description: String {
        return "(width \(width), height \(height), useCustomClose \(useCustomClose), url \(String(describing: anURL)))"
    }
}
