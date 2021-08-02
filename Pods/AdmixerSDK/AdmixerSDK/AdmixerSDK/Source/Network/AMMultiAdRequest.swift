//
//  AMMultiAdRequest.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation
import CoreGraphics
// MARK: - Private types.

//
enum MultiAdPropertyType : Int {
    case autoRefreshInterval
    case manager
    case memberID
    case publisherID
    case uuid
}

@objc protocol AMMultiAdRequestDelegate: NSObjectProtocol {
    @objc optional func multiAdRequestDidComplete(_ mar: AMMultiAdRequest)
    @objc optional func multiAdRequest(_ mar: AMMultiAdRequest, didFailWithError error: Error)
}

let kMARAdUnitIndexNotFound = -1

// MARK: -
@objc class AMMultiAdRequest: NSObject, AMAdDelegate, AMNativeAdRequestDelegate, AMRequestTagBuilderCore {
    
    private weak var delegate: AMMultiAdRequestDelegate?
    // adUnits is an array of AdUnits managed by the MultiAdRequest.
    // It is declared in a manner capable of storing weak pointers.  Pointers to deallocated AdUnits are automatically assigned to nil.
    //
    private var adUnits = [AMAdProtocolFoundationCore]()
    private var adFetcher: AMAdFetcherBase?
    internal var customKeywords: [String : [String]]? = [:]
    
    var memberId: Int = 0
    var publisherId: Int = -1
    var age: String = ""
    var gender: AMGender = .unknown
    var location: AMLocation?
    var externalUid: String?
// MARK: - Lifecycle.

    /// adUnits is a list of AdUnits ending with nil.
    convenience init?(memberId: Int, delegate: AMMultiAdRequestDelegate?, adUnits firstAdUnit: AMAdProtocolFoundationCore, adUnitArgs: AMAdProtocolFoundationCore...) {
        self.init()
        
        let didSetup = setup(withMemberId: memberId, publisherID: 0, andDelegate: delegate)
        guard didSetup else { return nil}

        let addUnitResult = self.addAdUnit(firstAdUnit)
        guard addUnitResult else { return nil }
        
        for arg in adUnitArgs {
            let addUnitResult = self.addAdUnit(arg)
            guard addUnitResult else { return nil }
        }
    }

    /// adUnits is a list of AdUnits ending with nil.
    convenience init?(memberId: Int, publisherId: Int, delegate: AMMultiAdRequestDelegate?, adUnits firstAdUnit: AMAdProtocolFoundationCore, adUnitArgs: AMAdProtocolFoundationCore...) {
        self.init()
        
        let didSetup = setup(withMemberId: memberId, publisherID: publisherId, andDelegate: delegate)
        guard didSetup else { return nil }

        let addUnitResult = self.addAdUnit(firstAdUnit)
        guard addUnitResult else { return nil }

        for arg in adUnitArgs {
            let addUnitResult = self.addAdUnit(arg)
            guard addUnitResult else { return nil }
        }
    }

    /// adUnits is a list of AdUnits ending with nil.
    convenience init?(loadWithMemberId memberID: Int, delegate: AMMultiAdRequestDelegate?, adUnits firstAdUnit: AMAdProtocolFoundationCore, adUnitArgs: AMAdProtocolFoundationCore...) {
        self.init()
        
        let didSetup = setup(withMemberId: memberID, publisherID: 0, andDelegate: delegate)
        guard didSetup else { return nil }

        let addUnitResult = self.addAdUnit(firstAdUnit)
        guard addUnitResult else { return nil }

        for arg in adUnitArgs {
            let addUnitResult = self.addAdUnit(arg)
            guard addUnitResult else { return nil }
        }

        let didLoad = load()
        guard didLoad else { return nil}
    }

