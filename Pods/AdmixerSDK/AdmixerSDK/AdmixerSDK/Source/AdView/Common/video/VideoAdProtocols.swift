//
//  VideoAdProtocols.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation
@objc protocol AMAdProtocolVideo: NSObjectProtocol {
    var minDuration: Int { get set }
    var maxDuration: Int { get set }
}

protocol AMVideoAdProtocol: AMAdProtocol, AMAdProtocolVideo {
    func getVideoOrientation() -> AMVideoOrientation
}
