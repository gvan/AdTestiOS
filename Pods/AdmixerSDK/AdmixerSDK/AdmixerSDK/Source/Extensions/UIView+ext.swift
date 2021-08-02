//
//  UIView+ext.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import UIKit
import WebKit

extension UIView {
    func anPresent(_ view: UIView?, animated: Bool) {
        anPresent(view, animated: animated) { _ in }
    }

    func anPresent(_ view: UIView?, animated: Bool, completion: @escaping (Bool) -> Void) {
        view?.transform = CGAffineTransform(translationX: 0, y: bounds.size.height)

        let animationDuration = TimeInterval(animated ? kAdmixerAnimationDuration : 0.0)

        UIView.animate(
            withDuration: animationDuration,
            animations: {
                if let view = view {
                    self.addSubview(view)
                }
                view?.transform = CGAffineTransform(translationX: 0, y: 0)
            },
            completion: completion)
    }

    func anDismissFromPresentingView(animated: Bool) {
        let animationDuration = TimeInterval(animated ? kAdmixerAnimationDuration : 0.0)

        UIView.animate(
            withDuration: animationDuration,
            animations: {
                self.transform = CGAffineTransform(translationX: 0, y: self.bounds.size.height)
            }) { finished in
                self.removeFromSuperview()
            }
    }

    func anRemoveSubviews() {
        self.subviews.forEach{$0.removeFromSuperview()}
    }

    func anRemoveSubviews(except exception: UIView?) {
        for view in subviews {
            if view == exception { continue }
            if let webView = view as? WKWebView {
                webView.stopLoading()
                webView.navigationDelegate = nil
                webView.uiDelegate = nil
            }
            view.anRemoveSubviews()
            view.removeFromSuperview()
        }

    }

    var anIsViewable: Bool {
        if self.isHidden { return false }
        if window == nil { return false }

        var isInHiddenSuperview = false
        var ancestorView = superview
        while (ancestorView != nil) {
            if ancestorView?.isHidden ?? false {
                isInHiddenSuperview = true
                break
            }
            ancestorView = ancestorView?.superview
        }
        if isInHiddenSuperview { return false }

        let screenRect = UIScreen.main.bounds
        let normalizedSelfRect = convert(bounds, to: nil)
        return normalizedSelfRect.intersects(screenRect)
    }

    var anIsAtLeastHalfViewable: Bool {
        if self.isHidden { return false }
        if window == nil { return false }

        var isInHiddenSuperview = false
        var ancestorView = superview
        while (ancestorView != nil) {
            if ancestorView?.isHidden ?? false {
                isInHiddenSuperview = true
                break
            }
            ancestorView = ancestorView?.superview
        }
        if isInHiddenSuperview { return false }

        let screenRect = UIScreen.main.bounds
        let normalizedSelfRect = convert(bounds, to: nil)
        let intersection = screenRect.intersection(normalizedSelfRect)
        if intersection.equalTo(.null) {
            return false
        }

        let intersectionArea: CGFloat = intersection.width * intersection.height
        let selfArea: CGFloat = normalizedSelfRect.width * normalizedSelfRect.height
        return intersectionArea >= 0.5 * selfArea
    }

    var anExposedPercentage: CGFloat {
        var exposedPrecentage: CGFloat = 0
        if anIsViewable {
            let normalizedSelfRect = convert(bounds, to: nil)
            let intersection = UIScreen.main.bounds.intersection(normalizedSelfRect)
            let intersectionArea = intersection.size.width * intersection.size.height
            let totalArea = Int(normalizedSelfRect.size.width * normalizedSelfRect.size.height)
            exposedPrecentage = (intersectionArea * 100) / CGFloat((totalArea))
        }
        return exposedPrecentage
    }