    /// adUnits is a list of AdUnits ending with nil.
    convenience init?(loadWithMemberId memberID: Int, publisherId: Int, delegate: AMMultiAdRequestDelegate?, adUnits firstAdUnit: AMAdProtocolFoundationCore, adUnitArgs: AMAdProtocolFoundationCore...) {
        self.init()
        
        let didSetup = setup(withMemberId: memberId, publisherID: publisherId, andDelegate: delegate)
        guard didSetup else { return nil }

        let addUnitResult = self.addAdUnit(firstAdUnit)
        guard addUnitResult else { return nil }

        for arg in adUnitArgs {
            let addUnitResult = self.addAdUnit(arg)
            guard addUnitResult else { return nil }
        }

        let didLoad = load()
        guard didLoad else { return nil}
    }

    convenience init?(memberId: Int, publisherId: Int, andDelegate delegate: AMMultiAdRequestDelegate?) {
        self.init()

        if !setup(withMemberId: memberId, publisherID: publisherId, andDelegate: delegate) {
            return nil
        }
    }

    /*
     * Return: YES on success; otherwise, NO.
     */
    func setup(withMemberId memberId: Int, publisherID publisherId: Int, andDelegate delegate: AMMultiAdRequestDelegate?) -> Bool {
        guard memberId > 0 && publisherId >= 0 else {
            AMLogError("memberId MUST BE GREATER THAN zero (0).")
            AMLogError("publisherId MUST BE non-negative.")
            return false
        }

        self.delegate = delegate
        self.adFetcher = AMAdFetcherBase(multiAdRequestManager: self)
        self.memberId = memberId
        self.publisherId = publisherId

        return true
    }

    /// Add an ad unit to MultiAdRequest object.
    /// Check that its fields do not conflict with MAR fields.  Set its MAR manager delegate.
    ///
    /// Returns: YES on success; otherwise, NO.
//    typealias AMAdUnit = AMMultiAdProtocol & AMAdProtocolFoundationCore
    func addAdUnit(_ newAdUnit: AMAdProtocolFoundationCore) -> Bool {
        var newMemberID = -1
        var newPublisherId = -1
        var newUUIDKey = ""

        var getProperties: [NSValue]? = nil
        let nullObj = NSNull()


        // Capture memberID, UUID and delegate from newAdUnit.
        //
        getProperties = adUnit(
            newAdUnit,
            getProperties: [
                NSNumber(value: MultiAdPropertyType.memberID.rawValue),
                NSNumber(value: MultiAdPropertyType.publisherID.rawValue),
                NSNumber(value: MultiAdPropertyType.uuid.rawValue),
                NSNumber(value: MultiAdPropertyType.manager.rawValue)
            ])

        if getProperties?.count != 4 {
            AMLogError("FAILED to read newAdUnit properties.")
            return false
        }

        if #available(iOS 11.0, *) {
            getProperties?[0].getValue(UnsafeMutableRawPointer(mutating: &newMemberID), size: MemoryLayout<Int>.size)
            getProperties?[1].getValue(UnsafeMutableRawPointer(mutating: &newPublisherId), size: MemoryLayout<Int>.size)
        } else {
            getProperties?[0].getValue(&newMemberID)
            getProperties?[1].getValue(&newPublisherId)
        }
        
//

        newUUIDKey = "\(String(describing: getProperties?[2]))"


        // Check that newAdUnit is not already managed by this or another MultiAdRequest object.
        //
        if getProperties?[3] != nullObj {
            if indexOfAdUnit(withUUIDKey: newUUIDKey) != kMARAdUnitIndexNotFound {
                AMLogError("IGNORING newAdUnit because it is already managed by this MultiAdRequest object.")
            } else {
                AMLogError("REJECTING newAdUnit because it is managed by another MultiAdRequest object.")
            }

            return false
        }


        // If newAdUnit defines its memberID or publisherID, check against equivalent MultiAdRequest values.
        //
        if newMemberID > 0 {
            if memberId != newMemberID {
                return false
            }
        }

        if newPublisherId > 0 {
            if publisherId != newPublisherId {
                return false
            }
        }

        // Set the MultiAdRequest manager delegates in the ad unit.
        if let multiad = newAdUnit as? AMMultiAdProtocol {
            adUnit(multiad, setManager: self)
        }
        
        adUnits.append(newAdUnit)

