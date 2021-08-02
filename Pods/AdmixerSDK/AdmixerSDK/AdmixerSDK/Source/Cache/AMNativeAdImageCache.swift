//
//  AMNativeAdImageCache.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import UIKit

class AMNativeAdImageCache: NSObject {
    static private var imageCache = NSCache<NSString, UIImage>()

    class func image(forURL url: URL) -> UIImage? {
        return self.imageCache.object(forKey: url.absoluteString as NSString)
    }

    class func setImage(_ image: UIImage?, forURL url: URL) {
        if let image = image {
            self.imageCache.setObject(image, forKey: url.absoluteString as NSString)
        }
    }

    class func removeAllImages() {
        self.imageCache.removeAllObjects()
    }
}
