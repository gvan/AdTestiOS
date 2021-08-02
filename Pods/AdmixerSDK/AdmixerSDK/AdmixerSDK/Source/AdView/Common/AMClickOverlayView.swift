//
//  AMClickOverlayView.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import UIKit

enum AMClickOverlayColorOption : Int {
    case grey
    case red
    case teal
}

let AMCLICKOVERLAYCOLOROPTION = AMClickOverlayColorOption.grey
class AMClickOverlayView: UIView {
    class func addOverlay(to view: UIView?) -> AMClickOverlayView? {
        let overlay = AMClickOverlayView()
        view?.addSubview(overlay)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        let heightSuperviewRelation = NSLayoutConstraint(
            item: overlay,
            attribute: .height,
            relatedBy: .lessThanOrEqual,
            toItem: view,
            attribute: .height,
            multiplier: 1.0,
            constant: 0.0)
        let maxHeight = NSLayoutConstraint(
            item: overlay,
            attribute: .height,
            relatedBy: .lessThanOrEqual,
            toItem: nil,
            attribute: .notAnAttribute,
            multiplier: 1.0,
            constant: OVERLAY_LARGE.height)
        let minHeight = NSLayoutConstraint(
            item: overlay,
            attribute: .height,
            relatedBy: .greaterThanOrEqual,
            toItem: nil,
            attribute: .notAnAttribute,
            multiplier: 1.0,
            constant: OVERLAY_MEDIUM.height)
        let height = NSLayoutConstraint(
            item: overlay,
            attribute: .height,
            relatedBy: .equal,
            toItem: view,
            attribute: .height,
            multiplier: 0.9,
            constant: 0.0)
        height.priority = .defaultLow
        let aspectRatio = NSLayoutConstraint(
            item: overlay,
            attribute: .width,
            relatedBy: .equal,
            toItem: overlay,
            attribute: .height,
            multiplier: 1.5,
            constant: 0.0)
        view?.addConstraints([heightSuperviewRelation, maxHeight, minHeight, aspectRatio, height])
        overlay.anAlignToSuperview(
            withXAttribute: .centerX,
            yAttribute: .centerY)
        return overlay
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.clear
        addIndicatorView()
    }

    func addIndicatorView() {
        let indicator = UIActivityIndicatorView(style: .white)
        indicator.startAnimating()
        addSubview(indicator)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.anAlignToSuperview(
            withXAttribute: .centerX,
            yAttribute: .centerY)
    }

    func color(for option: AMClickOverlayColorOption, withAlpha alpha: CGFloat) -> UIColor? {
        switch option {
            case .red:
                return UIColor(
                    red: 163.0 / 255.0,
                    green: 48.0 / 255.0,
                    blue: 53.0 / 255.0,
                    alpha: alpha)
            case .teal:
                return UIColor(
                    red: 0.0 / 255.0,
                    green: 197.0 / 255.0,
                    blue: 181.0 / 255.0,
                    alpha: alpha)
            default:
                return UIColor(
                    red: 77.0 / 255.0,
                    green: 78.0 / 255.0,
                    blue: 83.0 / 255.0,
                    alpha: alpha)
        }
    }

    override func draw(_ rect: CGRect) {
        let roundedRect = UIBezierPath(
            roundedRect: bounds,
            cornerRadius: 2.0)
        let bkColor = color(
            for: AMCLICKOVERLAYCOLOROPTION,
            withAlpha: 0.8)
        bkColor?.setFill()
        roundedRect.fill(
            with: .normal,
            alpha: 1.0)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}

let OVERLAY_LARGE = CGSize(width: 100.0, height: 70.0)
let OVERLAY_MEDIUM = CGSize(width: 50.0, height: 35.0)
