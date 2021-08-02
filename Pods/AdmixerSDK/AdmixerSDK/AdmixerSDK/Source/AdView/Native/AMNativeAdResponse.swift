//
//  AMNativeAdResponse.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import UIKit
//#import "AMOMIDImplementation.h"
let kAMNativeElementObject = "ELEMENT"

// MARK: - AMNativeAdResponseGestureRecognizerRecord
class AMNativeAdResponseGestureRecognizerRecord: NSObject {
    weak var viewWithTracking: UIView?
    weak var gestureRecognizer: UIGestureRecognizer?
}

// MARK: - AMNativeAdResponse
class AMNativeAdResponse: NSObject, AMNativeAdResponseProtocol {
    var landingPageLoadsInBackground: Bool = false
    /// The ad title.
    var title: String?
    /// The ad body, also known as the ad text or description.
    var body: String?
    /// The call to action text, for example, "Install Now!"
    var callToAction: String?
    /// The star rating of the ad, generally reserved for an app install ad.
    var rating: AMNativeAdStarRating?
    /// The ad icon image.
    private(set) var iconImage: UIImage?
    /// The icon image size
    var iconImageSize = CGSize.zero
    /// The ad main image, also known as a cover image.
    private(set) var mainImage: UIImage?
    /// A URL which loads the ad main image.
    var mainImageURL: URL?
    /// The main image size
    var mainImageSize = CGSize.zero
    /// A URL which loads the ad icon image.
    var iconImageURL: URL?
    /// Contains any non-standard elements. This would include any custom assets requested from
    /// third-party networks as specified in the third-party system.
    var customElements: [AnyHashable : Any]?
    /// The sponspored By text
    var sponsoredBy: String?
    /// An Admixer creativeID for the current creative that is displayed
    var creativeId: String?
    /// An Admixer Single Unified object that will contain all the common fields of all the ads types
    var adResponseInfo: AMAdResponseInfo?
    /// Additional description of the ad
    var additionalDescription: String?
    /// The network which supplied this native ad response.
    /// - seealso: AMNativeAdNetworkCode in AMAdConstants.h
    var networkCode: AMNativeAdNetworkCode!
    /// - Returns: YES if the response is no longer valid, for example, if too much time has elapsed
    /// since receiving it. NO if the response is still valid.
    var expired = false
    /// vastXML can be used to play Video.
    var vastXML: String?
    /// privacy Link of the ad
    var privacyLink: String?
    weak var delegate: AMNativeAdDelegate?
    var clickThroughAction: AMClickThroughAction = .openSDKBrowser
    var nativeRenderingUrl: String?
    var nativeRenderingObject: String?
    internal var viewForTracking: UIView?

    private var _gestureRecognizerRecords: [AMNativeAdResponseGestureRecognizerRecord]?
    private var gestureRecognizerRecords: [AMNativeAdResponseGestureRecognizerRecord]? {
        if _gestureRecognizerRecords == nil {
            _gestureRecognizerRecords = []
        }
        return _gestureRecognizerRecords
    }
    internal weak var rootViewController: UIViewController?
    //@property (nonatomic, readwrite, strong) OMIDadmixerAdSession *omidAdSession;
    internal var verificationScriptResource: AMVerificationScriptResource?

// MARK: - Registration
    @discardableResult func registerView(forTracking view: UIView, withRootViewController controller: UIViewController, clickableViews: [AnyHashable]?, error: Error?) throws -> Bool {
        if expired {
            AMLogError("native_expired_response")
            return false
        }

        let response = view.anNativeAdResponse
        if response != nil {
            AMLogDebug("Unregistering view from another response")
            response?.unregisterViewFromTracking()
        }

        let successfulResponseRegistration = try self.registerInstance(withNativeView: view, rootViewController: controller, clickableViews: clickableViews)

        if successfulResponseRegistration {
            viewForTracking = view
            view.anNativeAdResponse = self
            rootViewController = controller
            expired = true
            //        [self registerOMID];
            return true
        }

        return false
    }

