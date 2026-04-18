import Foundation

enum LocationPreferenceStore {
    static let defaultSiteIDKey = "preferences.default_observing_site_id"
    static let defaultEquipmentProfileIDKey = "preferences.default_equipment_profile_id"

    static func defaultSiteID(defaults: UserDefaults = .standard) -> UUID? {
        guard let rawValue = defaults.string(forKey: defaultSiteIDKey), !rawValue.isEmpty else {
            return nil
        }

        return UUID(uuidString: rawValue)
    }

    static func setDefaultSiteID(_ id: UUID?, defaults: UserDefaults = .standard) {
        if let id {
            defaults.set(id.uuidString, forKey: defaultSiteIDKey)
        } else {
            defaults.removeObject(forKey: defaultSiteIDKey)
        }
    }

    static func preferredSite(from sites: [ObservingSite], defaults: UserDefaults = .standard) -> ObservingSite? {
        if let defaultSiteID = defaultSiteID(defaults: defaults),
           let site = sites.first(where: { $0.id == defaultSiteID }) {
            return site
        }

        setDefaultSiteID(nil, defaults: defaults)
        return nil
    }

    static func reconcileDefaultSiteID(using sites: [ObservingSite], defaults: UserDefaults = .standard) -> UUID? {
        if let defaultSiteID = defaultSiteID(defaults: defaults),
           sites.contains(where: { $0.id == defaultSiteID }) {
            return defaultSiteID
        }

        setDefaultSiteID(nil, defaults: defaults)
        return nil
    }

    static func defaultEquipmentProfileID(defaults: UserDefaults = .standard) -> UUID? {
        guard let rawValue = defaults.string(forKey: defaultEquipmentProfileIDKey), !rawValue.isEmpty else {
            return nil
        }

        return UUID(uuidString: rawValue)
    }

    static func setDefaultEquipmentProfileID(_ id: UUID?, defaults: UserDefaults = .standard) {
        if let id {
            defaults.set(id.uuidString, forKey: defaultEquipmentProfileIDKey)
        } else {
            defaults.removeObject(forKey: defaultEquipmentProfileIDKey)
        }
    }

    static func reconcileDefaultEquipmentProfileID(using equipmentProfiles: [EquipmentProfile], defaults: UserDefaults = .standard) -> UUID? {
        if let defaultEquipmentProfileID = defaultEquipmentProfileID(defaults: defaults),
           equipmentProfiles.contains(where: {
               $0.id == defaultEquipmentProfileID &&
               $0.catalogGroup == .smartTelescope &&
               $0.isPlanCompatibleDefault
           }) {
            return defaultEquipmentProfileID
        }

        setDefaultEquipmentProfileID(nil, defaults: defaults)
        return nil
    }
}