    var anVisibleRectangle: CGRect {
        var visibleRectangle = CGRect(x: 0, y: 0, width: 0, height: 0)
        if anIsViewable {
            let normalizedSelfRect = convert(bounds, to: nil)
            let intersection = UIScreen.main.bounds.intersection(normalizedSelfRect)
            var visibleRectangleX: CGFloat = 0.0
            var visibleRectangleY: CGFloat = 0.0

            if normalizedSelfRect.origin.x < 0 {
                // The view is partly hidden from the left.(The view has scrolled out to the left and part of it is outside of screen bounds)
                visibleRectangleX = -1 * normalizedSelfRect.origin.x
            } else if (normalizedSelfRect.origin.x + normalizedSelfRect.size.width) > UIScreen.main.bounds.size.width {
                // Starting X of the View + its width is greater than the screen Width.
                // The view extends into the right of the screen and only partially visible.(The view has scrolled out to the right and part of it is outside of screen bounds)
                visibleRectangleX = 0
            } else if normalizedSelfRect.origin.y < 0 {
                // The view has scrolled up
                visibleRectangleY = -1 * normalizedSelfRect.origin.y
            } else if (normalizedSelfRect.origin.y + normalizedSelfRect.size.height) > UIScreen.main.bounds.size.height {
                // Starting Y of the View + its height is greater than the screen height.
                // The view has scrolled down
                visibleRectangleY = 0
            }
            visibleRectangle = CGRect(x: visibleRectangleX, y: visibleRectangleY, width: intersection.size.width, height: intersection.size.height)
        }
        return visibleRectangle
    }

    var anParentViewController: UIViewController? {
        var responder: UIResponder? = self

        while (responder != nil) {
            if (responder is UIViewController) {
                return responder as? UIViewController
            }
            responder = responder?.next
        }
        return nil
    }

    var anOriginalFrame: CGRect {
        let currentTransform = transform
        transform = .identity
        let originalFrame = frame
        transform = currentTransform

        return originalFrame
    }

// MARK: - Autolayout
    func anConstrain(with size: CGSize) {
        anRemoveSizeConstraintToSuperview()

        var widthConstraint: NSLayoutConstraint?
        var heightConstraint: NSLayoutConstraint?

        anExtractWidthConstraint( &widthConstraint, heightConstraint: &heightConstraint)

        if size.width > 1 {
            if widthConstraint == nil {
                widthConstraint = NSLayoutConstraint(item: self, attribute: .width, relatedBy: .equal,
                    toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: size.width)
                if let widthConstraint = widthConstraint {
                    addConstraint(widthConstraint)
                }
            } else {
                widthConstraint?.constant = size.width
            }
        } else {
            // Dynamic width - fill width of superview
            if widthConstraint != nil {
                if let widthConstraint = widthConstraint {
                    removeConstraint(widthConstraint)
                }
            }
            if superview != nil {
                let superviewWidthConstraint = NSLayoutConstraint(item: self, attribute: .width, relatedBy: .equal,
                    toItem: superview, attribute: .width, multiplier: 1, constant: 0)
                superview?.addConstraint(superviewWidthConstraint)
            } else {
                AMLogError("Failed to properly size dynamic width content view \(self) to superview, as superview is nil")
                // It's impossible to know what the right width to use here is because the width is supposed to be flexible.
                // But adding a constant to minimize any issue and hopefully this error rectifies itself when the view is actually displayed.
                widthConstraint = NSLayoutConstraint(item: self, attribute: .width, relatedBy: .equal,
                    toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 320)
                if let widthConstraint = widthConstraint {
                    addConstraint(widthConstraint)
                }
            }
        }

        if heightConstraint == nil {
            heightConstraint = NSLayoutConstraint(item: self, attribute: .height, relatedBy: .equal,
                toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: size.height)
            if let heightConstraint = heightConstraint {
                addConstraint(heightConstraint)
            }
        } else {
            heightConstraint?.constant = size.height
        }
    }

    func anConstrainWithFrameSize() {
        anConstrain(with: frame.size)
    }

