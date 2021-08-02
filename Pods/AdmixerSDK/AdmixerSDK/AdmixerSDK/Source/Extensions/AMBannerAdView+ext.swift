//
//  AMBannerAdView+ext.swift
//  AdmixerSDK
//
//  Created by admin on 10/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import UIKit
private let kAMContentViewTransitionsOldContentViewTransitionKey = "AdmixerOldContentViewTransition"
private let kAMContentViewTransitionsNewContentViewTransitionKey = "AdmixerNewContentViewTransition"
//
private let kAMBannerAdViewNumberOfKeyframeValuesToGenerate = 35
private var kAMBannerAdViewPerspectiveValue: CGFloat = -1.0 / 750.0

extension AMBannerAdView {
    func performTransition(fromContentView oldContentView: UIView?, toContentView newContentView: UIView?) {
        if newContentView != nil {
            if let newContentView = newContentView {
                addSubview(newContentView)
            }
            constrainContentView()
            anRemoveSubviews(except: newContentView)
        } else {
            anRemoveSubviews()
        }
    }

    func alignContentView() {
        var xAttribute: NSLayoutConstraint.Attribute = .centerX
        var yAttribute: NSLayoutConstraint.Attribute = .centerY
        switch alignment {
            case .topLeft:
                yAttribute = .top
                xAttribute = .left
            case .topCenter:
                yAttribute = .top
                xAttribute = .centerX
            case .topRight:
                yAttribute = .top
                xAttribute = .right
            case .centerLeft:
                yAttribute = .centerY
                xAttribute = .left
            case .centerRight:
                yAttribute = .centerY
                xAttribute = .right
            case .bottomLeft:
                yAttribute = .bottom
                xAttribute = .left
            case .bottomCenter:
                yAttribute = .bottom
                xAttribute = .centerX
            case .bottomRight:
                yAttribute = .bottom
                xAttribute = .right
            default:
                break
        }
        contentView?.anAlignToSuperview(
            withXAttribute: xAttribute,
            yAttribute: yAttribute)
    }

    func constrainContentView() {
        contentView?.translatesAutoresizingMaskIntoConstraints = false

        let shouldConstrainToSuperview = AMSDKSettings.sharedInstance.sizesThatShouldConstrainToSuperview?.contains(NSValue(cgSize: contentView?.bounds.size ?? CGSize.zero)) ?? false

        if adSize.equalTo(CGSize(width: 1, height: 1)) || shouldConstrainToSuperview {

            contentView?.anConstrainToSizeOfSuperview()
            contentView?.anAlignToSuperview(
                withXAttribute: .left,
                yAttribute: .top)
        } else {

            contentView?.anConstrainWithFrameSize()
            alignContentView()
        }
    }

// Properties are synthesized in AMBannerAdView
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if contentView?.layer.animationKeys()?.count == nil {
            // No animations left
            anRemoveSubviews(except: contentView)
        }
    }
}
