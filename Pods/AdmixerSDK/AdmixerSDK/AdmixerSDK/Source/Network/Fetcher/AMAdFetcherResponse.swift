//
//  AMAdFetcherResponse.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation

class AMAdFetcherResponse: NSObject {
    private(set) var successful = false
    private(set) var adObject: Any!
    private(set) var adObjectHandler: AMBaseAdObject?
    private(set) var error: Error?
    var adResponseInfo: AMAdResponseInfo?

    //
    init(error: Error) {
        super.init()
        self.error = error
    }

    init(adObject: Any, andAdObjectHandler adObjectHandler: AMBaseAdObject?) {
        super.init()
        successful = true
        self.adObject = adObject
        self.adObjectHandler = adObjectHandler
    }
}
