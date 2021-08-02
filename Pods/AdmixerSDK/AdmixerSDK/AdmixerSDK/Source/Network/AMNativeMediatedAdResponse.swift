//
//  AMNativeMediatedAdResponse.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import UIKit

class AMNativeMediatedAdResponse: AMNativeAdResponse, AMNativeCustomAdapterAdDelegate {
    private var adapter: AMNativeCustomAdapter?
    internal var impTrackers: [String]?
    private var impressionsHaveBeenTracked = false

    func hasExpired() -> Bool {
        if expired { return true }
        if adapter == nil || adapter?.expired ?? false {
            expired = true
        }
        return expired
    }

    init?(customAdapter adapter: AMNativeCustomAdapter?, networkCode: AMNativeAdNetworkCode) {
        if adapter == nil {return nil}
        super.init()
            self.adapter = adapter
            self.networkCode = networkCode
            self.adapter?.nativeAdDelegate = self
            impressionsHaveBeenTracked = false
    }

// MARK: - Registration
    override func registerInstance(withNativeView view: UIView?, rootViewController controller: UIViewController?, clickableViews: [AnyHashable]?) throws -> Bool {
        do{
            try self.registerAdapter(withNativeView: view, rootViewController: controller, clickableViews: clickableViews)
            return true
        }catch { return false }
    }

    func registerAdapter(withNativeView view: UIView?, rootViewController controller: UIViewController?, clickableViews: [AnyHashable]?) throws {
        if adapter?.responds(to: #selector(getter: AMNativeCustomAdapter.nativeAdDelegate)) ?? false {
            adapter?.nativeAdDelegate = self
        } else {
            AMLogDebug("native_adapter_native_ad_delegate_missing")
        }
        if let view = view, let controller = controller {
            adapter?.registerView?(forImpressionTrackingAndClickHandling: view, withRootViewController: controller, clickableViews: clickableViews)
        }
    }

// MARK: - Unregistration
    @objc override func unregisterViewFromTracking() {
        super.unregisterViewFromTracking()
        adapter?.unregisterViewFromTracking?()
    }

// MARK: - Click handling
    @objc override func handleClick() {
        guard let vc = rootViewController else { return }
        adapter?.handleClick?(fromRootViewController: vc)
    }

// MARK: - Impression Tracking
    func fireImpTrackers() {
        if impTrackers != nil && !impressionsHaveBeenTracked {
            AMTrackerManager.fireTrackerURLArray(impTrackers)
        }
        //    if(self.omidAdSession != nil){
        //        [[AMOMIDImplementation sharedInstance] fireOMIDImpressionOccuredEvent:self.omidAdSession];
        //    }
        impressionsHaveBeenTracked = true
    }

// MARK: - AMNativeCustomAdapterAdDelegate
    // Only need to handling adWillLogImpression rest all is handle in the base class AMNativeAdResponse.m
    func adDidLogImpression() {
        fireImpTrackers()
    }
}