    func anRemoveSizeConstraint() {
        var widthConstraint: NSLayoutConstraint?
        var heightConstraint: NSLayoutConstraint?
        anExtractWidthConstraint(&widthConstraint, heightConstraint: &heightConstraint)
        
        if let widthConstraint = widthConstraint {
            removeConstraint(widthConstraint)
        }
        if let heightConstraint = heightConstraint {
            removeConstraint(heightConstraint)
        }
    }

    func anExtractWidthConstraint(_ widthConstraint: inout NSLayoutConstraint?, heightConstraint: inout NSLayoutConstraint?) {
        self.constraints.forEach{constraint in
            let firstItemIsSelf = (constraint.firstItem as? UIView) == self
            let secondItemIsNil = constraint.secondItem == nil
            let notAnAtribute = constraint.secondAttribute == .notAnAttribute
            let constraintOnlyOnSelf = firstItemIsSelf && secondItemIsNil && notAnAtribute
            
            let constraintIsWidthConstraint = constraint.firstAttribute == .width && constraintOnlyOnSelf
            let constraintIsHeightConstraint = constraint.firstAttribute == .height && constraintOnlyOnSelf
            
            if constraintIsWidthConstraint {
                widthConstraint = constraint
            }
            if constraintIsHeightConstraint {
                heightConstraint = constraint
            }
        }
    }

    func anConstrainToSizeOfSuperview() {
        anRemoveSizeConstraintToSuperview()
        anRemoveSizeConstraint()

        let widthConstraint = NSLayoutConstraint(item: self, attribute: .width, relatedBy: .equal,
            toItem: superview, attribute: .width, multiplier: 1, constant: 0)
        let heightConstraint = NSLayoutConstraint(item: self, attribute: .height, relatedBy: .equal,
            toItem: superview, attribute: .height, multiplier: 1, constant: 0)
        superview?.addConstraints([widthConstraint, heightConstraint])
    }

