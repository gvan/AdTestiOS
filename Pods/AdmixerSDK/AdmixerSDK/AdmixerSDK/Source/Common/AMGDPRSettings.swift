//
//  AMGDPRSettings.swift
//  AdmixerSDK
//
//  Created by admin on 09/09/2020.
//  Copyright © 2020 Admixer. All rights reserved.
//

import Foundation

let AMGDPR_ConsentString = "AMGDPR_ConsentString"
let AMGDPR_ConsentRequired = "AMGDPR_ConsentRequired"
let AMGDPR_PurposeConsents = "AMGDPR_PurposeConsents"
//TCF 2.0 variables
let AMIABTCF_ConsentString = "IABTCF_TCString"
let AMIABTCF_SubjectToGDPR = "IABTCF_gdprApplies"
let AMIABTCF_PurposeConsents = "IABTCF_PurposeConsents"
//TCF 1.1 variables
let AMIABConsent_ConsentString = "IABConsent_ConsentString"
let AMIABConsent_SubjectToGDPR = "IABConsent_SubjectToGDPR"

class AMGDPRSettings {
    /// Set the GDPR consent string in the SDK
    class func setConsentString(_ consentString: String) {
        UserDefaults.standard.set(consentString, forKey: AMGDPR_ConsentString)
    }

    /// Set the GDPR consent required in the SDK
    class func setConsentRequired(_ consentRequired: NSNumber?) {

        UserDefaults.standard.setValue(consentRequired, forKey: AMGDPR_ConsentRequired)

    }

    /// reset the GDPR consent string and consent required in the SDK
    class func reset() {
        let defaults = UserDefaults.standard
        if defaults.dictionaryRepresentation().keys.contains(AMGDPR_ConsentString) {
            UserDefaults.standard.removeObject(forKey: AMGDPR_ConsentString)
        }
        if defaults.dictionaryRepresentation().keys.contains(AMGDPR_ConsentRequired) {
            UserDefaults.standard.removeObject(forKey: AMGDPR_ConsentRequired)
        }
        if defaults.dictionaryRepresentation().keys.contains(AMGDPR_PurposeConsents) {
            UserDefaults.standard.removeObject(forKey: AMGDPR_PurposeConsents)
        }
    }

    /// Get the GDPR consent string in the SDK.
    /// Check for AMGDPR_ConsentString And IABConsent_ConsentString and return if present else return @""
    class func getConsentString() -> String? {

        var consentString = UserDefaults.standard.string(forKey: AMGDPR_ConsentString)
        if (consentString?.count ?? 0) <= 0 {
            consentString = UserDefaults.standard.string(forKey: AMIABTCF_ConsentString)
            if (consentString?.count ?? 0) <= 0 {
                consentString = UserDefaults.standard.string(forKey: AMIABConsent_ConsentString)
            }
        }
        return consentString ?? ""
    }

    /// Get the GDPR consent required in the SDK
    /// Check for AMGDPR_ConsentRequired And IABConsent_SubjectToGDPR  and return if present else return nil
    class func getConsentRequired() -> NSNumber? {

        var hasConsent = UserDefaults.standard.value(forKey: AMGDPR_ConsentRequired) as? NSNumber
        if hasConsent == nil {
            hasConsent = UserDefaults.standard.value(forKey: AMIABTCF_SubjectToGDPR) as? NSNumber
            if hasConsent == nil {
                let hasConsentStringValue = UserDefaults.standard.string(forKey: AMIABConsent_SubjectToGDPR)
                let numberFormatter = NumberFormatter()
                hasConsent = numberFormatter.number(from: hasConsentStringValue ?? "")
            }
        }
        return hasConsent
    }

    /// Get the GDPR device consent required in the SDK to pass IDFA & cookies
    /// Check for AMGDPR_PurposeConsents And AMIABTCF_PurposeConsents  and return if present else return nil
    class func getDeviceAccessConsent() -> String? {
        var consents = UserDefaults.standard.string(forKey: AMGDPR_PurposeConsents)
        if consents == nil || consents!.isEmpty {
            consents = UserDefaults.standard.string(forKey: AMIABTCF_PurposeConsents)
        }
        
        guard let strongConsents = consents else { return nil }
        let index = strongConsents.index(strongConsents.startIndex, offsetBy: 1)
        return String(strongConsents[..<index])
    }

    /// set the GDPR device consent required in the SDK to pass IDFA & cookies
    class func setPurposeConsents(_ purposeConsents: String) {
        if purposeConsents.count > 0 {
            UserDefaults.standard.set(purposeConsents, forKey: AMGDPR_PurposeConsents)
        }
    }

    /// Get the GDPR device consent as a combination of purpose 1 & consent required
    static var canAccessDeviceData: Bool {
        let accessConsent = getDeviceAccessConsent()
        let consentRequired = getConsentRequired()
        
        if ((accessConsent == nil) &&
            (consentRequired == nil || consentRequired?.boolValue ?? false == false)) || (accessConsent != nil && (accessConsent == "1")) {
            return true
        }
        return false
    }
}
