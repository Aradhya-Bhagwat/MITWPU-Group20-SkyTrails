
import Foundation
import SwiftData

/// Service responsible for assembling rule parameters from UI state
@MainActor
final class WatchlistRuleAssemblyService {
    
    // MARK: - Species Family Rule Assembly
    
    /// Assembles species family rule parameters from UI selections
    /// - Parameters:
    ///   - selectedShapeId: The newly selected shape ID from UI
    ///   - existingShapeId: The existing shape ID from saved rule (if any)
    ///   - isActive: Whether the rule should be active
    /// - Returns: A tuple containing the assembled parameters and active state
    func assembleSpeciesRule(
        selectedShapeId: String?,
        existingShapeId: String?,
        isActive: Bool
    ) -> (parameters: RuleParameters?, isActive: Bool) {
        let shapeId = selectedShapeId ?? existingShapeId
        let parameters: RuleParameters? = shapeId.map {
            .speciesFamily(SpeciesFamilyRuleParams(shapeId: $0))
        }
        return (parameters, isActive)
    }
    
    // MARK: - Location Rule Assembly
    
    /// Assembles location rule parameters from UI selections
    /// - Parameters:
    ///   - selectedLocation: The newly selected location from UI
    ///   - existingData: Existing location data from saved rule (lat, lon, radius)
    ///   - selectedRadius: The radius selected in UI
    ///   - isActive: Whether the rule should be active
    /// - Returns: A tuple containing the assembled parameters and active state
    func assembleLocationRule(
        selectedLocation: LocationService.LocationData?,
        existingData: (lat: Double, lon: Double, radiusKm: Double)?,
        selectedRadius: Double,
        isActive: Bool
    ) -> (parameters: RuleParameters?, isActive: Bool) {
        let parameters: RuleParameters?
        
        if let selectedLoc = selectedLocation {
            parameters = .location(
                LocationRuleParams(
                    lat: selectedLoc.lat,
                    lon: selectedLoc.lon,
                    radiusKm: selectedRadius
                )
            )
        } else if let existingData = existingData {
            parameters = .location(
                LocationRuleParams(
                    lat: existingData.lat,
                    lon: existingData.lon,
                    radiusKm: existingData.radiusKm
                )
            )
        } else {
            parameters = nil
        }
        
        return (parameters, isActive)
    }
    
    // MARK: - Date Range Rule Assembly
    
    /// Assembles date range rule parameters from UI date pickers
    /// - Parameters:
    ///   - startDate: The start date from UI
    ///   - endDate: The end date from UI
    ///   - isActive: Whether the rule should be active
    /// - Returns: A tuple containing the assembled parameters and active state
    func assembleDateRule(
        startDate: Date,
        endDate: Date,
        isActive: Bool
    ) -> (parameters: RuleParameters?, isActive: Bool) {
        let parameters: RuleParameters = .dateRange(
            DateRangeRuleParams(startDate: startDate, endDate: endDate)
        )
        return (parameters, isActive)
    }
    
    // MARK: - Batch Assembly
    
    /// Assembles all rules at once for convenience
    /// - Parameters:
    ///   - speciesData: Species rule assembly data
    ///   - locationData: Location rule assembly data
    ///   - dateData: Date rule assembly data
    /// - Returns: A dictionary of rule types to their assembled parameters
    func assembleAllRules(
        speciesData: (selectedShapeId: String?, existingShapeId: String?, isActive: Bool),
        locationData: (selectedLocation: LocationService.LocationData?, existingData: (lat: Double, lon: Double, radiusKm: Double)?, selectedRadius: Double, isActive: Bool),
        dateData: (startDate: Date, endDate: Date, isActive: Bool)
    ) -> [WatchlistRuleType: (parameters: RuleParameters?, isActive: Bool)] {
        return [
            .species_family: assembleSpeciesRule(
                selectedShapeId: speciesData.selectedShapeId,
                existingShapeId: speciesData.existingShapeId,
                isActive: speciesData.isActive
            ),
            .location: assembleLocationRule(
                selectedLocation: locationData.selectedLocation,
                existingData: locationData.existingData,
                selectedRadius: locationData.selectedRadius,
                isActive: locationData.isActive
            ),
            .date_range: assembleDateRule(
                startDate: dateData.startDate,
                endDate: dateData.endDate,
                isActive: dateData.isActive
            )
        ]
    }
}