    func anConstrainToSizeOfSuperviewApplyingSafeAreaLayoutGuide() {
        anRemoveSizeConstraintToSuperview()
        anRemoveSizeConstraint()
        var widthConstraint: NSLayoutConstraint?
        var heightConstraint: NSLayoutConstraint?
        if #available(iOS 11.0, *) {
            widthConstraint = NSLayoutConstraint(item: self,attribute: .width,relatedBy: .equal,
                toItem: superview?.safeAreaLayoutGuide, attribute: .width, multiplier: 1, constant: 0)
            heightConstraint = NSLayoutConstraint(item: self, attribute: .height, relatedBy: .equal,
                toItem: superview?.safeAreaLayoutGuide,  attribute: .height, multiplier: 1, constant: 0)
        } else {
            widthConstraint = NSLayoutConstraint(item: self, attribute: .width,  relatedBy: .equal,
                toItem: superview, attribute: .width, multiplier: 1, constant: 0)
            heightConstraint = NSLayoutConstraint(item: self, attribute: .height, relatedBy: .equal,
                toItem: superview, attribute: .height, multiplier: 1, constant: 0)
        }
        superview?.addConstraints([widthConstraint, heightConstraint].compactMap { $0 })
    }

    func anRemoveSizeConstraintToSuperview() {
        guard let parent = self.superview else { return }
        let superviewConstraints = parent.constraints
        superviewConstraints.forEach{constraint in
            let firstItemIsSelf = (constraint.firstItem as? UIView) == self
            let secondItemIsSelf = (constraint.secondItem as? UIView) == self
            let firstItemIsParent = (constraint.firstItem as? UIView) == parent
            let secondItemIsParent = (constraint.secondItem as? UIView) == parent
            
            
            let selftToParent = firstItemIsSelf && secondItemIsParent
            let parentToSelf = firstItemIsParent && secondItemIsSelf
            let attributesEqual = constraint.firstAttribute == constraint.secondAttribute
            let isWidthOrHeightConstraint = constraint.firstAttribute == .width || constraint.firstAttribute == .height
            let invalidConstraint = (selftToParent || parentToSelf) && attributesEqual && isWidthOrHeightConstraint
            if invalidConstraint {
                parent.removeConstraint(constraint)
            }
        }
    }

    func anAlignToSuperview(withXAttribute xAttribute: NSLayoutConstraint.Attribute, yAttribute: NSLayoutConstraint.Attribute) {
        anAlignToSuperview(withXAttribute: xAttribute, yAttribute: yAttribute, offsetX: 0, offsetY: 0)
    }

    func anAlignToSuperview(withXAttribute xAttribute: NSLayoutConstraint.Attribute, yAttribute: NSLayoutConstraint.Attribute,
        offsetX: CGFloat,offsetY: CGFloat) {
        anRemoveAlignmentConstraintsToSuperview()

        let xConstraint = NSLayoutConstraint(item: self, attribute: xAttribute, relatedBy: .equal,
            toItem: superview, attribute: xAttribute, multiplier: 1, constant: offsetX)
        let yConstraint = NSLayoutConstraint(item: self, attribute: yAttribute, relatedBy: .equal,
            toItem: superview, attribute: yAttribute, multiplier: 1, constant: offsetY)
        superview?.addConstraints([xConstraint, yConstraint])
    }

    func anAlignToSuperviewApplyingSafeAreaLayoutGuide(withXAttribute xAttribute: NSLayoutConstraint.Attribute,
        yAttribute: NSLayoutConstraint.Attribute, offsetX: CGFloat, offsetY: CGFloat) {
        anRemoveAlignmentConstraintsToSuperview()
        var yConstraint: NSLayoutConstraint?
        var xConstraint: NSLayoutConstraint?
        if #available(iOS 11.0, *) {
            yConstraint = NSLayoutConstraint(item: self, attribute: yAttribute, relatedBy: .equal,
                toItem: superview?.safeAreaLayoutGuide, attribute: yAttribute, multiplier: 1, constant: offsetY)
            xConstraint = NSLayoutConstraint(item: self, attribute: xAttribute, relatedBy: .equal,
                toItem: superview?.safeAreaLayoutGuide, attribute: xAttribute, multiplier: 1, constant: offsetX)
        } else {
            yConstraint = NSLayoutConstraint(item: self, attribute: yAttribute, relatedBy: .equal,
                toItem: superview, attribute: yAttribute, multiplier: 1, constant: offsetY)
            xConstraint = NSLayoutConstraint(item: self, attribute: xAttribute, relatedBy: .equal,
                toItem: superview, attribute: xAttribute, multiplier: 1, constant: offsetX)
        }
        superview?.addConstraints([xConstraint, yConstraint].compactMap { $0 })
    }

    func anRemoveAlignmentConstraintsToSuperview() {
        guard let parent = self.superview else { return }
        let superviewConstraints = parent.constraints
        superviewConstraints.forEach{constraint in
            let firstItemIsSelf = (constraint.firstItem as? UIView) == self
            let secondItemIsSelf = (constraint.secondItem as? UIView) == self
            let firstItemIsParent = (constraint.firstItem as? UIView) == parent
            let secondItemIsParent = (constraint.secondItem as? UIView) == parent
            
            
            let selftToParent = firstItemIsSelf && secondItemIsParent
            let parentToSelf = firstItemIsParent && secondItemIsSelf
            let attributesEqual = constraint.firstAttribute == constraint.secondAttribute
            let isWidthOrHeightConstraint = constraint.firstAttribute == .width || constraint.firstAttribute == .height
            let invalidConstraint = (selftToParent || parentToSelf) && attributesEqual && !isWidthOrHeightConstraint
            if invalidConstraint {
                parent.removeConstraint(constraint)
            }
        }
    }
}
extension UIView {
    weak var anNativeAdResponse: AMNativeAdResponse? {
        get {
            let resp = objc_getAssociatedObject(self, &AssociatedKeys.anNativeAdResponse) as? AMNativeAdResponse
            return resp
        }
        set(newValue) {
            objc_setAssociatedObject(self, &AssociatedKeys.anNativeAdResponse, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
    }
}

fileprivate struct AssociatedKeys {
    static var anNativeAdResponse: UInt8 = 0
}
