//
//  AMOpenInExternalBrowserActivity.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import UIKit

class AMOpenInExternalBrowserActivity: UIActivity {
    private var urlToOpen: URL?

    override var activityType: UIActivity.ActivityType? {
        return UIActivity.ActivityType("Admixer Open In Safari")
    }

    override var activityTitle: String? {
        return "Open In Safari"
    }

    override var activityImage: UIImage? {
        let iconPath = AMPathForAMResource("compass", "png")
        if iconPath == nil {
            AMLogError("Could not find compass image for 'Open in Safari' sharing option")
            return nil
        }
        let icon = UIImage(contentsOfFile: iconPath ?? "")
        return icon
    }

    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        guard let firstObject = activityItems.first else { return false }
        guard let url = firstObject as? URL else { return false }
        return url.absoluteString.isEmpty
    }

    override func perform() {
        AMGlobal.openURL(urlToOpen?.absoluteString ?? "")
        activityDidFinish(true)
    }

    override func prepare(withActivityItems activityItems: [Any]) {
        urlToOpen = activityItems[0] as? URL
    }

    override class var activityCategory: UIActivity.Category {
        return .action
    }
}
