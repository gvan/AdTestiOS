//
//  AMRewardedItem.swift
//  AdmixerSDK
//
//  Created by Admixer on 11.03.2021.
//  Copyright © 2021 Admixer. All rights reserved.
//

import Foundation

public class AMRewardedItem: NSObject {
    
    public private(set) var type = ""
    public private(set) var amount: NSDecimalNumber!
    
    public required init(
        rewardType: String,
        rewardAmount: NSDecimalNumber) {
        self.type = rewardType
        self.amount = rewardAmount
    }
    
}