    func registerInstance(withNativeView view: UIView?, rootViewController controller: UIViewController?, clickableViews: [AnyHashable]?) throws -> Bool {
        // Abstract method, to be implemented by subclass
        return false
    }

    @objc func unregisterViewFromTracking() {
        detachAllGestureRecognizers()
        viewForTracking?.anNativeAdResponse = nil
        viewForTracking = nil
        //    if(self.omidAdSession != nil){
        //        [[AMOMIDImplementation sharedInstance] stopOMIDAdSession:self.omidAdSession];
        //    }
    }

    //- (void)registerOMID{
    //    NSMutableArray *scripts = [NSMutableArray new];
    //    NSURL *url = [NSURL URLWithString:self.verificationScriptResource.url];
    //    NSString *vendorKey = self.verificationScriptResource.vendorKey;
    //    NSString *params = self.verificationScriptResource.params;
    //    [scripts addObject:[[OMIDAdmixerVerificationScriptResource alloc] initWithURL:url vendorKey:vendorKey  parameters:params]];
    //    self.omidAdSession = [[AMOMIDImplementation sharedInstance] createOMIDAdSessionforNative:self.viewForTracking withScript:scripts];
    //}




// MARK: - Click handling
    func attachGestureRecognizers(
        toNativeView nativeView: UIView?,
        withClickableViews clickableViews: [AnyHashable]?
    ) {
        if clickableViews?.count != nil {
            (clickableViews as NSArray?)?.enumerateObjects({ clickableView, idx, stop in
                if (clickableView is UIView) {
                    self.attachGestureRecognizer(to: clickableView as? UIView)
                } else {
                    AMLogWarn("native_invalid_clickable_views")
                }
            })
        } else {
            attachGestureRecognizer(to: nativeView)
        }
    }

    func attachGestureRecognizer(to view: UIView?) {
        view?.isUserInteractionEnabled = true

        let record = AMNativeAdResponseGestureRecognizerRecord()
        record.viewWithTracking = view

        if (view is UIButton) {
            let button = view as? UIButton
            button?.addTarget(
                self,
                action: #selector(handleClick),
                for: .touchUpInside)
        } else {
            let clickRecognizer = UITapGestureRecognizer(
                target: self,
                action: #selector(handleClick))
            view?.addGestureRecognizer(clickRecognizer)
            record.gestureRecognizer = clickRecognizer
        }

        self._gestureRecognizerRecords?.append(record)
    }

    func detachAllGestureRecognizers() {
        self.gestureRecognizerRecords?.forEach{record in
            let view = record.viewWithTracking
            if view != nil {
                if (view is UIButton) {
                    (view as? UIButton)?.removeTarget(
                        self,
                        action: #selector(handleClick),
                        for: .touchUpInside)
                } else if record.gestureRecognizer != nil {
                    if let gestureRecognizer1 = record.gestureRecognizer {
                        view?.removeGestureRecognizer(gestureRecognizer1)
                    }
                }
            }
        }

        self._gestureRecognizerRecords?.removeAll()
    }

    @objc func handleClick() {
        // Abstract method, to be implemented by subclass
    }

    deinit {
        unregisterViewFromTracking()
    }

// MARK: - AMNativeAdDelegate
    @objc func adWasClicked() {
        delegate?.adWasClicked?(self)
    }

    @objc func adWasClicked(withURL clickURLString: String?, fallbackURL clickFallbackURLString: String?) {
        delegate?.adWasClicked?(
            self,
            withURL: clickURLString ?? "",
            fallbackURL: clickFallbackURLString ?? "")
    }

    @objc func willPresentAd() {
        delegate?.adWillPresent?(self)
    }

    @objc func didPresentAd() {
        delegate?.adDidPresent?(self)
    }

    @objc func willCloseAd() {
        delegate?.adWillClose?(self)
    }

    @objc func didCloseAd() {
        delegate?.adDidClose?(self)
    }

    @objc func willLeaveApplication() {
        delegate?.adWillLeaveApplication?(self)
    }
}
