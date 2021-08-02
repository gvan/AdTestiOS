//
//  AMMediationContainerView.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import UIKit

class AMMediationContainerView: UIView {
    init(mediatedView view: UIView?) {
        super.init(frame: view?.frame ?? CGRect.zero)
        if let view = view {
            addSubview(view)
        }
        view?.translatesAutoresizingMaskIntoConstraints = false
        view?.anConstrainWithFrameSize()
        view?.anAlignToSuperview(
            withXAttribute: .top,
            yAttribute: .left)
    }

    var controller: AMMediationAdViewController?

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
