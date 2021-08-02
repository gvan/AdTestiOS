//
//  Timer+ext.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation

extension Timer {
    func anIsScheduled() -> Bool {
        let runLoopRef = RunLoop.current.getCFRunLoop()
        return CFRunLoopContainsTimer(runLoopRef, self as CFRunLoopTimer, CFRunLoopMode.defaultMode)
    }

    func anScheduleNow() {
        AMLogDebug("Scheduled timer \(self) with interval \(fireDate.timeIntervalSinceNow).")
        RunLoop.current.add(self, forMode: .default)

        let isScheduled = anIsScheduled()

        if isScheduled {
            AMLogInfo("[NSTimer scheduleNow] \(self) is scheduled")
        }
    }

    class func anScheduledTimer(with interval: TimeInterval, block: @escaping () -> Void, repeats: Bool) -> Timer? {
        return self.scheduledTimer(
            timeInterval: interval,
            target: self,
            selector: #selector(Timer.anRunBlock(with:)),
            userInfo:  block,
            repeats: repeats)
    }

    class func anScheduledTimer(with interval: TimeInterval, block: @escaping () -> Void, repeats: Bool, mode: RunLoop.Mode) -> Timer? {
        let timer = self.init(
            timeInterval: interval,
            target: self,
            selector: #selector(Timer.anRunBlock(with:)),
            userInfo: block,
            repeats: repeats)
        RunLoop.current.add(
            timer,
            forMode: mode)
        return timer
    }

    @objc class func anRunBlock(with timer: Timer?) {
        let block: (() -> Void)? = timer?.userInfo as? (() -> Void)
        if block != nil {
            block?()
        }
    }
}
