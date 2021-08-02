//
//  AMCarrierObserver.swift
//  AdmixerSDK
//
//  Created by admin on 10/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import CoreTelephony
import Foundation

class AMCarrierMeta: NSObject {
    private(set) var name: String?
    private(set) var countryCode: String?
    private(set) var networkCode: String?

    init(
        _ name: String,
        countryCode: String,
        networkCode: String
    ) {
        super.init()
            self.name = name
            self.countryCode = countryCode
            self.networkCode = networkCode
    }

    class func make(with carrier: CTCarrier?) -> AMCarrierMeta {
        guard let carrier = carrier else {
            return AMCarrierMeta(
                "iOS",
                countryCode: Locale.current.regionCode ?? "",
                networkCode: "")
        }
        return AMCarrierMeta(
            carrier.carrierName ?? "",
            countryCode: carrier.mobileCountryCode ?? "",
            networkCode: carrier.mobileNetworkCode ?? "")
    }
}

class AMCarrierObserver: NSObject {
    var carrierMeta: AMCarrierMeta? {
        let carrier = networkInfo.subscriberCellularProvider
        return AMCarrierMeta.make(with: carrier)
    }
    static var shared = AMCarrierObserver()

    private var networkInfo = CTTelephonyNetworkInfo()
}
