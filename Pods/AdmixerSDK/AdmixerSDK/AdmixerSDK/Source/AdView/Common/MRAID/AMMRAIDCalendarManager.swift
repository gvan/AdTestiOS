//
//  AMMRAIDCalendarManager.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import UIKit

class AMMRAIDCalendarManager: NSObject {
    init(
        calendarDictionary dict: [AnyHashable : Any]?,
        delegate: AMMRAIDCalendarManagerDelegate?
    ) {
        super.init()
            calendarDict = dict
            self.delegate = delegate
            delegate?.calendarManager?(self, calendarEditFailedWithErrorString: "createCalendarEvent not supported")
    }

    weak var delegate: AMMRAIDCalendarManagerDelegate?
    private var calendarDict: [AnyHashable : Any]?
}

@objc protocol AMMRAIDCalendarManagerDelegate: NSObjectProtocol {
    func rootViewControllerForPresentation(for calendarManager: AMMRAIDCalendarManager?) -> UIViewController?

    @objc optional func willPresentCalendarEdit(for calendarManager: AMMRAIDCalendarManager?)
    @objc optional func didPresentCalendarEdit(for calendarManager: AMMRAIDCalendarManager?)
    @objc optional func willDismissCalendarEdit(for calendarManager: AMMRAIDCalendarManager?)
    @objc optional func didDismissCalendarEdit(for calendarManager: AMMRAIDCalendarManager?)
    @objc optional func calendarManager(_ calendarManager: AMMRAIDCalendarManager?, calendarEditFailedWithErrorString errorString: String?)
}
