//
//  AMTrackerInfo.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation

private let kAMTrackerExpirationInterval: TimeInterval = 3600

class AMTrackerInfo: NSObject {
    init?(url: String?) {
        if url == nil { return nil }
        super.init()
        self.url = url
        dateCreated = Date()
        createExpirationTimer()
    }

    private(set) var url: String?
    private(set) var dateCreated: Date?
    private(set) var expired = false
    var numberOfTimesFired = 0
    private var expirationTimer: Timer?

    func createExpirationTimer() {
        weak var weakSelf = self
        expirationTimer = Timer.anScheduledTimer(with: kAMTrackerExpirationInterval, block: {
                let strongSelf = weakSelf
                strongSelf?.expired = true
        },
        repeats: false)
    }

    override var description: String {
        return "\(NSStringFromClass(AMTrackerInfo.self)) URL: \(url ?? "")"
    }

    deinit {
        expirationTimer?.invalidate()
    }
}