        return true
    }

    /// Remove an ad unit from MultiAdRequest object.
    /// Set its MAR manager delegate to nil.
    ///
    /// Returns: YES on success; otherwise, NO.
    func removeAdUnit(_ adUnit: (AMMultiAdProtocol & AMAdProtocolFoundationCore)) -> Bool {
        var auUUIDKey: String? = nil
        var auIndex = -1

        var getProperties: [Any]? = nil

        //
        getProperties = self.adUnit(
            adUnit,
            getProperties: [NSNumber(value: MultiAdPropertyType.uuid.rawValue)])
        guard let props = getProperties, props.count == 1 else {
            AMLogError("FAILED to read adUnit property.")
            return false
        }

        auUUIDKey = props[0] as? String

        auIndex = indexOfAdUnit(withUUIDKey: auUUIDKey ?? "")
        if auIndex == kMARAdUnitIndexNotFound {
            AMLogError("AdUnit is not managed by this Multi-Ad Request instance.  \(auUUIDKey ?? "")")
            return false
        }


        //
        self.adUnit(adUnit, setManager: nil)
        self.adUnits.remove(at: auIndex)

        return true
    }

    /// RETURNS: YES if fetcher is started; otherwise, NO.
    func load() -> Bool {
        var errorString: String? = nil

        if adUnits.count <= 0 {
            errorString = "MultiAdRequest instance CONTAINS NO AdUnits."
        }

        if adFetcher == nil {
            errorString = "Fetcher is UNALLOCATED.  FAILED TO FETCH tags via UT."
        }

        if errorString != nil {
            let sessionError = AMError("multi_ad_request_failed %@", AMAdResponseCode.amAdResponseInvalidRequest.rawValue)


            if delegate?.responds(to: #selector(AMMultiAdRequestDelegate.multiAdRequest(_:didFailWithError:))) ?? false {
                delegate?.multiAdRequest?(self, didFailWithError: sessionError)
            }

            return false
        }


        adFetcher?.stopAdLoad()
        adFetcher?.requestAd()
        return true
    }

    deinit {
        adFetcher?.stopAdLoad()

    }

// MARK: - Getters/Setters.
    func countOfAdUnits() -> Int {
        return adUnits.count
    }

    func setPublisherId(_ publisherId: Int) {
        AMLogError("publisherId may only be SET WITH INITIALIZERS.")
    }

// MARK: - Private methods.
    func internalMultiAdRequestDidComplete() {
        if delegate?.responds(to: #selector(AMMultiAdRequestDelegate.multiAdRequestDidComplete(_:))) ?? false {
            delegate?.multiAdRequestDidComplete?(self)
        }
    }

    func internalMultiAdRequestDidFailWithError(_ error: Error?) {
        if delegate?.responds(to: #selector(AMMultiAdRequestDelegate.multiAdRequest(_:didFailWithError:))) ?? false {
            if let error = error {
                delegate?.multiAdRequest?(self, didFailWithError: error)
            }
        }
    }

    /// NB  Passes internal pointer back to calling environment.
    func internalGetAdUnits() -> [AMAdProtocolFoundationCore] {
        return adUnits
    }

    /// NB  Passes internal pointer back to calling environment.
    func internalGetAdUnit(byUUID uuidKey: String) -> AMAdProtocolFoundationCore? {
        let adunitIndex = indexOfAdUnit(withUUIDKey: uuidKey)

        if kMARAdUnitIndexNotFound == adunitIndex {
            return nil
        } else {
            return adUnits[adunitIndex]
        }
    }

// MARK: - Helper methods.
   
    /// Get an arbitrary number of properties from an arbitrary ad unit.
    ///
    /// RETURNS:
    ///   An array of objects that represent the items getted, in the order in which they were accessed.
    ///   Non-class values are passed via NSValue, nil is passed as NSNull.
    ///   All properties in the list are considered, even if there are errs along the way.
    ///   nil is returned instead of an array in the case of method fatal errors.
    func adUnit(_ adUnit: AMAdProtocolFoundationCore, getProperties getTypes: [NSNumber]) -> [NSValue]? {
           var returnValuesArray: [NSValue] = []
           let nullObj = NSValue()
           
           for gt in getTypes {
               let getType = MultiAdPropertyType(rawValue: gt.intValue)

               switch getType {
               case .manager:
                let marManager = (adUnit as? AMMultiAdProtocol)?.marManager
                let value = NSValue(nonretainedObject: marManager)
                returnValuesArray.append(value)
               case .memberID:
                       returnValuesArray.append(NSNumber(value: adUnit.memberId))
               case .publisherID:
                       returnValuesArray.append(NSNumber(value: adUnit.publisherId))
               case .uuid:
                let uuid = (adUnit as? AMMultiAdProtocol)?.utRequestUUIDString
                let value = NSValue(pointer: uuid)
                returnValuesArray.append(value)
                   default:
                       AMLogError("(internal) UNKNOWN MultiAdPropertyType getType.  \(String(describing: getType)).")
                   returnValuesArray.append(nullObj)
            }
            }
           return returnValuesArray
       }

    /// Set the delegate of an arbitrary ad unit.
    ///
    /// Return: YES on success; NO otherwise.
    func adUnit(_ adUnit: AMMultiAdProtocol, setManager delegate: Any?) {
        adUnit.marManager = delegate as? AMMultiAdRequest
        return
    }

    func indexOfAdUnit(withUUIDKey uuidKey: String) -> Int {
        var adunitIndex = kMARAdUnitIndexNotFound
        var adunitUUID: String? = nil

        for au in adUnits {
            guard let au = au as? AMMultiAdProtocol else {
                continue
            }
            adunitIndex += 1

            adunitUUID = au.utRequestUUIDString
            if adunitUUID == nil {
                return kMARAdUnitIndexNotFound
            }

            if (adunitUUID == uuidKey) {
                AMLogDebug("MATCHED uuidKey.  (%@)", uuidKey) //DEBUG
                return adunitIndex
            }
        }

        return kMARAdUnitIndexNotFound
    }

// MARK: - AMAdProtocol.
    @objc func adDidReceiveAd(_ ad: Any) {
        //EMPTY
    }

    @objc func ad(_ ad: Any, didReceiveNativeAd responseInstance: Any) {
        //EMPTY
    }

    @objc func ad(_ ad: Any, requestFailedWithError error: Error) {
        //EMPTY
    }

    func adRequestFailedWithError(_ error: Error?) {
        //UNUSED
    }

    @objc func adRequest(_ request: AMNativeAdRequest, didReceive response: AMNativeAdResponse) {
        //EMPTY
    }
    
    func adRequest(_ request: AMNativeAdRequest, didFailToLoadWithError error: Error, with adResponseInfo: AMAdResponseInfo?) {
        
    }

    func adRequest(_ request: AMNativeAdRequest, didFailToLoadWithError error: Error) {
        //EMPTY
    }

    func addCustomKeyword(withKey key: String, value: String) {
        if (key.count < 1) || value == "" {
            return
        }

        if customKeywords?[key] != nil {
            var valueArray = customKeywords?[key]
            if !(valueArray?.contains(value) ?? false) {
                valueArray?.append(value)
            }
            customKeywords?[key] = valueArray
        } else {
            customKeywords?[key] = [value]
        }
    }

    func removeCustomKeyword(withKey key: String) {
        if (key.count < 1) {
            return
        }

        //check if the key exist before calling remove
        let keysArray = customKeywords?.keys

        if keysArray?.contains(key) ?? false {
            customKeywords?.removeValue(forKey: key)
        }

    }

    func clearCustomKeywords() {
        customKeywords?.removeAll()
    }

    func setLocationWithLatitude(_ latitude: CGFloat, longitude: CGFloat, timestamp: Date?, horizontalAccuracy: CGFloat) {
        location = AMLocation.getWithLatitude(
            latitude,
            longitude: longitude,
            timestamp: timestamp,
            horizontalAccuracy: horizontalAccuracy)
    }

    func setLocationWithLatitude(_ latitude: CGFloat, longitude: CGFloat, timestamp: Date?, horizontalAccuracy: CGFloat, precision: Int) {
        location = AMLocation.getWithLatitude(
            latitude,
            longitude: longitude,
            timestamp: timestamp,
            horizontalAccuracy: horizontalAccuracy,
            precision: precision)
    }
}

